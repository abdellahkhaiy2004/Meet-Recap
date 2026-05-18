import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/audio_chunker.dart';
import '../../domain/entities/meeting.dart';
import '../local/app_database.dart';
import '../local/meeting_dao.dart';
import '../local/tables.dart';
import '../remote/summary_api.dart';
import '../remote/transcription_api.dart';
import '../remote/translation_api.dart';
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
    required TranslationApi translationApi,
    CalendarRepository? calendarRepository,
  })  : _dao = meetingDao,
        _transcription = transcriptionApi,
        _summary = summaryApi,
        _translation = translationApi,
        _calRepo = calendarRepository;

  final MeetingDao _dao;
  final TranscriptionApi _transcription;
  final SummaryApi _summary;
  final TranslationApi _translation;
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
    String? forcedLanguage,   // IP-0053: null = Whisper auto-detect
    String? translateTo,      // P-0097: null = no translation, else 'fr'/'en'
    bool latinizeDarija = false, // P-0097: rewrite Arabic Darija in Latin
  }) async {
    final effectiveTitle = title.isEmpty
        ? 'Réunion ${DateTime.now().toLocal().toString().substring(0, 16)}'
        : title;

    // Insert row immediately so ProcessingPage has something to watch.
    final id = await _dao.insert(
      MeetingsCompanion.insert(
        draftId: draftId,
        folderId: folderId,
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
      forcedLanguage: forcedLanguage,
      translateTo: translateTo,
      latinizeDarija: latinizeDarija,
    );

    // IP-0039: after success, link the CalendarEvent row to this meeting.
    if (result.isOk && linkedEventId != null && _calRepo != null) {
      await _calRepo!.linkMeeting(linkedEventId, id);
    }

    return result;
  }

  /// Re-runs the full pipeline for a failed meeting using the stored audio
  /// file ([IP-0049]).  Always skips the silence pre-check (user override).
  Future<Result<Meeting>> retryPipeline(
    int meetingId, {
    CancelToken? cancelToken,
    String? forcedLanguage,  // IP-0053
    String? translateTo,
    bool latinizeDarija = false,
  }) async {
    final row = await _dao.getById(meetingId);
    if (row == null) {
      return const Err(NetworkFailure('Réunion introuvable.'));
    }
    final audioFile = File(row.audioPath);
    if (!audioFile.existsSync()) {
      return const Err(NetworkFailure('Fichier audio introuvable.'));
    }
    return _runPipeline(
      id: meetingId,
      audioFile: audioFile,
      cancelToken: cancelToken,
      forceSend: true, // bypass silence check on explicit retry
      forcedLanguage: forcedLanguage,
      translateTo: translateTo,
      latinizeDarija: latinizeDarija,
    );
  }

  Future<Result<Meeting>> _runPipeline({
    required int id,
    required File audioFile,
    CancelToken? cancelToken,
    bool forceSend = false,
    String? forcedLanguage,  // IP-0053: null = Whisper auto-detect
    String? translateTo,        // P-0097
    bool latinizeDarija = false, // P-0097
  }) async {
    // ── Silent audio pre-check (IP-0050) ──────────────────────────────────
    // Heuristic: AAC-LC 16 kHz mono ≈ 4 KB/s. Threshold 1 KB/s is very
    // conservative — catches only near-silent recordings. Skipped on retry
    // (forceSend) so the user can override by pressing "Réessayer".
    if (!forceSend) {
      final row = await _dao.getById(id);
      final dur = row?.durationSeconds ?? 0;
      final fileSize = audioFile.lengthSync();
      if (dur > 5 && fileSize < dur * 1000) {
        await _dao.updatePipelineState(id, 'failed');
        return const Err(EmptyAudioFailure(
          'Enregistrement trop silencieux. Réessayez pour envoyer quand même.',
        ));
      }
    }

    // ── Chunking > 25 MB (IP-0048) ────────────────────────────────────────
    final chunks = await AudioChunker.chunk(audioFile);
    final isChunked = chunks.length > 1;

    // Step 1 — Transcribe (sequential chunks, transcripts joined with newline)
    await _dao.updatePipelineState(id, 'transcribing');
    var fullTranscript = '';

    for (final chunk in chunks) {
      final transcriptResult = await _transcription.transcribe(
        chunk,
        language: forcedLanguage,
        cancelToken: cancelToken,
      );
      if (transcriptResult.isErr) {
        await _dao.updatePipelineState(id, 'failed');
        if (isChunked) await AudioChunker.cleanup(audioFile, chunks);
        return Err((transcriptResult as Err).failure);
      }
      if (fullTranscript.isNotEmpty) fullTranscript += '\n';
      fullTranscript += (transcriptResult as Ok<String>).value;
    }

    if (isChunked) await AudioChunker.cleanup(audioFile, chunks);

    // Detect dominant language now so the post-processing step can decide
    // whether to translate / transliterate. Whisper doesn't return the BCP-47
    // code through our wrapper, so we use the same heuristic as the summary
    // step below.
    final preLang = _heuristicLang(fullTranscript);

    // Step 1b — Optional post-processing (translate to fr/en, Latin Darija).
    // Fails soft: returns the original transcript on any non-cancel error
    // so summarization can still proceed. See TranslationApi.postProcess.
    if (translateTo != null || latinizeDarija) {
      final post = await _translation.postProcess(
        fullTranscript,
        translateTo: translateTo,
        latinizeDarija: latinizeDarija,
        detectedLang: preLang,
        cancelToken: cancelToken,
      );
      if (post.isErr) {
        // Only true cancellations bubble up; soft failures returned Ok.
        await _dao.updatePipelineState(id, 'failed');
        return Err((post as Err).failure);
      }
      fullTranscript = (post as Ok<String>).value;
    }

    await _dao.updateTranscript(id, fullTranscript);

    // Step 2 — Summarize
    await _dao.updatePipelineState(id, 'summarizing');
    final summaryResult = await _summary.summarize(
      fullTranscript,
      cancelToken: cancelToken,
    );
    if (summaryResult.isErr) {
      await _dao.updatePipelineState(id, 'failed');
      return Err((summaryResult as Err).failure);
    }
    final summaryMd = (summaryResult as Ok<String>).value;

    // Detect dominant language from first non-empty content line (heuristic).
    final detectedLang = _heuristicLang(fullTranscript);

    await _dao.updateSummary(id, summaryMd, detectedLang);

    final row = await _dao.getById(id);
    return Ok(_rowToEntity(row!));
  }

  // ── Live watch ─────────────────────────────────────────────────────────────

  Stream<Meeting?> watchById(int id) =>
      _dao.watchById(id).map((r) => r == null ? null : _rowToEntity(r));

  /// Polls until the DB row for [draftId] appears (inserted at the start of
  /// [processRecording]), then delegates to [watchById] for live state updates.
  Stream<Meeting?> watchByDraftId(String draftId) async* {
    int? id;
    while (id == null) {
      final row = await _dao.getByDraftId(draftId);
      if (row != null) {
        id = row.id;
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    yield* watchById(id);
  }

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
    translationApi: ref.watch(translationApiProvider),
    calendarRepository: ref.watch(calendarRepositoryProvider),
  );
});
