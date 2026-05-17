import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'folder_dao.g.dart';

@DriftAccessor(tables: [Folders, Meetings])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  // ── Queries ────────────────────────────────────────────────────────────────

  /// All folders ordered by creation date, with live meeting count via subquery.
  Stream<List<FolderData>> watchAll() {
    return select(folders)
      ..orderBy([(f) => OrderingTerm.asc(f.createdAt)])
      ..watch() as Stream<List<FolderData>>;
  }

  /// Single folder by id — returns null if not found.
  Stream<FolderData?> watchById(int id) =>
      (select(folders)..where((f) => f.id.equals(id))).watchSingleOrNull();

  Future<FolderData?> getById(int id) =>
      (select(folders)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// The seeded Inbox folder (isInbox = true, always exists after migration v1).
  Future<FolderData?> getInbox() =>
      (select(folders)..where((f) => f.isInbox.equals(true))).getSingleOrNull();

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<int> insert(FoldersCompanion companion) =>
      into(folders).insert(companion);

  Future<bool> update(FoldersCompanion companion) =>
      (updateReturning(folders, companion)) != null
          ? Future.value(true)
          : Future.value(false);

  Future<void> updateFolder(FolderData folder) =>
      (update(folders)..where((f) => f.id.equals(folder.id))).write(
        FoldersCompanion(
          name: Value(folder.name),
          category: Value(folder.category),
          colorHex: Value(folder.colorHex),
          iconName: Value(folder.iconName),
        ),
      );

  /// Delete a folder. Drift's FK `onDelete: KeyAction.setDefault` on Meetings
  /// will move orphaned meetings to folderId = 1 (the Inbox).
  Future<int> deleteById(int id) =>
      (delete(folders)..where((f) => f.id.equals(id))).go();

  // ── Meeting count helper ───────────────────────────────────────────────────

  /// Counts meetings belonging to [folderId]. Used by FolderCard.
  Future<int> countMeetings(int folderId) async {
    final count = meetings.id.count();
    final query = selectOnly(meetings)
      ..addColumns([count])
      ..where(meetings.folderId.equals(folderId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
