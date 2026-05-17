import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/calendar_repository.dart';
import '../../services/notification_service.dart';
import '../state/calendar_controller.dart';
import '../state/folder_controller.dart';

/// Form page for scheduling a calendar event (architecture §5, IP-0037).
///
/// Fields: title, folder picker, start date+time, end date+time, reminder.
/// [PopScope] blocks back if form is dirty → discard confirmation sheet.
/// On save: persists via [CalendarRepository] + schedules via [NotificationService].
class ScheduleEventPage extends ConsumerStatefulWidget {
  const ScheduleEventPage({super.key});

  @override
  ConsumerState<ScheduleEventPage> createState() => _ScheduleEventPageState();
}

class _ScheduleEventPageState extends ConsumerState<ScheduleEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();

  int? _selectedFolderId;
  DateTime _startsAt = _roundUp(DateTime.now(), 30);
  DateTime _endsAt = _roundUp(DateTime.now(), 30).add(const Duration(hours: 1));
  int _reminderMinutes = 15;
  bool _saving = false;

  static const _reminderOptions = [0, 5, 10, 15, 30, 60];

  bool get _isDirty => _titleCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static DateTime _roundUp(DateTime dt, int minutes) {
    final rem = dt.minute % minutes;
    final add = rem == 0 ? 0 : minutes - rem;
    return dt.copyWith(minute: dt.minute + add, second: 0, millisecond: 0);
  }

  // ── Date/time pickers ──────────────────────────────────────────────────────

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;
    final newStart = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _startsAt = newStart;
      if (_endsAt.isBefore(newStart.add(const Duration(minutes: 15)))) {
        _endsAt = newStart.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: _startsAt,
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endsAt),
    );
    if (time == null || !mounted) return;
    final newEnd = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    if (newEnd.isBefore(_startsAt)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La fin doit être après le début.')),
      );
      return;
    }
    setState(() => _endsAt = newEnd);
  }

  // ── Back guard ─────────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Abandonner ?',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                  'Les modifications non enregistrées seront perdues.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Continuer'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Abandonner'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La réunion est planifiée dans le passé.')),
      );
    }

    setState(() => _saving = true);

    // Use a unique notification ID derived from microseconds.
    final notificationId =
        DateTime.now().microsecondsSinceEpoch % 0x7FFFFFFF;

    // Resolve the folder ID — fall back to Inbox (first folder, id=1).
    final folderId = _selectedFolderId ?? 1;

    final fireAt = _startsAt
        .subtract(Duration(minutes: _reminderMinutes));

    final calRepo = ref.read(calendarRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);

    try {
      final eventId = await calRepo.scheduleEvent(
        title: _titleCtrl.text.trim(),
        folderId: folderId,
        startsAt: _startsAt,
        endsAt: _endsAt,
        reminderMinutes: _reminderMinutes,
        notificationId: notificationId,
      );

      // Schedule OS notification if reminder time is in the future.
      if (fireAt.isAfter(DateTime.now())) {
        final hasPermission =
            await notifService.requestExactAlarmPermission();
        if (hasPermission) {
          await notifService.schedule(
            notificationId: notificationId,
            title: 'Rappel : ${_titleCtrl.text.trim()}',
            body: _reminderMinutes == 0
                ? 'Votre réunion commence maintenant.'
                : 'Dans $_reminderMinutes min.',
            fireAt: fireAt,
            folderId: folderId,
            eventId: eventId,
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permission exacte refusée — le rappel ne sera pas déclenché.',
              ),
            ),
          );
        }
      }

      // Refresh the calendar state so the new event appears.
      ref
          .read(calendarControllerProvider.notifier)
          .fetchForMonth(DateTime(_startsAt.year, _startsAt.month));

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersStreamProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Planifier une réunion'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              TextButton(onPressed: _save, child: const Text('Enregistrer')),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Title ────────────────────────────────────────────────────
              _Label('Titre'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ex: Réunion d\'équipe',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 20),

              // ── Folder picker ────────────────────────────────────────────
              _Label('Dossier'),
              const SizedBox(height: 8),
              foldersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur : $e'),
                data: (folders) => DropdownButtonFormField<int>(
                  value: _selectedFolderId,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder()),
                  hint: const Text('Boîte de réception (défaut)'),
                  items: folders
                      .map(
                        (f) => DropdownMenuItem(
                          value: f.id,
                          child: Text(f.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedFolderId = v),
                ),
              ),
              const SizedBox(height: 20),

              // ── Start date/time ──────────────────────────────────────────
              _Label('Début'),
              const SizedBox(height: 8),
              _DateTimeButton(
                value: _startsAt,
                onTap: _pickStart,
              ),
              const SizedBox(height: 16),

              // ── End date/time ────────────────────────────────────────────
              _Label('Fin'),
              const SizedBox(height: 8),
              _DateTimeButton(
                value: _endsAt,
                onTap: _pickEnd,
              ),
              const SizedBox(height: 20),

              // ── Reminder ─────────────────────────────────────────────────
              _Label('Rappel'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _reminderMinutes,
                decoration:
                    const InputDecoration(border: OutlineInputBorder()),
                items: _reminderOptions
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m == 0
                            ? 'Au moment de la réunion'
                            : '$m min avant'),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _reminderMinutes = v ?? 15),
              ),
              const SizedBox(height: 32),

              // ── Save CTA ─────────────────────────────────────────────────
              FilledButton.icon(
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Enregistrer l\'événement'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({required this.value, required this.onTap});
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}  '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today_rounded, size: 18),
      label: Text(fmt),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
