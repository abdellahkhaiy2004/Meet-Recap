import 'dart:math';

/// Generates a time-based unique draft ID for a new recording session.
/// Pure Dart — no framework dependencies.
class StartRecording {
  const StartRecording();

  /// Returns a unique draft ID. The caller is responsible for passing this
  /// ID to [AudioRecorder.start] and later to [StopAndProcess].
  String call() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rng = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'draft_${ts}_$rng';
  }
}
