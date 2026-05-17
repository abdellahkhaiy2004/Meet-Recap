import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/folder.dart';
import '../local/app_database.dart';
import '../local/folder_dao.dart';
import '../local/tables.dart';

/// CRUD + stream access for folders.
///
/// The Inbox folder (isInbox = true, id = 1 after seed) is never deleted;
/// [deleteById] is a no-op when called on the Inbox.
class FolderRepository {
  const FolderRepository(this._dao);

  final FolderDao _dao;

  // ── Reads ──────────────────────────────────────────────────────────────────

  Stream<List<Folder>> watchAll() =>
      _dao.watchAll().asyncMap(_enrichWithCounts);

  Stream<Folder?> watchById(int id) =>
      _dao.watchById(id).asyncMap((row) async {
        if (row == null) return null;
        final count = await _dao.countMeetings(row.id);
        return _rowToEntity(row, count);
      });

  Future<Folder?> getById(int id) async {
    final row = await _dao.getById(id);
    if (row == null) return null;
    final count = await _dao.countMeetings(row.id);
    return _rowToEntity(row, count);
  }

  Future<Folder?> getInbox() async {
    final row = await _dao.getInbox();
    if (row == null) return null;
    final count = await _dao.countMeetings(row.id);
    return _rowToEntity(row, count);
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<int> create({
    required String name,
    required Category category,
    required String colorHex,
    required String iconName,
  }) =>
      _dao.insert(
        FoldersCompanion.insert(
          name: name,
          category: Value(category.name),
          colorHex: Value(colorHex),
          iconName: Value(iconName),
        ),
      );

  Future<void> rename(int id, String newName) async {
    final row = await _dao.getById(id);
    if (row == null) return;
    await _dao.updateFolder(row.copyWith(name: newName));
  }

  Future<void> updateFolder({
    required int id,
    String? name,
    Category? category,
    String? colorHex,
    String? iconName,
  }) async {
    final row = await _dao.getById(id);
    if (row == null) return;
    await _dao.updateFolder(
      row.copyWith(
        name: name ?? row.name,
        category: category?.name ?? row.category,
        colorHex: colorHex ?? row.colorHex,
        iconName: iconName ?? row.iconName,
      ),
    );
  }

  /// Deletes a folder. Meetings whose FK pointed here are moved to Inbox
  /// automatically by Drift's `onDelete: KeyAction.setDefault` constraint.
  /// The Inbox itself cannot be deleted.
  Future<void> deleteById(int id) async {
    final row = await _dao.getById(id);
    if (row == null || row.isInbox) return;
    await _dao.deleteById(id);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<List<Folder>> _enrichWithCounts(List<FolderData> rows) async {
    final result = <Folder>[];
    for (final row in rows) {
      final count = await _dao.countMeetings(row.id);
      result.add(_rowToEntity(row, count));
    }
    return result;
  }

  static Folder _rowToEntity(FolderData row, int meetingCount) => Folder(
        id: row.id,
        name: row.name,
        category: _parseCategory(row.category),
        colorHex: row.colorHex,
        iconName: row.iconName,
        meetingCount: meetingCount,
        createdAt: row.createdAt,
        isInbox: row.isInbox,
      );

  static Category _parseCategory(String s) {
    try {
      return Category.values.firstWhere((c) => c.name == s);
    } catch (_) {
      return Category.other;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(ref.watch(appDatabaseProvider).folderDao);
});
