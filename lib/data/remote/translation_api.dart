import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/errors/failures.dart';
import 'groq_client.dart';

/// Post-processes a raw Whisper transcript through the Groq LLM:
///   - optionally translates to a target language (fr/en)
///   - optionally transliterates Darija from Arabic to Latin script
///
/// Both operations share the same chat/completions endpoint so we only pay
/// one round-trip when both are requested.
class TranslationApi {
  const TranslationApi(this._client);

  final GroqClient _client;

  static const _endpoint = '/chat/completions';

  /// Returns the transformed transcript, or the original [transcript]
  /// unchanged when no transformation is requested.
  ///
  /// [translateTo]    null = keep source language; 'fr' or 'en' = translate.
  /// [latinizeDarija] true = if text is Darija in Arabic script, rewrite Latin.
  /// [detectedLang]   BCP-47 code from Whisper (used to skip no-op calls).
  Future<Result<String>> postProcess(
    String transcript, {
    String? translateTo,
    bool latinizeDarija = false,
    String detectedLang = '',
    CancelToken? cancelToken,
  }) async {
    // Nothing to do — short-circuit so we don't burn an API call.
    final shouldTranslate =
        translateTo != null && translateTo != detectedLang;
    final shouldLatinize = latinizeDarija && detectedLang == 'ar';
    if (!shouldTranslate && !shouldLatinize) return Ok(transcript);
    if (transcript.trim().isEmpty) return Ok(transcript);

    final prompt = _buildSystemPrompt(
      translateTo: shouldTranslate ? translateTo : null,
      latinizeDarija: shouldLatinize,
    );

    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        _endpoint,
        cancelToken: cancelToken,
        data: {
          'model': Env.llmModel,
          'temperature': 0.1,
          'max_tokens': 4096,
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': transcript},
          ],
        },
      );

      final content = _extractContent(response.data);
      if (content == null || content.trim().isEmpty) {
        // Fail soft — return the original so the pipeline can still produce
        // a summary. Translation failure should not kill the whole meeting.
        return Ok(transcript);
      }
      return Ok(content.trim());
    } on DioException catch (e) {
      // Same fail-soft policy on network errors.
      if (e.type == DioExceptionType.cancel) {
        return Err(mapDioError(e));
      }
      return Ok(transcript);
    } catch (_) {
      return Ok(transcript);
    }
  }

  // ── Prompt builder ────────────────────────────────────────────────────────

  static String _buildSystemPrompt({
    String? translateTo,
    bool latinizeDarija = false,
  }) {
    final lines = <String>[
      'You rewrite raw meeting transcripts according to the rules below.',
      'Output ONLY the rewritten transcript text. No preamble, no quotes, '
          'no explanations, no Markdown fences.',
      'Preserve proper nouns, numbers, dates, titles, and technical terms '
          'exactly as they appear.',
    ];

    if (latinizeDarija) {
      lines.add(
        'Rule (Darija romanization): when the text is Moroccan Darija written '
        'in Arabic script, transliterate it into the Latin "arabizi" '
        'convention commonly used by Moroccan speakers (using digits 2, 3, 5, '
        '7, 9 for Arabic-specific sounds). Keep code-switched French/English '
        'words in Latin script as-is.',
      );
    }

    if (translateTo != null) {
      final target = translateTo == 'fr' ? 'French' : 'English';
      lines.add(
        'Rule (translation): translate the entire transcript into $target. '
        'Translate Darija, French, and English uniformly into $target. '
        'Render names of people and places naturally in $target.',
      );
    }

    if (!latinizeDarija && translateTo == null) {
      lines.add('Rule: return the input unchanged.');
    }

    return lines.join('\n');
  }

  static String? _extractContent(Map<String, dynamic>? data) {
    final choices = data?['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final message = choices.first['message'];
    if (message is! Map) return null;
    return message['content']?.toString();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final translationApiProvider = Provider<TranslationApi>(
  (ref) => TranslationApi(ref.watch(groqClientProvider)),
);
