# Auto-Derdacha

Multilingual meeting recorder and summarizer — handles Darija, French, and English (code-switching included). Records audio locally, sends it to Groq's free Whisper endpoint for transcription, then generates a structured Markdown summary with an LLM.

---

## How to run the project

### Prerequisites

| Tool | Minimum version | Where to get it |
|---|---|---|
| Flutter SDK | 3.16.0 | https://docs.flutter.dev/get-started/install |
| Dart SDK | 3.2.0 | Bundled with Flutter |
| Android SDK | API 21+ | Android Studio or `sdkmanager` |
| Java (JDK) | 17 | https://adoptium.net |
| A Groq API key | — | https://console.groq.com/keys (free tier) |

### 1. Clone and enter the project

```bash
git clone <repo-url>
cd auto-Dardacha
```

### 2. Set up your environment file

```bash
cp .env.example .env
```

Open `.env` and fill in `GROQ_API_KEY` with the key you created at https://console.groq.com/keys.
The other variables have safe defaults and can be left as-is.

### 3. Generate platform directories (first time only)

`flutter create` was not run in this repo — run it once to generate the `android/` and `ios/` directories:

```bash
flutter create . --project-name auto_derdacha --org com.autoderdacha
```

This will not overwrite existing files.

### 4. Install dependencies

```bash
flutter pub get
```

### 5. Generate Drift database code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 6. Run the app

```bash
flutter run --dart-define-from-file=.env
```

For VS Code users, add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "auto_derdacha",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define-from-file=.env"]
    }
  ]
}
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `StateError: GROQ_API_KEY is not set` | You forgot `--dart-define-from-file=.env`, or `.env` is missing `GROQ_API_KEY`. |
| `flutter: command not found` | Flutter is not in your PATH. Follow https://docs.flutter.dev/get-started/install. |
| Mic permission denied on device | Go to system Settings → Apps → auto_derdacha → Permissions → Microphone → Allow. |
| Groq API returns 401 | Your `GROQ_API_KEY` is invalid or expired. Regenerate at https://console.groq.com/keys. |
| Groq API returns 429 | Free-tier rate limit hit. Wait ~60 s and retry (the app retries automatically). |
| Notifications not working (Android 13+) | Go to Settings → Apps → auto_derdacha → Notifications → Allow, and allow exact alarms. |
