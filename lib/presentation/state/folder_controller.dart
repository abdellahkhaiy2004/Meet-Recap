import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/folder_repository.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/folder.dart';

// ── Stream provider ────────────────────────────────────────────────────────────

/// Live list of all folders — consumed by FoldersPage and move-to sheets.
final foldersStreamProvider = StreamProvider<List<Folder>>((ref) {
  return ref.watch(folderRepositoryProvider).watchAll();
});

/// Live single folder — consumed by FolderDetailPage AppBar + header.
final folderStreamProvider =
    StreamProvider.autoDispose.family<Folder?, int>((ref, id) {
  return ref.watch(folderRepositoryProvider).watchById(id);
});

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Handles folder CRUD mutations triggered by the UI.
///
/// The UI watches [foldersStreamProvider] for the live list and calls methods
/// here to mutate. This keeps mutating logic and reactive state separate.
class FolderController extends Notifier<void> {
  @override
  void build() {}

  FolderRepository get _repo => ref.read(folderRepositoryProvider);

  Future<int> createFolder({
    required String name,
    required Category category,
    required String colorHex,
    required String iconName,
  }) =>
      _repo.create(
        name: name,
        category: category,
        colorHex: colorHex,
        iconName: iconName,
      );

  Future<void> renameFolder(int id, String newName) =>
      _repo.rename(id, newName);

  Future<void> updateFolder({
    required int id,
    String? name,
    Category? category,
    String? colorHex,
    String? iconName,
  }) =>
      _repo.updateFolder(
        id: id,
        name: name,
        category: category,
        colorHex: colorHex,
        iconName: iconName,
      );

  /// Deletes a folder. The repository protects the Inbox from deletion.
  /// Drift's FK onDelete:setDefault moves orphaned meetings to Inbox.
  Future<void> deleteFolder(int id) => _repo.deleteById(id);
}

final folderControllerProvider =
    NotifierProvider<FolderController, void>(FolderController.new);
