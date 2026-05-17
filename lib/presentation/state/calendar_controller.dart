import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/entities/meeting.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class CalendarState {
  const CalendarState({
    required this.focusedDay,
    this.selectedDay,
    this.events = const {},
    this.meetings = const {},
    this.isLoading = false,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;

  /// Events keyed by date (time stripped to midnight UTC).
  final Map<DateTime, List<CalendarEvent>> events;

  /// Past meetings keyed by date (date recorded, time stripped).
  final Map<DateTime, List<Meeting>> meetings;

  final bool isLoading;

  CalendarState copyWith({
    DateTime? focusedDay,
    DateTime? selectedDay,
    Map<DateTime, List<CalendarEvent>>? events,
    Map<DateTime, List<Meeting>>? meetings,
    bool? isLoading,
  }) =>
      CalendarState(
        focusedDay: focusedDay ?? this.focusedDay,
        selectedDay: selectedDay ?? this.selectedDay,
        events: events ?? this.events,
        meetings: meetings ?? this.meetings,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CalendarController extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final now = DateTime.now();
    // Fetch data for the current month on first build.
    Future.microtask(() => fetchForMonth(DateTime(now.year, now.month)));
    return CalendarState(focusedDay: now, selectedDay: now);
  }

  CalendarRepository get _calRepo => ref.read(calendarRepositoryProvider);
  MeetingRepository get _meetRepo => ref.read(meetingRepositoryProvider);

  // ── Page navigation ────────────────────────────────────────────────────────

  void setFocusedDay(DateTime day) {
    state = state.copyWith(focusedDay: day);
    fetchForMonth(DateTime(day.year, day.month));
  }

  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: day, focusedDay: day);
  }

  // ── Data fetch ─────────────────────────────────────────────────────────────

  Future<void> fetchForMonth(DateTime month) async {
    state = state.copyWith(isLoading: true);

    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final eventList = await _calRepo.getByDateRange(from, to);
    final meetingList = await _meetRepo.getByDateRange(from, to);

    final eventsMap = <DateTime, List<CalendarEvent>>{};
    for (final e in eventList) {
      final key = _dayKey(e.startsAt);
      eventsMap.putIfAbsent(key, () => []).add(e);
    }

    final meetingsMap = <DateTime, List<Meeting>>{};
    for (final m in meetingList) {
      final key = _dayKey(m.createdAt);
      meetingsMap.putIfAbsent(key, () => []).add(m);
    }

    state = state.copyWith(
      events: eventsMap,
      meetings: meetingsMap,
      isLoading: false,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<CalendarEvent> eventsForDay(DateTime day) =>
      state.events[_dayKey(day)] ?? [];

  List<Meeting> meetingsForDay(DateTime day) =>
      state.meetings[_dayKey(day)] ?? [];

  static DateTime _dayKey(DateTime dt) =>
      DateTime.utc(dt.year, dt.month, dt.day);
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);
