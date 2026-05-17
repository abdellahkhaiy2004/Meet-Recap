import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/errors/failures.dart';
import 'groq_client.dart';

/// Sends a raw transcript to the Groq LLM and returns a structured
/// Markdown summary with fixed sections (architecture §3, §20).
class SummaryApi {
  const SummaryApi(this._client);

  final GroqClient _client;

  static const _endpoint = '/chat/completions';

  // ── System prompt ─────────────────────────────────────────────────────────

  static const _systemPrompt = '''
Tu es un expert en synthèse de réunions multilingues.
Le transcript fourni peut contenir du Darija (dialecte arabe marocain, en alphabet arabe ou en translittération latine), du français, de l'anglais, ou un mélange de ces langues au sein d'une même phrase (code-switching).

Règles absolues :
1. Détecte la langue dominante du transcript (Darija, français, ou anglais).
2. Rédige entièrement la synthèse dans la langue dominante détectée.
3. Conserve les noms propres, termes techniques, titres de postes et références exactement tels qu'ils apparaissent dans le transcript.
4. Structurer ta réponse en Markdown valide avec EXACTEMENT ces cinq sections, dans cet ordre, sans texte avant le premier ## ni après le dernier :

## Participants
Liste chaque participant ou intervenant identifié. Indique "Inconnu" si le nom n'est pas clair.

## Décisions
Liste à puces des décisions prises lors de la réunion. Chaque puce = une décision.

## Action items
Liste à puces. Format : [Responsable si connu] — tâche — délai si mentionné.

## Risques / Points ouverts
Liste à puces des questions ouvertes, risques identifiés ou points non résolus.

## Résumé global
2 à 4 phrases résumant l'objet de la réunion et les résultats principaux.

5. Si une section ne contient aucune information pertinente, écris "Aucun" sous son titre.
6. Ne génère aucun texte avant le premier ## ni après la dernière section.

Exemple de structure attendue (contenu fictif) :

## Participants
- Ahmed Benali
- Sara Dupont
- Inconnu (intervenant 3)

## Décisions
- Valider le budget Q3 avant le 30 juin.
- Passer au nouveau prestataire logistique.

## Action items
- [Ahmed] — Envoyer la proposition budgétaire — avant vendredi.
- [Sara] — Contacter le prestataire pour négociation — semaine prochaine.

## Risques / Points ouverts
- Le délai de livraison du prestataire n'est pas confirmé.
- Validation légale du contrat encore en attente.

## Résumé global
La réunion a porté sur la planification budgétaire du Q3 et le changement de prestataire logistique. Les deux décisions clés ont été validées, avec des actions assignées à Ahmed et Sara pour la semaine suivante.
''';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Summarises [transcript] and returns a [Result] with the Markdown string.
  ///
  /// [cancelToken] is threaded through for ProcessingPage cancellation ([IP-0058]).
  Future<Result<String>> summarize(
    String transcript, {
    CancelToken? cancelToken,
  }) async {
    if (transcript.trim().isEmpty) {
      return const Err(EmptyAudioFailure('Transcript vide, résumé impossible.'));
    }

    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        _endpoint,
        cancelToken: cancelToken,
        data: {
          'model': Env.llmModel,
          'temperature': 0.2,
          'max_tokens': 2048,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {
              'role': 'user',
              'content':
                  'Voici le transcript de la réunion :\n\n$transcript',
            },
          ],
        },
      );

      final content = _extractContent(response.data);
      if (content == null || content.trim().isEmpty) {
        return const Err(ApiFailure(
          status: 200,
          message: 'Le modèle a retourné un contenu vide.',
        ));
      }

      // Sanity-check: ensure the required sections are present.
      final validated = _validateSections(content);
      return Ok(validated);
    } on DioException catch (e) {
      return Err(mapDioError(e));
    } catch (e) {
      return Err(NetworkFailure(e.toString()));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _extractContent(Map<String, dynamic>? data) {
    // Groq/OpenAI chat completions shape:
    // { "choices": [ { "message": { "content": "..." } } ] }
    final choices = data?['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final message = choices.first['message'];
    if (message is! Map) return null;
    return message['content']?.toString();
  }

  static const _requiredSections = [
    '## Participants',
    '## Décisions',
    '## Action items',
    '## Risques / Points ouverts',
    '## Résumé global',
  ];

  /// If the model omitted a required section, appends it with "Aucun".
  /// Prevents the UI from crashing on missing headings.
  static String _validateSections(String md) {
    var result = md;
    for (final section in _requiredSections) {
      if (!result.contains(section)) {
        result = '$result\n\n$section\nAucun';
      }
    }
    return result.trim();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final summaryApiProvider = Provider<SummaryApi>(
  (ref) => SummaryApi(ref.watch(groqClientProvider)),
);
