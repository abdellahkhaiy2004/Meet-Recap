import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/meeting.dart';
import '../local/app_database.dart';
import '../local/meeting_dao.dart';
import '../local/tables.dart';
import '../remote/summary_api.dart';
import '../remote/transcription_api.dart';
import 'calendar_repository.dart';

/// Orchestrates the full pipeline: record → transcribe → summarize → persist.
///
/// Each step updates `pipeline_state` in the DB so ProcessingPage ([IP-0058])
/// can watch live progress via [watchById].
class MeetingRepository {
  const MeetingRepository({
    required MeetingDao meetingDao,
    required TranscriptionApi transcriptionApi,
    required SummaryApi summaryApi,
    CalendarRepository? calendarRepository,
  })  : _dao = meetingDao,
        _transcription = transcriptionApi,
        _summary = summaryApi,
        _calRepo = calendarRepository;

  final MeetingDao _dao;
  final TranscriptionApi _transcription;
  final SummaryApi _summary;
  // Nullable — injected at Part 7; avoids circular dep before CalendarRepo exists.
  final CalendarRepository? _calRepo;

  // ── Pipeline ───────────────────────────────────────────────────────────────

  /// Creates a DB row in `pending` state immediately after recording stops,
  /// then runs transcription → summarization and updates the row in place.
  ///
  /// Returns [Ok<Meeting>] on full success, [Err<Failure>] on any API failure.
  /// On failure the row remains with `pipelineState = failed` so it can be
  /// retried via [retryPipeline] ([IP-0049]).
  Future<Result<Meeting>> processRecording({
    required String draftId,
    required File audioFile,
    required int durationSeconds,
    required int folderId,
    String title = '',
    int? linkedEventId,  // IP-0039: set when recording is tied to a calendar event
    CancelToken? cancelToken,
  }) async {
    final effectiveTitle = title.isEmpty
        ? 'Réunion ${DateTime.now().toLocal().toString().substring(0, 16)}'
        : title;

    // Insert row immediately so ProcessingPage has something to watch.
    final id = await _dao.insert(
      MeetingsCompanion.insert(
        draftId: draftId,
        folderId: Value(folderId),
        title: effectiveTitle,
        audioPath: audioFile.path,
        durationSeconds: Value(durationSeconds),
        pipelineState: const Value('pending'),
        linkedEventId: Value(linkedEventId),
      ),
    );

    final result = await _runPipeline(
      id: id,
      audioFile: audioFile,
      cancelToken: cancelToken,
    );

    // IP-0039: after success, link the CalendarEvent row to this meeting.
    if (result.isOk && linkedEventId != null && _calRepo != null) {
      await _calRepo!.linkMeeting(linkedEventId, id);
    }

    return result;
  }

  /// Re-runs transcription + summarization for a failed meeting using the
  /// already-stored audio file ([IP-0049]).
  Future<Result<Meeting>> retryPipeline(
    int meetingId, {
    CancelToken? cancelToken,
  }) async {
    final row = await _dao.getById(meetingId);
    if (row == null) {
      return const Err(NetworkFailure('Réunion introuvable.'));
    }
    final audioFile = File(row.audioPath);
    if (!audioFile.existsSync()) {
      return const Err(FileTooLargeFailure()); // file gone — treat as error
    }
    return _runPipeline(
      id: meetingId,
      audioFile: audioFile,
      cancelToken: cancelToken,
    );
  }

  Future<Result<Meeting>> _runPipeline({
    required int id,
    required File audioFile,
    CancelToken? cancelToken,
  }) async {
    // Step 1 — Transcribe
    await _dao.updatePipelineState(id, 'transcribing');
    final transcriptResult = await _transcription.transcribe(
      audioFile,
      cancelToken: cancelToken,
    );
    if (transcriptResult.isErr) {
      await _dao.updatePipelineState(id, 'failed');
      return Err((transcriptResult as Err).failure);
    }
    final transcript = (transcriptResult as Ok<String>).value;
    await _dao.updateTranscript(id, transcript);

    // Step 2 — Summarize
    await _dao.updatePipelineState(id, 'summarizing');
    final summaryResult = await _summary.summarize(
      transcript,
      cancelToken: cancelToken,
    );
    if (summaryResult.isErr) {
      await _dao.updatePipelineState(id, 'failed');
      return Err((summaryResult as Err).failure);
    }
    final summaryMd = (summaryResult as Ok<String>).value;

    // Detect dominant language from first non-empty content line (heuristic).
    final detectedLang = _heuristicLang(transcript);

    await _dao.updateSummary(id, summaryMd, detectedLang);

    final row = await _dao.getById(id);
    return Ok(_rowToEntity(row!));
  }

