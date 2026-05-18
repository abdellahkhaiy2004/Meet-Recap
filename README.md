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

## Running on an Android emulator via Android Studio

This section covers the full path from a fresh Android Studio install to seeing the app running in an emulator.

### A. Install and configure Android Studio

1. Download **Android Studio** (Hedgehog 2023.1.1 or later) from https://developer.android.com/studio and run the installer.
2. On first launch, follow the **Setup Wizard** — select *Standard* installation. It will install the Android SDK, build-tools, and a default emulator image automatically.
3. After setup, open **SDK Manager** (top-right gear icon → *SDK Manager*):
   - **SDK Platforms** tab → tick **Android 14 (API 34)** (or any API ≥ 21). Click *Apply*.
   - **SDK Tools** tab → confirm these are installed: *Android SDK Build-Tools*, *Android Emulator*, *Android SDK Platform-Tools*.
4. Open **Settings → Languages & Frameworks → Flutter** (install the Flutter plugin first if absent), point the *Flutter SDK path* to your Flutter installation directory (e.g. `C:\flutter`). Android Studio will auto-detect the Dart SDK bundled with it.

### B. Enable Windows Developer Mode (required for Flutter symlinks)

Flutter on Windows requires symlink support:

1. Open **Settings → System → For developers** (or run `start ms-settings:developers` in a terminal).
2. Toggle **Developer Mode** on.
3. Restart the terminal / Android Studio if already open.

### C. Create an Android Virtual Device (AVD)

1. In Android Studio, open **Device Manager** (right sidebar or *View → Tool Windows → Device Manager*).
2. Click **Create Device**.
3. Choose a phone profile, e.g. **Pixel 7** → *Next*.
4. Select a system image — pick **API 34 (x86_64, Android 14, Google Play)**. Download it if needed → *Next*.
5. Leave AVD settings at their defaults → *Finish*.
6. Press the **▶ Play** button next to the new AVD to boot it. Wait until the home screen is visible before proceeding.

### D. Run auto-Derdacha on the emulator

Open a terminal in the project root (`C:\Users\Admin\Desktop\auto-Dardacha`) and run:

```powershell
# 1. Make sure dependencies and generated code are up to date
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Confirm Flutter sees the running emulator
flutter devices
# Expected output includes something like:
#   sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64 • Android 14 (API 34)

# 3. Launch the app with the env file
flutter run --dart-define-from-file=.env
```

Flutter will automatically target the running emulator. If multiple devices are available, pass `-d emulator-5554` (use the ID shown by `flutter devices`).

### E. Run from within Android Studio (alternative)

1. Open the project folder in Android Studio (*File → Open → select auto-Dardacha*).
2. Wait for Gradle sync to finish.
3. Select your AVD from the device dropdown in the toolbar.
4. Open **Run → Edit Configurations**, select *main.dart*, and add to *Additional run args*:
   ```
   --dart-define-from-file=.env
   ```
5. Click **▶ Run** (Shift+F10). The app will build and deploy to the emulator.

### F. Emulator-specific notes

| Topic | Note |
|---|---|
| Microphone on emulator | The Android emulator routes audio through the host machine's default microphone. Ensure your PC mic is enabled in Windows Sound settings. |
| Notifications | Exact-alarm permissions may need to be granted manually: *Settings → Apps → auto_derdacha → Permissions → Alarms & reminders → Allow*. |
| Hot reload | Press `r` in the terminal (or click the lightning bolt in Android Studio) to hot-reload after Dart changes. Full restart with `R`. |
| Slow first build | Gradle downloads dependencies on first build (~5 min on a cold cache). Subsequent builds are incremental and much faster. |
| `INSTALL_FAILED_USER_RESTRICTED` | Developer Mode is not enabled — see step B above. |

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
| Language override not taking effect | The forced language is read once when the pipeline starts. Change the setting *before* tapping Stop, then retry. |
| `MissingPluginException` on first run | Run `flutter clean && flutter pub get` then rebuild. |

---

## Feature notes — v0.1.0 (2026-05-17)

### Language override (Settings → Langue)

By default, Whisper auto-detects the language and handles Darija / French / English code-switching. If your meetings are consistently in a single language you can force it:

