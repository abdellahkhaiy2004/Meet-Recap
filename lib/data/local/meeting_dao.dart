import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'meeting_dao.g.dart';

@DriftAccessor(tables: [Meetings])
class MeetingDao extends DatabaseAccessor<AppDatabase> with _$MeetingDaoMixin {
  MeetingDao(super.db);

  // ── Queries ────────────────────────────────────────────────────────────────

  /// Watch all meetings in a folder, newest first.
  Stream<List<MeetingData>> watchByFolder(int folderId) =>
      (select(meetings)
            ..where((m) => m.folderId.equals(folderId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
          .watch();

  /// Watch a single meeting — used by MeetingDetailPage for live pipeline state.
  Stream<MeetingData?> watchById(int id) =>
      (select(meetings)..where((m) => m.id.equals(id))).watchSingleOrNull();

  Future<MeetingData?> getById(int id) =>
      (select(meetings)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<MeetingData?> getByDraftId(String draftId) =>
      (select(meetings)..where((m) => m.draftId.equals(draftId)))
          .getSingleOrNull();

  /// Meetings in a date range — used by CalendarPage day bottom-sheet.
  Future<List<MeetingData>> getByDateRange(DateTime from, DateTime to) =>
      (select(meetings)
            ..where((m) => m.createdAt.isBetweenValues(from, to))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
          .get();

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<int> insert(MeetingsCompanion companion) =>
      into(meetings).insert(companion);

  /// Partial update — only sets columns present in [companion].
  Future<void> updateMeeting(MeetingsCompanion companion) =>
      (update(meetings)..where((m) => m.id.equals(companion.id.value)))
          .write(companion);

  Future<void> updatePipelineState(int id, String state) =>
      (update(meetings)..where((m) => m.id.equals(id))).write(
        MeetingsCompanion(pipelineState: Value(state)),
      );

  Future<void> updateTranscript(int id, String transcript) =>
      (update(meetings)..where((m) => m.id.equals(id))).write(
        MeetingsCompanion(transcript: Value(transcript)),
      );

  Future<void> updateSummary(
    int id,
    String summary,
    String detectedLanguage,
  ) =>
      (update(meetings)..where((m) => m.id.equals(id))).write(
        MeetingsCompanion(
          summary: Value(summary),
          detectedLanguage: Value(detectedLanguage),
          pipelineState: const Value('done'),
        ),
      );

  Future<void> linkEvent(int meetingId, int eventId) =>
      (update(meetings)..where((m) => m.id.equals(meetingId))).write(
        MeetingsCompanion(linkedEventId: Value(eventId)),
      );

  Future<int> deleteById(int id) =>
      (delete(meetings)..where((m) => m.id.equals(id))).go();

  Future<void> moveToFolder(int meetingId, int folderId) =>
      (update(meetings)..where((m) => m.id.equals(meetingId))).write(
        MeetingsCompanion(folderId: Value(folderId)),
      );
}
