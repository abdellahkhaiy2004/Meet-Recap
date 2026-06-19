# Meet-Recap

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

---

## Feature notes — Part 15

### Notes pendant la réunion ([IP-0061])

A new card "**Notes de réunion**" appears on the Record page as soon as recording starts. Type free-form notes — decisions to remember, names to capture, points to clarify. They are:

- **Persisted** with the meeting (new `meetings.user_notes` column, schema v2 migration). Survives app restart, retries, and re-summarisation.
- **Sent to the LLM** as part of the summarisation prompt. The system prompt now contains a rule asking the model to prioritise the notes in the **Décisions**, **Action items**, and **Résumé global** sections. The transcript is still the primary source — the notes act as a guided emphasis from the user.
- **Displayed separately** in the meeting detail page. The "Transcript" tab now shows two cards: one for the raw transcription and one ("Mes notes") for the notes you wrote. Each card has its own copy button. When you took no notes, the second card simply shows "Aucune note prise pendant cette réunion." in italic.

The notes card is hidden when the recorder is idle so the empty landing screen stays minimal. It reappears whenever a session is active or paused. Typing during a `Paused` state is fine — notes are part of the session, not the audio.

**Migration notice.** Existing databases will auto-upgrade from schema v1 to v2 on first launch after this update; the new column starts empty for past meetings.



## Feature notes — Part 16

### Android 15 and Android 16 support ([IP-0062])

The app now compiles and targets **API level 36 (Android 16)**, which also enables every Android 15 (API 35) platform behavior. The install floor is unchanged — `minSdk` stays at Flutter's default (API 21, Android 5.0), so the same range of devices keeps working.

**What this means as an operator.**

- The release manifest now declares all the runtime permissions the app needs explicitly: `INTERNET`, `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`. No more relying on transitive plugin manifests.
- On Android 13+ the first scheduled reminder will prompt for notification permission. Accept it once.
- On Android 14+ exact-alarm scheduling for calendar reminders is granted via `USE_EXACT_ALARM` (no special user trip to system settings needed for the timekeeping use case).
- After a reboot, pending reminders are automatically re-armed (`RECEIVE_BOOT_COMPLETED`).
- Edge-to-edge is enforced by Android 15+ — Material 3 `Scaffold` already handles insets, so no visible regression is expected. If a real device shows a control clipped by the gesture bar, wrap that screen's body in `SafeArea(bottom: true)`.

### Troubleshooting on Android 15 / 16

| Symptom | Cause | Fix |
| --- | --- | --- |
| Notifications never appear on Android 13+ | `POST_NOTIFICATIONS` denied at first run | Settings → Apps → auto_derdacha → Notifications → enable |
| Exact reminders fire late on Android 12 | OEM aggressively batched the alarm | `permission_handler`'s `scheduleExactAlarm` request is honored on stock Android; on heavy-skin OEMs add the app to the battery-optimisation exception list |
| `INSTALL_FAILED_OLDER_SDK` when sideloading | Device runs API < 21 (Android < 5.0) | Outside support window; upgrade the device |
| App crashes on Android 15 device with 16 KB pages | A native plugin still ships 4 KB-aligned .so files | Bump the affected plugin to a 16 KB-ready minor (e.g. `sqlite3_flutter_libs ^0.5.27+`) in a separate work loop and rebuild |
| FAB hidden behind the gesture bar on Android 15 | Edge-to-edge enforcement, screen body lacks bottom inset | Wrap the body in `SafeArea(bottom: true)` |

### Building for Android 15 / 16

