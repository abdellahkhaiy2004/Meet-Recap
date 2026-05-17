import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/animation_utils.dart';
import '../../data/repositories/folder_repository.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../domain/entities/meeting.dart';
import '../state/folder_controller.dart';

// ── Sort mode ──────────────────────────────────────────────────────────────────

enum _SortMode { date, duration }

// ── Page ──────────────────────────────────────────────────────────────────────

/// Lists all meetings inside a folder, with sort toggle and FAB to record.
///
/// Hero counterpart tags for MeetingDetailPage ([IP-0029]) are applied to each
/// list-row title here.
class FolderDetailPage extends ConsumerStatefulWidget {
  const FolderDetailPage({super.key, required this.folderId});
  final String folderId;

  @override
  ConsumerState<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends ConsumerState<FolderDetailPage> {
  _SortMode _sortMode = _SortMode.date;

  int get _folderId => int.tryParse(widget.folderId) ?? -1;

  @override
  Widget build(BuildContext context) {
    final folderAsync = ref.watch(folderStreamProvider(_folderId));
    final meetingsAsync = ref.watch(_meetingsProvider(_folderId));

    return folderAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Erreur : $e'))),
      data: (folder) {
        final categoryColor = folder != null
            ? AppColors.forCategory(folder.category)
            : AppColors.primarySeed;

        return Scaffold(
          // ── AppBar with category colour band ──────────────────────────────
          appBar: AppBar(
            title: Text(folder?.name ?? 'Dossier'),
            backgroundColor: categoryColor,
            foregroundColor: AppColors.contrastOn(categoryColor),
            actions: [
              // Sort toggle
              IconButton(
                icon: Icon(_sortMode == _SortMode.date
                    ? Icons.schedule_rounded
                    : Icons.timer_rounded),
                tooltip: _sortMode == _SortMode.date
                    ? 'Trier par durée'
                    : 'Trier par date',
                onPressed: () => setState(() {
                  _sortMode = _sortMode == _SortMode.date
                      ? _SortMode.duration
                      : _SortMode.date;
                }),
              ),
              // Delete folder (non-Inbox)
              if (folder != null && !folder.isInbox)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') await _deleteFolder(folder.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer le dossier',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
            ],
          ),
          body: meetingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (meetings) {
              final sorted = _sort(meetings);
              if (sorted.isEmpty) return _EmptyMeetings(folderId: widget.folderId);
              final animate = animationsEnabled(context);
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sorted.length,
                itemBuilder: (ctx, i) {
                  final tile = _MeetingTile(
                    meeting: sorted[i],
                    folderId: widget.folderId,
                    onMove: () => _moveMeeting(sorted[i]),
                  );
                  if (!animate) return tile;
                  return tile
                      .animate(delay: Duration(milliseconds: i * 50))
                      .fadeIn(duration: const Duration(milliseconds: 250))
                      .slideX(
                        begin: -0.05,
                        end: 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                },
              );
            },
          ),
          // ── FAB → quick record into this folder ───────────────────────────
          floatingActionButton: FloatingActionButton(
            heroTag: 'fab_record_folder_${widget.folderId}',
            tooltip: 'Enregistrer dans ce dossier',
            onPressed: () => context.go(
              '/record?folderId=${widget.folderId}',
            ),
            child: const Icon(Icons.mic_rounded),
          ),
        );
      },
    );
  }

  // ── Sort ───────────────────────────────────────────────────────────────────

  List<Meeting> _sort(List<Meeting> meetings) {
    final list = [...meetings];
    if (_sortMode == _SortMode.date) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      list.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    }
    return list;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _moveMeeting(Meeting meeting) async {
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
                  final isCurrent = f.id == meeting.folderId;
                  return ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(f.name),
                    selected: isCurrent,
                    enabled: !isCurrent,
                    onTap: isCurrent
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            await ref
                                .read(meetingRepositoryProvider)
                                .moveToFolder(meeting.id, f.id);
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

  Future<void> _deleteFolder(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce dossier ?'),
        content: const Text(
          'Les réunions seront déplacées vers la Boîte de réception.',
        ),
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
      await ref.read(folderControllerProvider.notifier).deleteFolder(id);
      if (mounted) context.pop();
    }
  }
}

// ── Stream providers ──────────────────────────────────────────────────────────

final _meetingsProvider =
    StreamProvider.autoDispose.family<List<Meeting>, int>((ref, folderId) {
  return ref.watch(meetingRepositoryProvider).watchByFolder(folderId);
});

// ── Meeting tile ───────────────────────────────────────────────────────────────

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({
    required this.meeting,
    required this.folderId,
    required this.onMove,
  });

  final Meeting meeting;
  final String folderId;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final dur = Duration(seconds: meeting.durationSeconds);
    final durStr =
        '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';
    final date = meeting.createdAt.toLocal();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return ListTile(
      // Hero counterpart for MeetingDetailPage title ([IP-0029]).
      title: Hero(
        tag: 'meeting_title_${meeting.id}',
        flightShuttleBuilder: _shuttle,
        child: Material(
          color: Colors.transparent,
          child: Text(
            meeting.title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
      subtitle: Text(dateStr,
          style: Theme.of(context).textTheme.bodySmall),
      trailing: _DurationChip(label: durStr, state: meeting.pipelineState),
      onTap: () => context.push(
        '/folders/$folderId/meetings/${meeting.id}',
      ),
      onLongPress: onMove,
    );
  }

  static Widget _shuttle(
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

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.label, required this.state});
  final String label;
  final PipelineState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isError = state == PipelineState.failed;
    final isPending = state == PipelineState.pending ||
        state == PipelineState.transcribing ||
        state == PipelineState.summarizing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : isPending
                ? colorScheme.tertiaryContainer
                : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPending ? '…' : isError ? '!' : label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isError
                  ? colorScheme.onErrorContainer
                  : isPending
                      ? colorScheme.onTertiaryContainer
                      : colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyMeetings extends StatelessWidget {
  const _EmptyMeetings({required this.folderId});
  final String folderId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none_rounded,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withAlpha(153)),
            const SizedBox(height: 16),
            Text('Aucune réunion dans ce dossier',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur le bouton micro pour\nenregistrer votre première réunion.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
