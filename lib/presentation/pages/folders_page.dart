import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/folder_controller.dart';
import '../widgets/folder_card.dart';

/// Tab 2 — grid of all folders (architecture §4).
///
/// Displays a 2-column lazy GridView fed by [foldersStreamProvider].
/// Empty state shows a centred CTA directing the user to create their first folder.
class FoldersPage extends ConsumerWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dossiers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            tooltip: 'Nouveau dossier',
            onPressed: () => context.push('/folders/new'),
          ),
        ],
      ),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (folders) {
          if (folders.isEmpty) return const _EmptyState();
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: folders.length,
            itemBuilder: (context, i) {
              final folder = folders[i];
              return FolderCard(
                folder: folder,
                gridIndex: i,
                onTap: () =>
                    context.push('/folders/${folder.id}'),
              );
            },
          );
        },
      ),
      floatingActionButton: foldersAsync.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton.extended(
              heroTag: 'fab_folders',
              icon: const Icon(Icons.create_new_folder_rounded),
              label: const Text('Nouveau'),
              onPressed: () => context.push('/folders/new'),
            )
          : null,
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 72,
              color: colorScheme.primary.withAlpha(153),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun dossier pour l\'instant',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Organisez vos réunions en créant\nvotre premier dossier.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.create_new_folder_rounded),
              label: const Text('Créer un dossier'),
              onPressed: () => context.push('/folders/new'),
            ),
          ],
        ),
      ),
    );
  }
}
