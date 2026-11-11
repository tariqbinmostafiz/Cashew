// native.dart
import 'package:budget/database/tables.dart';
import 'package:budget/farm/backupValidation.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import 'dart:io';

Future<FinanceDatabase> constructDb(String dbName,
    {Uint8List? initialDataWeb}) async {
  // the LazyDatabase util lets us find the right location for the file async.
  final db = LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, dbName + '.sqlite'));
    await makePreMigrationCopy(file, dbFolder.path);
    // return NativeDatabase(file);
    QueryExecutor foregroundExecutor = NativeDatabase(file);
    QueryExecutor backgroundExecutor = NativeDatabase.createInBackground(file);
    return MultiExecutor(read: foregroundExecutor, write: backgroundExecutor);
  });
  return FinanceDatabase(db);
}

Future<DBFileInfo> getCurrentDBFileInfo() async {
  Uint8List dbFileBytes;
  late Stream<List<int>> mediaStream;

  final dbFolder = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dbFolder.path, 'db.sqlite'));
  //print("FILE SIZE:" + (dbFile.lengthSync() / 1e+6).toString());
  dbFileBytes = await dbFile.readAsBytes();
  mediaStream = Stream.value(List<int>.from(dbFileBytes));

  return DBFileInfo(dbFileBytes, mediaStream);
}

/// Keeps a plain-file copy of the database whenever the app is started with a
/// different schema version than last time (i.e. just before a migration can
/// run). Keeps the 3 most recent copies. Never throws.
Future<void> makePreMigrationCopy(File dbFile, String folder) async {
  try {
    if (await dbFile.exists() && await dbFile.length() > 0) {
      final int? last = sharedPreferences.getInt('farmLastOpenedSchemaVersion');
      if (last != schemaVersionGlobal) {
        final String tag = last == null ? 'unknown' : 'v' + last.toString();
        await dbFile.copy(p.join(folder,
            'db.pre-migration-' + tag + '-to-v' + schemaVersionGlobal.toString() + '.bak'));
        await pruneDbBackups(folder, 'db.pre-migration-', 3);
      }
    }
    await sharedPreferences.setInt(
        'farmLastOpenedSchemaVersion', schemaVersionGlobal);
  } catch (e) {
    print('Pre-migration copy failed: ' + e.toString());
  }
}

Future<void> pruneDbBackups(String folder, String prefix, int keep) async {
  try {
    final List<File> files = Directory(folder)
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith(prefix))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (int i = keep; i < files.length; i++) {
      await files[i].delete();
    }
  } catch (e) {
    print('Prune backups failed: ' + e.toString());
  }
}

/// Replaces the live database with [dataStore].
/// Safe-restore: validates the bytes again, keeps a copy of the current
/// database (db.pre-restore-*.bak), writes to a temp file and renames it over
/// db.sqlite so a crash mid-write cannot leave a half-written database.
Future overwriteDefaultDB(Uint8List dataStore) async {
  final String? problem =
      validateSqliteBackupBytes(dataStore, schemaVersionGlobal);
  if (problem != null) {
    throw Exception('invalid-backup:' + problem);
  }
  final dbFolder = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dbFolder.path, 'db.sqlite'));
  if (await dbFile.exists()) {
    final String stamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    await dbFile.copy(p.join(dbFolder.path, 'db.pre-restore-' + stamp + '.bak'));
    await pruneDbBackups(dbFolder.path, 'db.pre-restore-', 3);
  }
  final tmpFile = File(p.join(dbFolder.path, 'db.sqlite.restore-tmp'));
  await tmpFile.writeAsBytes(dataStore, flush: true);
  // Stale journal files from the old database must not be applied to the new one
  for (final String suffix in ['-wal', '-shm', '-journal']) {
    final f = File(dbFile.path + suffix);
    if (await f.exists()) await f.delete();
  }
  await tmpFile.rename(dbFile.path);
  // The restored file may be older: take a pre-migration copy on next start
  await sharedPreferences.remove('farmLastOpenedSchemaVersion');
  // we need to be able to sync with others after the restore
  await sharedPreferences.setString("dateOfLastSyncedWithClient", "{}");
}
