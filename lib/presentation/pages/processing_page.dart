import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/animation_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../domain/entities/meeting.dart';
import '../state/meeting_controller.dart';
import 'settings_page.dart'
    show
        forcedLanguageProvider,
        translateTranscriptToProvider,
        darijaLatinizeProvider;

// ── Provider ──────────────────────────────────────────────────────────────────

final _meetingByDraftProvider =
    StreamProvider.autoDispose.family<Meeting?, String>((ref, draftId) {
  return ref.watch(meetingRepositoryProvider).watchByDraftId(draftId);
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// Full-screen pipeline-progress page shown while audio is transcribed and
/// summarized.  PopScope blocks back during the pipeline per [IP-0045]; the
/// page is the implementation vehicle for [IP-0058].
class ProcessingPage extends ConsumerStatefulWidget {
  const ProcessingPage({super.key, required this.draftId});
  final String draftId;

  @override
  ConsumerState<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends ConsumerState<ProcessingPage> {
  final CancelToken _cancelToken = CancelToken();
  bool _started = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPipeline());
  }

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel('Page disposed.');
    super.dispose();
  }

  // ── Pipeline trigger ───────────────────────────────────────────────────────

  Future<void> _startPipeline() async {
    if (_started || !mounted) return;
    _started = true;

    final meetingState = ref.read(meetingControllerProvider);
    final result = meetingState.result;
    if (result == null) {
      if (mounted) context.go('/record');
      return;
    }

    final folderId = await _resolveFolder(result.folderId);
    if (!mounted) return;

    final forcedLanguage = ref.read(forcedLanguageProvider);
    final translateTo    = ref.read(translateTranscriptToProvider);
    final latinizeDarija = ref.read(darijaLatinizeProvider);
    final repo = ref.read(meetingRepositoryProvider);
    unawaited(
      repo
          .processRecording(
            draftId: widget.draftId,
            audioFile: result.audioFile,
            durationSeconds: result.duration.inSeconds,
            folderId: folderId,
            cancelToken: _cancelToken,
            forcedLanguage: forcedLanguage,
            translateTo: translateTo,
            latinizeDarija: latinizeDarija,
          )
          .then((r) {
        if (!mounted) return;
        if (r.isErr) {
          final f = (r as Err).failure;
          if (f is! CancelledFailure) setState(() => _errorMessage = f.message);
        }
      }),
    );
  }

  Future<int> _resolveFolder(String? folderIdStr) async {
    if (folderIdStr != null) {
      final n = int.tryParse(folderIdStr);
      if (n != null) return n;
    }
    final inbox = await ref.read(appDatabaseProvider).folderDao.getInbox();
    return inbox?.id ?? 1;
  }

  Future<void> _retry(int meetingId) async {
    setState(() => _errorMessage = null);
    final forcedLanguage = ref.read(forcedLanguageProvider);
    final translateTo    = ref.read(translateTranscriptToProvider);
    final latinizeDarija = ref.read(darijaLatinizeProvider);
    final r = await ref
        .read(meetingRepositoryProvider)
        .retryPipeline(
          meetingId,
          cancelToken: _cancelToken,
          forcedLanguage: forcedLanguage,
          translateTo: translateTo,
          latinizeDarija: latinizeDarija,
        );
    if (!mounted) return;
    if (r.isErr) {
      final f = (r as Err).failure;
      if (f is! CancelledFailure) setState(() => _errorMessage = f.message);
    }
  }

  Future<void> _onPopRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le traitement ?'),
        content: const Text(
          'Le fichier audio est conservé. Vous pourrez réessayer depuis '
          'la liste des réunions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    if ((confirm ?? false) && mounted) {
      _cancelToken.cancel('User cancelled.');
      context.go('/record');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_meetingByDraftProvider(widget.draftId));
    final meeting = async.valueOrNull;
    final phase = meeting?.pipelineState ?? PipelineState.pending;
    final isFailed = phase == PipelineState.failed || _errorMessage != null;

    // Navigate (replacing route) the moment the pipeline reports done.
    ref.listen<AsyncValue<Meeting?>>(_meetingByDraftProvider(widget.draftId),
        (_, next) {
      final m = next.valueOrNull;
      if (m != null && m.pipelineState == PipelineState.done && mounted) {
        context.go('/folders/${m.folderId}/meetings/${m.id}');
      }
    });

    return PopScope(
      canPop: isFailed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopRequest();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isFailed ? 'Traitement échoué' : 'Traitement en cours…'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhaseRow(
                  label: 'Transcription',
                  description: 'Conversion de l\'audio en texte',
                  state: _phaseState(phase, 0, meeting),
                  animate: animationsEnabled(context),
                ),
                const SizedBox(height: 24),
                _PhaseRow(
                  label: 'Résumé',
                  description: 'Analyse et structuration du contenu',
                  state: _phaseState(phase, 1, meeting),
                  animate: animationsEnabled(context),
                ),
                const SizedBox(height: 24),
                _PhaseRow(
                  label: 'Sauvegarde',
                  description: 'Enregistrement local de la réunion',
                  state: phase == PipelineState.done
                      ? _PhaseState.done
                      : _PhaseState.idle,
                  animate: animationsEnabled(context),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 32),
                  _ErrorCard(
                    message: _errorMessage!,
                    onRetry: meeting != null ? () => _retry(meeting.id) : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static _PhaseState _phaseState(PipelineState p, int idx, Meeting? m) {
    final transcriptDone = m?.transcript.isNotEmpty ?? false;
    return switch (idx) {
      0 => switch (p) {
          PipelineState.summarizing || PipelineState.done => _PhaseState.done,
          PipelineState.failed when transcriptDone => _PhaseState.done,
          PipelineState.failed => _PhaseState.failed,
          _ => _PhaseState.active,
        },
      1 => switch (p) {
          PipelineState.done => _PhaseState.done,
          PipelineState.summarizing => _PhaseState.active,
          PipelineState.failed when transcriptDone => _PhaseState.failed,
          _ => _PhaseState.idle,
        },
      _ => _PhaseState.idle,
    };
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

enum _PhaseState { idle, active, done, failed }

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.label,
    required this.description,
    required this.state,
    required this.animate,
  });

  final String label;
  final String description;
  final _PhaseState state;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (iconData, color) = switch (state) {
      _PhaseState.idle   => (Icons.radio_button_unchecked, cs.outline),
      _PhaseState.active => (Icons.radio_button_checked, cs.primary),
      _PhaseState.done   => (Icons.check_circle, cs.primary),
      _PhaseState.failed => (Icons.error_outline, cs.error),
    };

    Widget icon = Icon(iconData, color: color, size: 28);
    if (state == _PhaseState.active && animate) {
      icon = icon
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: color.withValues(alpha: 0.3));
    }

    return Row(
      children: [
        SizedBox(width: 28, height: 28, child: icon),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: state == _PhaseState.idle
                          ? cs.onSurface.withValues(alpha: 0.4)
                          : cs.onSurface,
                      fontWeight: state == _PhaseState.active
                          ? FontWeight.bold
                          : null,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message,
                style: TextStyle(color: cs.onErrorContainer)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