No new command. The existing flow works as-is:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug      # or --release once signing is wired up
```

The build now picks up `compileSdk = 36` / `targetSdk = 36` from `android/app/build.gradle.kts` regardless of which Flutter SDK constant the local installation ships with.

### Troubleshooting — silent recordings (Android)

If a meeting finishes in state **Terminé** but the Transcription card looks empty:

1. Confirm the **microphone is not blocked at the OS level**:
   - Pull down the notification shade and look for a **"Microphone access blocked"** tile or a mic-mute icon — toggle it off.
   - Settings → Privacy / Privacy controls → **Microphone access** → must be **On**.
   - Settings → Apps → auto_derdacha → Permissions → **Microphone** → **Allowed**.
2. Start a new recording inside the app and **watch the waveform on the record screen**. If the waveform stays flat at zero while you speak, the OS is silencing the input; no code path on the client side can recover the audio.
3. As of [P-0117] the client now rejects transcripts with fewer than 3 letter-or-digit characters (typical Whisper silence hallucinations: `.`, `you`, `Music`, the Amara.org subtitle boilerplate). When this happens you will see **"Enregistrement silencieux. Vérifiez le microphone et réessayez."** on the processing screen instead of a silent success.

## Branding — "meet-recap" ([IP-0063])

As of [IP-0063] the application's launcher label is **meet-recap**. This is a display-only rename via `<application android:label="meet-recap">` in `android/app/src/main/AndroidManifest.xml`. The internal codebase identifier stays as `auto_derdacha` (Dart package, Android `applicationId = com.autoderdacha.auto_derdacha`, Drift DB filename) so that:

- Existing installs upgrade in place — no data loss, no fresh install.
- Earlier sections of this README that reference `auto-dardacha` remain historically accurate (this file is append-only per `instructions.md` §2.1).

**Where you will see the new name.** Home-screen launcher icon caption, recents (overview) task title, and the default activity label.

**Where the old name still appears (intentionally).** App-info screen on the device (shows `com.autoderdacha.auto_derdacha`), build artefact paths (`build\app\outputs\flutter-apk\...`), Dart import statements, and the Drift database file on disk. None of these are user-visible during normal app use.

**Promoting to a full rename later.** If you decide to rename the applicationId too, plan it as a dedicated migration: export Drift data, change `applicationId` and `namespace`, reinstall, re-import. Users without the migration step will lose access to old meetings because Android treats a new applicationId as a different app with isolated data.

### Launcher icon ([IP-0064])

The Android launcher icon source is `assets/icon/app_icon.png` (1024×1024 transparent PNG). The mipmap density buckets and the adaptive-icon XML under `android/app/src/main/res/mipmap-*/` are **generated** — do not hand-edit them.

**Regenerate after editing the source:**
```bash
dart run flutter_launcher_icons
```

The generator pulls its config from the `flutter_launcher_icons:` block at the bottom of `pubspec.yaml`. The adaptive icon background is the brand violet `#7C3AED` so the masked region (squircle / circle / rounded square, depending on launcher) always shows brand colour around the foreground microphone.

### Launcher icon refresh ([IP-0065])

The launcher icon source was refreshed to a pre-tiled rounded-square design (file `assets/icon/app_icon.png`, plus a lavender alt at `assets/icon/app_icon_light.png`). Because the source now embeds its own dark tile, the adaptive-icon background in `pubspec.yaml` is `#15172A` (matches the tile) — **not** the brand violet `#7C3AED` that the earlier transparent-glyph source used. Rule of thumb:

| Foreground type | Set `adaptive_icon_background` to |
| --- | --- |
| Transparent-bg glyph | Brand colour (`#7C3AED` in this codebase) |
| Pre-tiled icon (tile baked in) | The tile's own background colour (`#15172A` here) |

The display label was also rewritten from `meet-recap` (kebab) to `Meet Recap` (title case + space) per Android's launcher-naming convention.

## Feature notes — Slices A–D ([IP-0066..0069])

The four-part owner request from [P-0126] landed across four commits:

- **Slice A — Waveform fix** ([IP-0066], [SL-0069]). The microphone amplitude bars now animate on every recording, not just the first one. Internal lifecycle fix; no user-facing setting.
- **Slice B — Folder multi-select** ([IP-0067], [SL-0070]). Long-press any folder card on the Dossiers tab to enter selection mode; tap to add/remove; the contextual appbar offers a batch Supprimer. Inbox is exempt. Android Back exits selection mode without leaving the page.
- **Slice C — Meeting multi-select inside a folder** ([IP-0068], [SL-0071]). Same long-press contextual-appbar pattern on meeting tiles inside FolderDetailPage. Two batch actions: Déplacer vers (opens a folder picker bottom sheet) and Supprimer (confirmation dialog warns audio is also deleted). Calendar day-sheet multi-select is intentionally deferred — modal-inside-modal UX issue.
- **Slice D — Historique tab** ([IP-0069], [SL-0072]). New bottom-nav destination between Calendrier and Dossiers. Reverse-chronological list of every meeting, grouped by local calendar day with inline French date headers. Reuses the meeting selection controller from slice C, but exposes only batch delete (move-to-folder stays scoped to FolderDetailPage where the source/target relationship is unambiguous).
