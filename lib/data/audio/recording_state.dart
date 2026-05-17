sealed class RecordingState {
  const RecordingState();
}

final class Idle extends RecordingState {
  const Idle();
}

final class Recording extends RecordingState {
  const Recording({required this.elapsed, required this.amplitude});

  /// Wall-clock time since recording started.
  final Duration elapsed;

  /// Normalised amplitude 0.0 (silence) → 1.0 (peak), derived from dBFS.
  final double amplitude;
}

final class Paused extends RecordingState {
  const Paused({required this.elapsed});
  final Duration elapsed;
}

final class RecordingError extends RecordingState {
  const RecordingError(this.message);
  final String message;
}
