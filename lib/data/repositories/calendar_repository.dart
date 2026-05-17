import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/calendar_event.dart';
import '../local/app_database.dart';
import '../local/event_dao.dart';
import '../local/tables.dart';

/// Read/write access for calendar events (architecture §7, IP-0025).
///
/// Scheduling the actual OS notification is handled separately by
/// NotificationService ([IP-0038]) — this repository only persists event data.
class CalendarRepository {
  const CalendarRepository(this._dao);

  final EventDao _dao;

  // ── Reads ──────────────────────────────────────────────────────────────────

  Stream<List<CalendarEvent>> watchByDateRange(DateTime from, DateTime to) =>
      _dao.watchByDateRange(from, to).map((rows) => rows.map(_rowToEntity).toList());

  Future<List<CalendarEvent>> getByDateRange(DateTime from, DateTime to) async {
    final rows = await _dao.getByDateRange(from, to);
    return rows.map(_rowToEntity).toList();
  }

  Future<CalendarEvent?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _rowToEntity(row);
  }

  Future<List<CalendarEvent>> getByFolder(int folderId) async {
    final rows = await _dao.getByFolder(folderId);
    return rows.map(_rowToEntity).toList();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Persists a new event and returns its assigned id.
  ///
  /// The caller (ScheduleEventPage / NotificationService) is responsible for
  /// scheduling the OS alarm **after** obtaining this id ([IP-0038]).
  Future<int> scheduleEvent({
    required String title,
    required int folderId,
    required DateTime startsAt,
    required DateTime endsAt,
    required int reminderMinutes,
    required int notificationId,
  }) =>
      _dao.insert(
        CalendarEventsCompanion.insert(
          title: title,
          folderId: Value(folderId),
          startsAt: startsAt,
          endsAt: endsAt,
          reminderMinutes: Value(reminderMinutes),
          notificationId: notificationId,
        ),
      );

  Future<void> updateEvent({
    required int id,
    String? title,
    int? folderId,
    DateTime? startsAt,
    DateTime? endsAt,
    int? reminderMinutes,
    int? notificationId,
  }) async {
    final companion = CalendarEventsCompanion(
      id: Value(id),
      title: title != null ? Value(title) : const Value.absent(),
      folderId: folderId != null ? Value(folderId) : const Value.absent(),
      startsAt: startsAt != null ? Value(startsAt) : const Value.absent(),
      endsAt: endsAt != null ? Value(endsAt) : const Value.absent(),
      reminderMinutes: reminderMinutes != null
          ? Value(reminderMinutes)
          : const Value.absent(),
      notificationId: notificationId != null
          ? Value(notificationId)
          : const Value.absent(),
    );
    await _dao.updateEvent(companion);
  }

  /// Links a completed meeting to this event ([IP-0039]).
  Future<void> linkMeeting(int eventId, int meetingId) =>
      _dao.linkMeeting(eventId, meetingId);

  Future<int> deleteById(int id) => _dao.deleteById(id);

  // ── Mapping ────────────────────────────────────────────────────────────────

  static CalendarEvent _rowToEntity(CalendarEventData row) => CalendarEvent(
        id: row.id,
        title: row.title,
        folderId: row.folderId,
        startsAt: row.startsAt,
        endsAt: row.endsAt,
        reminderMinutes: row.reminderMinutes,
        notificationId: row.notificationId,
        linkedMeetingId: row.linkedMeetingId,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(appDatabaseProvider).eventDao);
});
