import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/errors/failures.dart';
import 'groq_client.dart';

/// Sends an audio file to Groq's Whisper endpoint and returns the transcript.
class TranscriptionApi {
  const TranscriptionApi(this._client);

  final GroqClient _client;

  static const _endpoint = '/audio/transcriptions';
  // 25 MB — Groq hard limit. Chunking is handled upstream ([IP-0048]).
  static const maxFileSizeBytes = 25 * 1024 * 1024;

  /// Transcribes [audio] and returns a [Result] with the raw transcript string.
  ///
  /// [language] is intentionally left null by default so Whisper auto-detects
  /// language and handles Darija / FR / EN code-switching (architecture §3).
  /// Pass a BCP-47 code (e.g. 'fr', 'ar') to override.
  ///
  /// [cancelToken] is threaded through for ProcessingPage cancellation ([IP-0058]).
  Future<Result<String>> transcribe(
    File audio, {
    String? language,
    CancelToken? cancelToken,
  }) async {
    final size = audio.lengthSync();
    if (size > maxFileSizeBytes) return const Err(FileTooLargeFailure());
    if (size == 0) return const Err(EmptyAudioFailure());

    try {
      final formData = FormData.fromMap({
        'model': Env.sttModel,
        'response_format': 'json',
        if (language != null) 'language': language,
        'file': await MultipartFile.fromFile(
          audio.path,
          filename: audio.uri.pathSegments.last,
        ),
      });

      final response = await _client.dio.post<Map<String, dynamic>>(
        _endpoint,
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          // Override content-type so Dio sets multipart boundary correctly.
          contentType: 'multipart/form-data',
        ),
      );

      final text = (response.data?['text'] as String?)?.trim();
      if (text == null || text.isEmpty) {
        return const Err(EmptyAudioFailure('Transcription vide reçue.'));
      }
      return Ok(text);
    } on DioException catch (e) {
      return Err(mapDioError(e));
    } catch (e) {
      return Err(NetworkFailure(e.toString()));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final transcriptionApiProvider = Provider<TranscriptionApi>(
  (ref) => TranscriptionApi(ref.watch(groqClientProvider)),
);
