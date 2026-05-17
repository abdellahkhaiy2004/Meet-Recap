import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../data/audio/recording_state.dart';
import '../state/meeting_controller.dart';
import '../widgets/record_button.dart';
import '../widgets/waveform_indicator.dart';

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key, this.folderId, this.eventId});

  /// When launched from a folder FAB or a notification deep-link.
  final String? folderId;
  final String? eventId;

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetingControllerProvider);
    final rs    = state.recordingState;
    final isRecording = rs is Recording;
    final isPaused    = rs is Paused;
    final isActive    = isRecording || isPaused;

    return PopScope(
      // Block hardware back while recording (architecture §9c).
      canPop: !isActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await _askStopFirst(context);
        if (confirm && context.mounted) {
          await ref.read(meetingControllerProvider.notifier).stopAndProcess();
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Enregistrer'),
          actions: [
            if (isPaused)
              TextButton.icon(
                onPressed: _resumeRecording,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Reprendre'),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Error banner
              if (rs is RecordingError) _ErrorBanner(
                message: rs.message,
                onDismiss: () =>
                    ref.read(meetingControllerProvider.notifier).clearError(),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Status label ────────────────────────────────────
                    _StatusLabel(rs: rs),

                    const SizedBox(height: 12),

                    // ── Elapsed timer ───────────────────────────────────
                    _ElapsedTimer(rs: rs),

                    const SizedBox(height: 40),

                    // ── Record button ────────────────────────────────────
                    RecordButton(
                      isRecording: isRecording,
                      onTap: isActive ? _stopRecording : _startRecording,
                    ),

                    const SizedBox(height: 40),

                    // ── Waveform (visible only while recording) ──────────
                    AnimatedOpacity(
                      opacity: isRecording ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: WaveformIndicator(
                          amplitude: isRecording ? (rs as Recording).amplitude : 0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Pause / hint text ────────────────────────────────
                    if (isRecording)
                      TextButton.icon(
                        onPressed: _pauseRecording,
                        icon: const Icon(Icons.pause_rounded),
                        label: const Text('Pause'),
                      )
                    else if (!isActive)
                      Text(
                        'Appuyez pour commencer',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final granted = await _ensureMicPermission();
    if (!granted || !mounted) return;

    await ref.read(meetingControllerProvider.notifier).startRecording(
          folderId: widget.folderId,
        );
  }

  Future<void> _pauseRecording() =>
      ref.read(meetingControllerProvider.notifier).pauseRecording();

  Future<void> _resumeRecording() =>
      ref.read(meetingControllerProvider.notifier).resumeRecording();

  Future<void> _stopRecording() async {
    final result =
        await ref.read(meetingControllerProvider.notifier).stopAndProcess();
    if (!mounted) return;

    if (result == null) {
      // Error state is already set on the controller.
      return;
    }
    // Navigate to ProcessingPage, replacing the current route so the user
    // cannot swipe back into an empty RecordPage mid-process.
    context.go('/processing/${result.draftId}');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (!mounted) return false;

    if (status.isPermanentlyDenied) {
      await _showPermissionDeniedDialog(permanent: true);
    } else {
      await _showPermissionDeniedDialog(permanent: false);
    }
    return false;
  }

  Future<void> _showPermissionDeniedDialog({required bool permanent}) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Microphone requis'),
        content: Text(
          permanent
              ? 'L\'accès au microphone a été refusé de façon permanente. '
                  'Activez-le dans les paramètres de l\'application.'
              : 'L\'accès au microphone est requis pour enregistrer une réunion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          if (permanent)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Paramètres'),
            ),
        ],
      ),
    );
  }

  static Future<bool> _askStopFirst(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Arrêter l\'enregistrement ?'),
        content: const Text(
          'L\'enregistrement en cours sera arrêté et envoyé pour traitement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Arrêter'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.rs});
  final RecordingState rs;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (rs) {
      Recording()      => ('Enregistrement en cours…', AppColors.recording),
      Paused()         => ('En pause', Colors.orange),
      RecordingError() => ('Erreur', Colors.red),
      Idle()           => ('Prêt', Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        label,
        key: ValueKey(label),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _ElapsedTimer extends StatelessWidget {
  const _ElapsedTimer({required this.rs});
  final RecordingState rs;

  @override
  Widget build(BuildContext context) {
    final elapsed = switch (rs) {
      Recording(elapsed: final e) => e,
      Paused(elapsed: final e)    => e,
      _                           => Duration.zero,
    };

    final h  = elapsed.inHours;
    final m  = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s  = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = h > 0 ? '$h:$m:$s' : '$m:$s';

    return Text(
      text,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: rs is Recording
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
          ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
