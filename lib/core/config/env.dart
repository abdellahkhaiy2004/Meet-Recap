abstract final class Env {
  static const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const baseUrl = String.fromEnvironment(
    'GROQ_BASE_URL',
    defaultValue: 'https://api.groq.com/openai/v1',
  );
  static const sttModel = String.fromEnvironment(
    'GROQ_STT_MODEL',
    defaultValue: 'whisper-large-v3',
  );
  static const llmModel = String.fromEnvironment(
    'GROQ_LLM_MODEL',
    defaultValue: 'llama-3.3-70b-versatile',
  );

  // Called from main() before runApp. Fails fast with a clear message
  // when the app is started without --dart-define-from-file=.env.
  static void validate() {
    if (groqApiKey.isEmpty) {
      throw StateError(
        'GROQ_API_KEY is not set.\n'
        'Copy .env.example → .env, fill GROQ_API_KEY, then run:\n'
        '  flutter run --dart-define-from-file=.env',
      );
    }
  }
}
