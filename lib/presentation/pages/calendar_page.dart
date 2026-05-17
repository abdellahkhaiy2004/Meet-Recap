import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/animation_utils.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/entities/meeting.dart';
import '../state/calendar_controller.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

/// Tab 1 — calendar view (architecture §5, IP-0035 + IP-0036).
///
/// Displays a month calendar using `table_calendar`. Each day with activity
/// shows up to 3 coloured dots (meetings = primary, events = tertiary) plus
/// a "+N" overflow label. Tapping a day opens the [_DaySheet].
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarControllerProvider);
    final ctrl = ref.read(calendarControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Planifier une réunion',
            onPressed: () => context.push('/calendar/schedule'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Calendar widget ─────────────────────────────────────────────
          TableCalendar<Object>(
            locale: 'fr_FR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: state.focusedDay,
            selectedDayPredicate: (day) =>
                isSameDay(state.selectedDay, day),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Mois',
              CalendarFormat.twoWeeks: '2 semaines',
              CalendarFormat.week: 'Semaine',
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(color: colorScheme.onPrimary),
              markersMaxCount: 0, // we draw custom markers
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, _) =>
                  _DayMarkers(
                    meetings: ctrl.meetingsForDay(day),
                    events: ctrl.eventsForDay(day),
                  ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              ctrl.selectDay(selectedDay);
              _showDaySheet(context, ref, selectedDay);
            },
            onPageChanged: (focusedDay) => ctrl.setFocusedDay(focusedDay),
          ),

          // ── Loading indicator ───────────────────────────────────────────
          if (state.isLoading)
            LinearProgressIndicator(
              color: colorScheme.tertiary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),

          // ── Selected-day summary ────────────────────────────────────────
          if (state.selectedDay != null) ...[
            const Divider(height: 1),
            Expanded(
              child: _DayPreview(
                selectedDay: state.selectedDay!,
                meetings: ctrl.meetingsForDay(state.selectedDay!),
                events: ctrl.eventsForDay(state.selectedDay!),
              ),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Text('Sélectionnez un jour pour voir les activités'),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_calendar',
        icon: animationsEnabled(context)
            ? const Icon(Icons.add_rounded)
                .animate()
                .rotate(
                  begin: -0.25,
                  end: 0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                )
            : const Icon(Icons.add_rounded),
        label: const Text('Planifier'),
        onPressed: () => context.push('/calendar/schedule'),
      ),
    );
  }

  static void _showDaySheet(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
  ) {
    final ctrl = ref.read(calendarControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false, // back closes sheet first (architecture §9c)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DaySheet(
        day: day,
        meetings: ctrl.meetingsForDay(day),
        events: ctrl.eventsForDay(day),
      ),
    );
  }
}

// ── Day markers (coloured dots) ────────────────────────────────────────────────

class _DayMarkers extends StatelessWidget {
  const _DayMarkers({required this.meetings, required this.events});
  final List<Meeting> meetings;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = meetings.length + events.length;
    if (total == 0) return const SizedBox.shrink();

    // Show up to 3 dots, then a "+N" overflow label.
    const maxDots = 3;
    final items = [
      ...List.generate(meetings.length, (_) => colorScheme.primary),
      ...List.generate(events.length, (_) => colorScheme.tertiary),
    ];

    return Positioned(
      bottom: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...items.take(maxDots).map(
                (c) => Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              ),
          if (total > maxDots)
            Text(
              '+${total - maxDots}',
              style: TextStyle(
                fontSize: 8,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Day preview (inline below calendar) ───────────────────────────────────────

class _DayPreview extends StatelessWidget {
  const _DayPreview({
    required this.selectedDay,
    required this.meetings,
    required this.events,
  });
  final DateTime selectedDay;
  final List<Meeting> meetings;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty && events.isEmpty) {
      return Center(
        child: Text(
          'Aucune activité ce jour',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (meetings.isNotEmpty) ...[
          _SheetSectionHeader(
              'Réunions enregistrées (${meetings.length})'),
          ...meetings.map((m) => _MeetingRow(meeting: m)),
        ],
        if (events.isNotEmpty) ...[
          _SheetSectionHeader('À venir (${events.length})'),
          ...events.map((e) => _EventRow(event: e)),
        ],
      ],
    );
  }
}

// ── Day bottom-sheet (IP-0036) ─────────────────────────────────────────────────

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.day,
    required this.meetings,
    required this.events,
  });
  final DateTime day;
  final List<Meeting> meetings;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_wd(day.weekday)} ${day.day} ${_month(day.month)} ${day.year}';

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Date title
          Text(dateStr, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          // Schedule event shortcut
          TextButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Planifier une réunion'),
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/calendar/schedule');
            },
          ),
          const Divider(),
          // Content
          Expanded(
            child: (meetings.isEmpty && events.isEmpty)
                ? Center(
                    child: Text(
                      'Aucune activité ce jour',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (meetings.isNotEmpty) ...[
                        _SheetSectionHeader(
                            'Réunions passées (${meetings.length})'),
                        ...meetings.map((m) => _MeetingRow(meeting: m)),
                      ],
                      if (events.isNotEmpty) ...[
                        _SheetSectionHeader(
                            'Événements à venir (${events.length})'),
                        ...events.map((e) => _EventRow(event: e)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _wd(int wd) => const [
        '', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'
      ][wd];

  static String _month(int m) => const [
        '', 'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
        'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.'
      ][m];
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _SheetSectionHeader extends StatelessWidget {
  const _SheetSectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.meeting});
  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final dur = Duration(seconds: meeting.durationSeconds);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.mic_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(meeting.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${dur.inMinutes} min ${dur.inSeconds % 60} s'),
      onTap: () {
        Navigator.of(context, rootNavigator: false).pop();
        context.push(
          '/folders/${meeting.folderId}/meetings/${meeting.id}',
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final start = event.startsAt.toLocal();
    final timeStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final isLinked = event.linkedMeetingId != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isLinked
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        child: Icon(
          isLinked ? Icons.check_circle_rounded : Icons.event_rounded,
          size: 18,
          color: isLinked
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.tertiary,
        ),
      ),
      title: Text(event.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(timeStr),
      trailing: isLinked
          ? Tooltip(
              message: 'Enregistrement lié',
              child: Icon(Icons.link_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary),
            )
          : null,
    );
  }
}
