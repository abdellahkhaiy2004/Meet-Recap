import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'event_dao.dart';
import 'folder_dao.dart';
import 'meeting_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Folders, Meetings, CalendarEvents],
  daos: [FolderDao, MeetingDao, EventDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed the virtual "Inbox" folder so the user always has a default
          // destination for recordings made without an explicit folder choice.
          await into(folders).insert(
            FoldersCompanion.insert(
              name: 'Boîte de réception',
              category: const Value('other'),
              colorHex: const Value('7C3AED'),
              iconName: const Value('inbox'),
              isInbox: const Value(true),
            ),
          );
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'auto_derdacha.db'));
    return NativeDatabase.createInBackground(file);
  });
}

// ── Provider ──────────────────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) {
    final db = AppDatabase();
    ref.onDispose(db.close);
    return db;
  },
);
