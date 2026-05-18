import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'folder_dao.g.dart';

/// Pair of a folder row and its current meeting count.
/// Used by [FolderDao.watchAllWithCounts] so the UI gets count updates
/// the moment a meeting is added/moved/deleted (no tab-switch refresh).
typedef FolderWithCount = ({FolderData folder, int count});

@DriftAccessor(tables: [Folders, Meetings])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  // ── Queries ────────────────────────────────────────────────────────────────

  /// All folders ordered by creation date.
  Stream<List<FolderData>> watchAll() {
    return (select(folders)
          ..orderBy([(f) => OrderingTerm.asc(f.createdAt)]))
        .watch();
  }

  /// All folders + their current meeting count, joined and grouped.
  /// Drift auto-tracks both tables in the join so this stream re-emits
  /// whenever a folder OR a meeting changes — fixes the stale-count bug
  /// where the badge only refreshed after switching tabs.
  Stream<List<FolderWithCount>> watchAllWithCounts() {
    final countExp = meetings.id.count();
    final query = select(folders).join([
      leftOuterJoin(meetings, meetings.folderId.equalsExp(folders.id)),
    ])
      ..addColumns([countExp])
      ..groupBy([folders.id])
      ..orderBy([OrderingTerm(expression: folders.createdAt)]);

    return query.watch().map((rows) => rows
        .map((row) => (
              folder: row.readTable(folders),
              count: row.read(countExp) ?? 0,
            ))
        .toList());
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

  Future<bool> updateCompanion(FoldersCompanion companion) async {
    final affected = await (super.update(folders)
          ..where((f) => f.id.equals(companion.id.value)))
        .write(companion);
    return affected > 0;
  }

  Future<void> updateFolder(FolderData folder) =>
      (super.update(folders)..where((f) => f.id.equals(folder.id))).write(
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
