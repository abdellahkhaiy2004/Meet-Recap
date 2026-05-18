import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Theme-mode notifier ────────────────────────────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system; // synchronous default before prefs load
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = _parse(raw);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _serialize(mode));
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
        'light'  => ThemeMode.light,
        'dark'   => ThemeMode.dark,
        _        => ThemeMode.system,
      };

  static String _serialize(ThemeMode m) => switch (m) {
        ThemeMode.light  => 'light',
        ThemeMode.dark   => 'dark',
        ThemeMode.system => 'system',
      };
}

// Exposed globally so app.dart's MaterialApp.router can watch it.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ── Forced-language notifier (IP-0053) ────────────────────────────────────

/// Persists the user's language override for Whisper transcription.
/// null → auto-detect (default); otherwise a BCP-47 code passed to the API.
class ForcedLanguageNotifier extends Notifier<String?> {
  static const _key = 'forced_language';

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> set(String? lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    if (lang == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, lang);
    }
  }
}

final forcedLanguageProvider =
    NotifierProvider<ForcedLanguageNotifier, String?>(
  ForcedLanguageNotifier.new,
);

// ── Transcript translation target ─────────────────────────────────────────
// Owner-requested feature: after Whisper returns the raw transcript, optionally
// translate it to FR or EN via the Groq LLM. null = no translation.

class TranslateTranscriptToNotifier extends Notifier<String?> {
  static const _key = 'translate_transcript_to';

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> set(String? lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    if (lang == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, lang);
    }
  }
}

final translateTranscriptToProvider =
    NotifierProvider<TranslateTranscriptToNotifier, String?>(
  TranslateTranscriptToNotifier.new,
);

// ── Darija Latin script preference ────────────────────────────────────────
// Owner-requested feature: when Whisper outputs Darija in Arabic script, the
// LLM post-processing step transliterates it to Latin (so the transcript and
// summary both use Latin Darija). Default false = keep Arabic script.

class DarijaLatinizeNotifier extends Notifier<bool> {
  static const _key = 'darija_latinize';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool v) async {
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, v);
  }
}

final darijaLatinizeProvider =
    NotifierProvider<DarijaLatinizeNotifier, bool>(
  DarijaLatinizeNotifier.new,
);

// ── SettingsPage ───────────────────────────────────────────────────────────

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode      = ref.watch(themeModeProvider);
    final forcedLanguage = ref.watch(forcedLanguageProvider);
    final translateTo    = ref.watch(translateTranscriptToProvider);
    final darijaLatinize = ref.watch(darijaLatinizeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────
          _SectionHeader('Apparence'),
          RadioListTile<ThemeMode>(
            title: const Text('Système (défaut)'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Clair'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Sombre'),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v!),
          ),
          const Divider(),

          // ── Transcription language (IP-0053) ──────────────────────────
          _SectionHeader('Langue (transcription)'),
          RadioListTile<String?>(
            title: const Text('Auto (détection automatique)'),
            subtitle: const Text('Darija / FR / EN code-switching'),
            value: null,
            groupValue: forcedLanguage,
            onChanged: (v) =>
                ref.read(forcedLanguageProvider.notifier).set(v),
          ),
          RadioListTile<String?>(
            title: const Text('Arabe'),
            value: 'ar',
            groupValue: forcedLanguage,
            onChanged: (v) =>
                ref.read(forcedLanguageProvider.notifier).set(v),
          ),
          RadioListTile<String?>(
            title: const Text('Français'),
            value: 'fr',
            groupValue: forcedLanguage,
            onChanged: (v) =>
                ref.read(forcedLanguageProvider.notifier).set(v),
          ),
          RadioListTile<String?>(
            title: const Text('Anglais'),
            value: 'en',
            groupValue: forcedLanguage,
            onChanged: (v) =>
                ref.read(forcedLanguageProvider.notifier).set(v),
          ),
          const Divider(),

          // ── Translation target ────────────────────────────────────────
          _SectionHeader('Traduire le transcript'),
          RadioListTile<String?>(
            title: const Text('Ne pas traduire (défaut)'),
            subtitle: const Text('Garder la langue d\'origine'),
            value: null,
            groupValue: translateTo,
            onChanged: (v) =>
                ref.read(translateTranscriptToProvider.notifier).set(v),
          ),
          RadioListTile<String?>(
            title: const Text('Traduire en français'),
            value: 'fr',
            groupValue: translateTo,
            onChanged: (v) =>
                ref.read(translateTranscriptToProvider.notifier).set(v),
          ),
          RadioListTile<String?>(
            title: const Text('Traduire en anglais'),
            value: 'en',
            groupValue: translateTo,
            onChanged: (v) =>
                ref.read(translateTranscriptToProvider.notifier).set(v),
          ),
          const Divider(),

          // ── Darija Latin transliteration ──────────────────────────────
          _SectionHeader('Darija — alphabet'),
          SwitchListTile(
            title: const Text('Darija en alphabet latin'),
            subtitle: const Text(
              'Translittère le Darija (arabe) en lettres latines. '
              'S\'applique au transcript et au résumé.',
            ),
            value: darijaLatinize,
            onChanged: (v) =>
                ref.read(darijaLatinizeProvider.notifier).set(v),
          ),
          const Divider(),

          // ── About ─────────────────────────────────────────────────────
          _SectionHeader('À propos'),
          const ListTile(
            title: Text('Auto-Derdacha'),
            subtitle: Text(
              'v0.0.1 — Enregistreur multilingue (Darija / FR / EN)',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
