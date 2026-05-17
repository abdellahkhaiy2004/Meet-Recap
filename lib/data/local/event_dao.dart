import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [CalendarEvents])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  // ── Queries ────────────────────────────────────────────────────────────────

  /// Watch all events in a date range — drives CalendarPage dot markers.
  Stream<List<CalendarEventData>> watchByDateRange(
    DateTime from,
    DateTime to,
  ) =>
      (select(calendarEvents)
            ..where(
              (e) => e.startsAt.isBetweenValues(from, to),
            )
            ..orderBy([(e) => OrderingTerm.asc(e.startsAt)]))
          .watch();

  Future<List<CalendarEventData>> getByDateRange(
    DateTime from,
    DateTime to,
  ) =>
      (select(calendarEvents)
            ..where((e) => e.startsAt.isBetweenValues(from, to))
            ..orderBy([(e) => OrderingTerm.asc(e.startsAt)]))
          .get();

  Future<CalendarEventData?> getById(int id) =>
      (select(calendarEvents)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<List<CalendarEventData>> getByFolder(int folderId) =>
      (select(calendarEvents)
            ..where((e) => e.folderId.equals(folderId))
            ..orderBy([(e) => OrderingTerm.asc(e.startsAt)]))
          .get();

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<int> insert(CalendarEventsCompanion companion) =>
      into(calendarEvents).insert(companion);

  Future<void> updateEvent(CalendarEventsCompanion companion) =>
      (update(calendarEvents)
            ..where((e) => e.id.equals(companion.id.value)))
          .write(companion);

  Future<void> linkMeeting(int eventId, int meetingId) =>
      (update(calendarEvents)..where((e) => e.id.equals(eventId))).write(
        CalendarEventsCompanion(linkedMeetingId: Value(meetingId)),
      );

  Future<int> deleteById(int id) =>
      (delete(calendarEvents)..where((e) => e.id.equals(id))).go();
}
