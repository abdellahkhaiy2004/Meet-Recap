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
    this.selectedFolderIds,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;

  /// Events keyed by date (time stripped to midnight UTC).
  final Map<DateTime, List<CalendarEvent>> events;

  /// Past meetings keyed by date (date recorded, time stripped).
  final Map<DateTime, List<Meeting>> meetings;

  final bool isLoading;

  /// Folder filter (IP-0060/H1). null = show all; non-null set = show only
  /// meetings/events whose folderId is in the set. Empty set = hide everything.
  final Set<int>? selectedFolderIds;

  CalendarState copyWith({
    DateTime? focusedDay,
    DateTime? selectedDay,
    Map<DateTime, List<CalendarEvent>>? events,
    Map<DateTime, List<Meeting>>? meetings,
    bool? isLoading,
    Object? selectedFolderIds = _unset,
  }) =>
      CalendarState(
        focusedDay: focusedDay ?? this.focusedDay,
        selectedDay: selectedDay ?? this.selectedDay,
        events: events ?? this.events,
        meetings: meetings ?? this.meetings,
        isLoading: isLoading ?? this.isLoading,
        selectedFolderIds: identical(selectedFolderIds, _unset)
            ? this.selectedFolderIds
            : selectedFolderIds as Set<int>?,
      );
}

// Sentinel for nullable copyWith — lets callers pass null explicitly to reset
// the filter without us misreading "missing argument" as "set to null".
const _unset = Object();

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

  // ── Folder filter (IP-0060/H1) ─────────────────────────────────────────────

  /// Pass null to clear the filter; non-null Set restricts visible items.
  void setFolderFilter(Set<int>? ids) =>
      state = state.copyWith(selectedFolderIds: ids);

  /// Convenience used by chip taps: toggle a folder id in/out of the filter.
  /// Clearing the last filtered folder switches back to "show all" (null).
  void toggleFolder(int folderId) {
    final current = state.selectedFolderIds;
    if (current == null) {
      state = state.copyWith(selectedFolderIds: {folderId});
      return;
    }
    final next = Set<int>.from(current);
    if (!next.add(folderId)) next.remove(folderId);
    state = state.copyWith(selectedFolderIds: next.isEmpty ? null : next);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<CalendarEvent> eventsForDay(DateTime day) {
    final all = state.events[_dayKey(day)] ?? [];
    final filter = state.selectedFolderIds;
    if (filter == null) return all;
    return all.where((e) => filter.contains(e.folderId)).toList();
  }

  List<Meeting> meetingsForDay(DateTime day) {
    final all = state.meetings[_dayKey(day)] ?? [];
    final filter = state.selectedFolderIds;
    if (filter == null) return all;
    return all.where((m) => filter.contains(m.folderId)).toList();
  }

  static DateTime _dayKey(DateTime dt) =>
      DateTime.utc(dt.year, dt.month, dt.day);
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);
