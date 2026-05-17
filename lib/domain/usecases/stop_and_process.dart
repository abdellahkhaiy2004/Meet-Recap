import 'dart:io';

/// Value returned when recording is stopped and the audio file is ready.
/// Pure Dart — carries no Flutter/Dio/Drift dependencies.
class RecordingResult {
  const RecordingResult({
    required this.draftId,
    required this.audioFile,
    required this.duration,
    this.folderId,
  });

  final String draftId;
  final File audioFile;
  final Duration duration;
  final String? folderId;
}

/// Use-case: validates the stopped recording and packages it for the pipeline.
/// Actual transcription + summarisation happens in [MeetingRepository] ([IP-0024]).
class StopAndProcess {
  const StopAndProcess();

  /// Returns null if the audio file is missing or too short to process.
  RecordingResult? call({
    required String draftId,
    required File? audioFile,
    required Duration elapsed,
    String? folderId,
  }) {
    if (audioFile == null || !audioFile.existsSync()) return null;
    if (elapsed.inSeconds < 2) return null; // too short to transcribe
    return RecordingResult(
      draftId: draftId,
      audioFile: audioFile,
      duration: elapsed,
      folderId: folderId,
    );
  }
}
