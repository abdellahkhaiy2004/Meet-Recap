/// Pipeline state for a meeting recording (architecture §10, §12).
///
/// Tracks where the recording is in the transcribe → summarize → saved flow.
enum PipelineState {
  /// Audio captured locally; not yet sent to API.
  pending,

  /// Transcription request in flight.
  transcribing,

  /// Summarization request in flight.
  summarizing,

  /// Both API calls succeeded; markdown is stored.
  done,

  /// One or both API calls failed; retry is available.
  failed,
}

/// Pure-Dart domain entity for a recorded meeting (architecture §10).
class Meeting {
  const Meeting({
    required this.id,
    required this.draftId,
    required this.folderId,
    required this.title,
    required this.audioPath,
    required this.durationSeconds,
    required this.transcript,
    required this.summary,
    required this.pipelineState,
    required this.detectedLanguage,
    required this.createdAt,
    this.linkedEventId,
  });

  final int id;
  final String draftId;
  final int folderId;
  final String title;
  final String audioPath;
  final int durationSeconds;
  final String transcript;
  final String summary;
  final PipelineState pipelineState;
  final String detectedLanguage;
  final DateTime createdAt;
  final int? linkedEventId;

  Meeting copyWith({
    int? id,
    String? draftId,
    int? folderId,
    String? title,
    String? audioPath,
    int? durationSeconds,
    String? transcript,
    String? summary,
    PipelineState? pipelineState,
    String? detectedLanguage,
    DateTime? createdAt,
    int? linkedEventId,
  }) =>
      Meeting(
        id: id ?? this.id,
        draftId: draftId ?? this.draftId,
        folderId: folderId ?? this.folderId,
        title: title ?? this.title,
        audioPath: audioPath ?? this.audioPath,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        transcript: transcript ?? this.transcript,
        summary: summary ?? this.summary,
        pipelineState: pipelineState ?? this.pipelineState,
        detectedLanguage: detectedLanguage ?? this.detectedLanguage,
        createdAt: createdAt ?? this.createdAt,
        linkedEventId: linkedEventId ?? this.linkedEventId,
      );
}
