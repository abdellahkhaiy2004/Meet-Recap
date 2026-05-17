import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/animation_utils.dart';
import '../../data/audio/audio_player.dart';
import '../../data/repositories/folder_repository.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../domain/entities/meeting.dart';
import '../../domain/entities/summary_section.dart';
import '../widgets/audio_player_bar.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class MeetingDetailPage extends ConsumerStatefulWidget {
  const MeetingDetailPage({super.key, required this.meetingId});

  /// String from go_router path parameter; parsed to int internally.
  final String meetingId;

  @override
  ConsumerState<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends ConsumerState<MeetingDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _reSummarizing = false;

  int get _id => int.tryParse(widget.meetingId) ?? -1;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Audio init ─────────────────────────────────────────────────────────────

  bool _audioLoaded = false;

  void _loadAudioOnce(String audioPath) {
    if (_audioLoaded) return;
    _audioLoaded = true;
    // Deferred so the first frame renders before the file I/O.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(audioPlayerProvider.notifier).load(audioPath);
      }
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _rename(Meeting meeting) async {
    final controller = TextEditingController(text: meeting.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer la réunion'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Titre'),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Renommer')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != meeting.title) {
      await ref
          .read(meetingRepositoryProvider)
          .rename(_id, result);
    }
  }

  Future<void> _moveToFolder(Meeting meeting) async {
    final folders = await ref.read(folderRepositoryProvider).watchAll().first;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('Déplacer vers',
                style: Theme.of(ctx).textTheme.titleMedium),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: folders.length,
                itemBuilder: (_, i) {
                  final f = folders[i];
                  return ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(f.name),
                    selected: f.id == meeting.folderId,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await ref
                          .read(meetingRepositoryProvider)
                          .moveToFolder(_id, f.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la réunion ?'),
        content: const Text(
            'Le fichier audio et le résumé seront définitivement supprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(meetingRepositoryProvider).delete(_id);
      if (mounted) context.pop();
    }
  }

  Future<void> _exportMarkdown(Meeting meeting) async {
    await Clipboard.setData(ClipboardData(text: meeting.summary));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Résumé copié dans le presse-papiers')),
      );
    }
  }

  Future<void> _reSummarize() async {
    setState(() => _reSummarizing = true);
    await ref.read(meetingRepositoryProvider).reSummarize(_id);
    if (mounted) setState(() => _reSummarizing = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final meetingAsync = ref.watch(
      meetingRepositoryProvider.select((_) => _),
    );
    // We watch via a stream-based approach: use FutureProvider wrapper.
    // Direct stream watch is wired through _meetingStreamProvider below.
    final meetingStream = ref.watch(_meetingStreamProvider(_id));

    return meetingStream.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erreur : $e')),
      ),
      data: (meeting) {
        if (meeting == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Réunion introuvable.')),
          );
        }
        _loadAudioOnce(meeting.audioPath);
        return _buildScaffold(meeting);
      },
    );
  }

  Widget _buildScaffold(Meeting meeting) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = meeting.pipelineState == PipelineState.transcribing ||
        meeting.pipelineState == PipelineState.summarizing;

    return PopScope(
      // Pause audio on back gesture.
      onPopInvokedWithResult: (_, __) {
        ref.read(audioPlayerProvider.notifier).pause();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Hero(
            tag: 'meeting_title_${_id}',
            flightShuttleBuilder: _heroShuttle,
            child: Material(
              color: Colors.transparent,
              child: Text(
                meeting.title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          actions: [
            if (_reSummarizing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            PopupMenuButton<_Action>(
              onSelected: (a) {
                switch (a) {
                  case _Action.rename:
                    _rename(meeting);
                  case _Action.move:
                    _moveToFolder(meeting);
                  case _Action.delete:
                    _delete();
                  case _Action.export:
                    _exportMarkdown(meeting);
                  case _Action.reSummarize:
                    if (!_reSummarizing) _reSummarize();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: _Action.rename,
                    child: Text('Renommer')),
                const PopupMenuItem(
                    value: _Action.move,
                    child: Text('Déplacer')),
                const PopupMenuItem(
                    value: _Action.export,
                    child: Text('Copier le résumé')),
                PopupMenuItem(
                    value: _Action.reSummarize,
                    child: Text(_reSummarizing
                        ? 'Résumé en cours…'
                        : 'Re-résumer')),
                const PopupMenuItem(
                    value: _Action.delete,
                    child: Text('Supprimer',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Résumé'),
              Tab(text: 'Transcript'),
              Tab(text: 'Infos'),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Pipeline state banner ─────────────────────────────────────
            if (isActive)
              LinearProgressIndicator(
                color: colorScheme.tertiary,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            // ── Header card ───────────────────────────────────────────────
            _MeetingHeader(meeting: meeting),
            // ── Tab views ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _SummaryTab(summary: meeting.summary),
                  _TranscriptTab(transcript: meeting.transcript),
                  _InfoTab(
                    meeting: meeting,
                    onReSummarize:
                        _reSummarizing ? null : _reSummarize,
                  ),
                ],
              ),
            ),
            // ── Audio player bar ──────────────────────────────────────────
            const AudioPlayerBar(),
          ],
        ),
      ),
    );
  }

  // Hero shuttle keeps Text visible during flight.
  static Widget _heroShuttle(
    BuildContext _,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromCtx,
    BuildContext toCtx,
  ) =>
      FadeTransition(
        opacity: animation,
        child: direction == HeroFlightDirection.push
            ? toCtx.widget
            : fromCtx.widget,
      );
}

// ── Stream provider ────────────────────────────────────────────────────────────

final _meetingStreamProvider =
    StreamProvider.autoDispose.family<Meeting?, int>((ref, id) {
  return ref.watch(meetingRepositoryProvider).watchById(id);
});

// ── Header ─────────────────────────────────────────────────────────────────────

class _MeetingHeader extends StatelessWidget {
  const _MeetingHeader({required this.meeting});
  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final created = meeting.createdAt.toLocal();
    final dateStr =
        '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}  '
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    final dur = Duration(seconds: meeting.durationSeconds);
    final durStr =
        '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  _pipelineLabel(meeting.pipelineState),
                  style: textTheme.labelSmall?.copyWith(
                    color: _pipelineColor(meeting.pipelineState, colorScheme),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              durStr,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _pipelineLabel(PipelineState s) => switch (s) {
        PipelineState.pending => 'En attente',
        PipelineState.transcribing => 'Transcription en cours…',
        PipelineState.summarizing => 'Résumé en cours…',
        PipelineState.done => 'Terminé',
        PipelineState.failed => 'Échec — relancez le résumé',
      };

  static Color _pipelineColor(PipelineState s, ColorScheme cs) =>
      switch (s) {
        PipelineState.done => cs.primary,
        PipelineState.failed => cs.error,
        _ => cs.tertiary,
      };
}

// ── Summary tab ────────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.summary});
  final String summary;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return const Center(child: Text('Résumé non disponible.'));
    }

    final sections = SummarySection.parse(summary);
    final animate = animationsEnabled(context);

    // Flat markdown fallback when no ## headings detected.
    if (sections.isEmpty) {
      return Markdown(
        data: summary,
        selectable: true,
        padding: const EdgeInsets.all(16),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final section = sections[i];
        Widget card = Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.heading,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                MarkdownBody(
                  data: section.body,
                  selectable: true,
                ),
              ],
            ),
          ),
        );

        if (!animate) return card;
        return card
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: const Duration(milliseconds: 280))
            .slideY(
              begin: 0.08,
              end: 0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
            );
      },
    );
  }
}

