import 'dart:convert';
import 'dart:typed_data';
import 'package:budget/farm/backupValidation.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List fakeSqlite({int userVersion = 46, bool withTables = true}) {
  final Uint8List b = Uint8List(4096);
  final List<int> header = ascii.encode('SQLite format 3');
  for (int i = 0; i < header.length; i++) {
    b[i] = header[i];
  }
  b[15] = 0;
  b[60] = (userVersion >> 24) & 0xff;
  b[61] = (userVersion >> 16) & 0xff;
  b[62] = (userVersion >> 8) & 0xff;
  b[63] = userVersion & 0xff;
  if (withTables) {
    final List<int> schema = ascii.encode('CREATE TABLE transactions CREATE TABLE wallets');
    for (int i = 0; i < schema.length; i++) {
      b[200 + i] = schema[i];
    }
  }
  return b;
}

void main() {
  test('accepts a valid backup from an older or equal version', () {
    expect(validateSqliteBackupBytes(fakeSqlite(userVersion: 46), 47), isNull);
    expect(validateSqliteBackupBytes(fakeSqlite(userVersion: 47), 47), isNull);
  });

  test('rejects a backup from a newer app version', () {
    expect(validateSqliteBackupBytes(fakeSqlite(userVersion: 48), 47), 'too-new');
  });

  test('rejects files that are not SQLite databases', () {
    expect(validateSqliteBackupBytes(Uint8List(10), 47), 'too-small');
    expect(validateSqliteBackupBytes(Uint8List(4096), 47), 'not-sqlite');
  });

  test('rejects SQLite files without app tables or version', () {
    expect(validateSqliteBackupBytes(fakeSqlite(withTables: false), 47),
        'not-app-db');
    expect(validateSqliteBackupBytes(fakeSqlite(userVersion: 0), 47),
        'no-version');
  });

  test('reads the user_version from the header', () {
    expect(readSqliteUserVersion(fakeSqlite(userVersion: 46)), 46);
  });
}