  // ── Live watch ─────────────────────────────────────────────────────────────

  Stream<Meeting?> watchById(int id) =>
      _dao.watchById(id).map((r) => r == null ? null : _rowToEntity(r));

  Stream<List<Meeting>> watchByFolder(int folderId) =>
      _dao.watchByFolder(folderId).map((rows) => rows.map(_rowToEntity).toList());

  Future<Meeting?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _rowToEntity(row);
  }

  Future<Meeting?> getByDraftId(String draftId) async {
    final row = await _dao.getByDraftId(draftId);
    return row == null ? null : _rowToEntity(row);
  }

  Future<List<Meeting>> getByDateRange(DateTime from, DateTime to) async {
    final rows = await _dao.getByDateRange(from, to);
    return rows.map(_rowToEntity).toList();
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> rename(int id, String newTitle) =>
      _dao.updateMeeting(MeetingsCompanion(
        id: Value(id),
        title: Value(newTitle),
      ));

  Future<void> moveToFolder(int meetingId, int folderId) =>
      _dao.moveToFolder(meetingId, folderId);

  /// Re-runs the summarization step using the already-stored transcript.
  /// Used by MeetingDetailPage "Re-summarize" action ([IP-0028]).
  Future<Result<Meeting>> reSummarize(
    int meetingId, {
    CancelToken? cancelToken,
  }) async {
    final row = await _dao.getById(meetingId);
    if (row == null) return const Err(NetworkFailure('Réunion introuvable.'));
    if (row.transcript.trim().isEmpty) {
      return const Err(EmptyAudioFailure('Aucun transcript à résumer.'));
    }

    await _dao.updatePipelineState(meetingId, 'summarizing');
    final summaryResult =
        await _summary.summarize(row.transcript, cancelToken: cancelToken);
    if (summaryResult.isErr) {
      await _dao.updatePipelineState(meetingId, 'failed');
      return Err((summaryResult as Err).failure);
    }
    final summaryMd = (summaryResult as Ok<String>).value;
    await _dao.updateSummary(meetingId, summaryMd, row.detectedLanguage);

    final updated = await _dao.getById(meetingId);
    return Ok(_rowToEntity(updated!));
  }

  Future<void> linkEvent(int meetingId, int eventId) =>
      _dao.linkEvent(meetingId, eventId);

  Future<int> delete(int id) => _dao.deleteById(id);

  // ── Mapping ────────────────────────────────────────────────────────────────

  static Meeting _rowToEntity(MeetingData row) => Meeting(
        id: row.id,
        draftId: row.draftId,
        folderId: row.folderId,
        title: row.title,
        audioPath: row.audioPath,
        durationSeconds: row.durationSeconds,
        transcript: row.transcript,
        summary: row.summary,
        pipelineState: _parsePipelineState(row.pipelineState),
        detectedLanguage: row.detectedLanguage,
        createdAt: row.createdAt,
        linkedEventId: row.linkedEventId,
      );

  static PipelineState _parsePipelineState(String s) => switch (s) {
        'transcribing' => PipelineState.transcribing,
        'summarizing' => PipelineState.summarizing,
        'done' => PipelineState.done,
        'failed' => PipelineState.failed,
        _ => PipelineState.pending,
      };

  /// Very rough heuristic: if transcript contains Arabic characters → 'ar',
  /// else if it contains accented French characters → 'fr', else 'en'.
  static String _heuristicLang(String text) {
    if (RegExp(r'[؀-ۿ]').hasMatch(text)) return 'ar';
    if (RegExp(r'[àâçéèêëîïôùûüæœ]', caseSensitive: false).hasMatch(text)) {
      return 'fr';
    }
    return 'en';
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return MeetingRepository(
    meetingDao: ref.watch(appDatabaseProvider).meetingDao,
    transcriptionApi: ref.watch(transcriptionApiProvider),
    summaryApi: ref.watch(summaryApiProvider),
    calendarRepository: ref.watch(calendarRepositoryProvider),
  );
});
