/// Pure-Dart domain entity for a scheduled calendar event (architecture §7, §10).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.folderId,
    required this.startsAt,
    required this.endsAt,
    required this.reminderMinutes,
    required this.notificationId,
    this.linkedMeetingId,
  });

  final int id;
  final String title;
  final int folderId;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Minutes before [startsAt] to fire the local notification. 0 = at start.
  final int reminderMinutes;

  /// ID used with flutter_local_notifications so it can be cancelled.
  final int notificationId;

  /// Set after the meeting is recorded and linked to this event ([IP-0039]).
  final int? linkedMeetingId;

  CalendarEvent copyWith({
    int? id,
    String? title,
    int? folderId,
    DateTime? startsAt,
    DateTime? endsAt,
    int? reminderMinutes,
    int? notificationId,
    int? linkedMeetingId,
  }) =>
      CalendarEvent(
        id: id ?? this.id,
        title: title ?? this.title,
        folderId: folderId ?? this.folderId,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        notificationId: notificationId ?? this.notificationId,
        linkedMeetingId: linkedMeetingId ?? this.linkedMeetingId,
      );
}