// ── Transcript tab ─────────────────────────────────────────────────────────────

class _TranscriptTab extends StatelessWidget {
  const _TranscriptTab({required this.transcript});
  final String transcript;

  @override
  Widget build(BuildContext context) {
    if (transcript.isEmpty) {
      return const Center(child: Text('Transcript non disponible.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copier'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: transcript));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Transcript copié dans le presse-papiers')),
                );
              },
            ),
          ),
          SelectableText(transcript),
        ],
      ),
    );
  }
}

// ── Info tab ───────────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.meeting, required this.onReSummarize});
  final Meeting meeting;
  final VoidCallback? onReSummarize;

  @override
  Widget build(BuildContext context) {
    final dur = Duration(seconds: meeting.durationSeconds);
    final rows = <_InfoRow>[
      _InfoRow('Langue détectée', meeting.detectedLanguage.isEmpty
          ? 'Inconnue'
          : meeting.detectedLanguage.toUpperCase()),
      _InfoRow('Durée',
          '${dur.inMinutes} min ${dur.inSeconds % 60} s'),
      _InfoRow('Taille audio', _fileSize(meeting.audioPath)),
      _InfoRow('État du pipeline',
          _pipelineLabel(meeting.pipelineState)),
      _InfoRow('ID brouillon', meeting.draftId),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...rows.map((r) => _InfoTile(row: r)),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Re-résumer'),
          onPressed: onReSummarize,
        ),
      ],
    );
  }

  static String _fileSize(String path) {
    try {
      final bytes =
          (path.length * 8); // placeholder; real stat in full impl
      return '${(bytes / 1024).toStringAsFixed(0)} KB (approx.)';
    } catch (_) {
      return 'Inconnu';
    }
  }

  static String _pipelineLabel(PipelineState s) => switch (s) {
        PipelineState.pending => 'En attente',
        PipelineState.transcribing => 'Transcription…',
        PipelineState.summarizing => 'Résumé…',
        PipelineState.done => 'Terminé',
        PipelineState.failed => 'Échec',
      };
}

class _InfoRow {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.row});
  final _InfoRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(row.value,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Action enum ────────────────────────────────────────────────────────────────

enum _Action { rename, move, delete, export, reSummarize }