1. Open the **Réglages** tab.
2. Under **Langue (transcription)**, select **Arabe**, **Français**, or **Anglais**.
3. The next recording will pass that code to Whisper's `language` field.
4. Set back to **Auto** to restore code-switching support.

> Forced language also applies when retrying a failed pipeline from MeetingDetailPage.

### Accessibility

All interactive controls carry screen-reader labels compatible with TalkBack (Android) and VoiceOver (iOS):
- RecordButton announces "Démarrer / Arrêter l'enregistrement".
- Audio player skip buttons announce "Reculer / Avancer de 15 secondes".
- Playback speed chips announce their value and selected state.

Enable **Reduce motion** in your OS settings to disable all looping animations while keeping the app fully functional.

### Release checklist status

Parts 0–12 implemented. Pending owner actions before shipping:
1. Run the QA checklist in `student_lab.md` [SL-0052] on a physical device.
2. Add `android:enableOnBackInvokedCallback="true"` to `AndroidManifest.xml` after `flutter create .` ([IP-0046] BLOCKED on SDK install).
3. Create annotated git tag `v0.1.0` ([IP-0057] BLOCKED — not a git repository yet; run `git init && git add -A && git commit -m "chore: initial commit"` then `git tag -a v0.1.0 -m "v0.1.0"`).

---

## Feature notes — Part 13 (2026-05-18)

### Translate the transcript to French or English

By default the transcript is kept in the language Whisper detected (typically Darija, French, English, or a mix). If you want every meeting transcript in a single target language:

1. Open the **Réglages** tab.
2. Under **Traduire le transcript**, choose **Traduire en français** or **Traduire en anglais**.
3. The next recording's transcript will be translated automatically after Whisper finishes and before the summary is generated. The summary will then also be in that language.
4. Set back to **Ne pas traduire** to keep the original language.

If the translation request fails (network issue, API error), the original transcript is kept and the meeting is still saved with its summary — translation is a soft step, not a blocking one.

### Darija in Latin alphabet (arabizi)

Whisper returns Darija in Arabic script by default. If you prefer the Latin "arabizi" convention (using digits 2/3/5/7/9 for Arabic-specific sounds):

1. Open the **Réglages** tab.
2. Toggle **Darija en alphabet latin** on.
3. Any future recording detected as Arabic will have its transcript rewritten in Latin script. The summary inherits the script automatically.

Both settings can be on at the same time — a single LLM call applies both rules.

### Troubleshooting addendum

| Symptom | Fix |
|---|---|
| Transcript is still in Arabic after enabling Darija Latin | The toggle only affects future recordings. Re-process an existing meeting via the "Re-résumer" button or record a new one. |
| Translation toggle has no effect | The setting is read at pipeline start. Change it BEFORE pressing Stop, then start a new recording. |
| Calendar meeting tap shows a black screen | Fixed in this build (Part 13). If it still happens, run `flutter clean && flutter pub get && flutter run --dart-define-from-file=.env`. |

---

## Feature notes — Part 14 (2026-05-18)

### Edit a folder after creating it

Folders are no longer locked once created — every field except the meeting count is editable.

1. Open the **Dossiers** tab and tap the folder you want to change.
2. In the folder detail page, open the overflow menu (top-right) and tap **Modifier**.
3. Change the name, category, colour, or icon. The preview card updates live.
4. Tap **Enregistrer** in the top bar (or **Enregistrer les modifications** at the bottom). You are returned to the detail page with the new look applied.

The **Boîte de réception** (Inbox) is editable as well — you can rename it or change its colour — but it cannot be deleted (its system role as the default fallback folder is preserved).

### Filter the calendar by folder

The Calendrier tab now has a chip row above the month grid. Each chip represents one of your folders.

1. Tap one or more folder chips to filter — only meetings and events from the selected folders will appear on the calendar (dots, day preview, day sheet).
2. Tap **Tous** to clear the filter and see everything again. Tapping the last active chip also clears the filter.
3. When **exactly one** folder is active, tapping the **Planifier** FAB opens the scheduling form with that folder pre-selected, so you can quickly add multiple events to the same folder without re-picking each time.

The filter is per-session — it resets when you close the app. The chip row is hidden when you have fewer than two folders (nothing to filter).
