import 'dart:convert';
import 'dart:typed_data';

/// Pure-Dart checks run on a backup file BEFORE it is allowed to replace the
/// live database. Returns null when the bytes look like a usable backup, or a
/// short error code otherwise:
///  'too-small'  - not enough bytes to be a SQLite database
///  'not-sqlite' - missing the "SQLite format 3" header
///  'no-version' - header user_version is 0 (not an app database)
///  'too-new'    - backup was made by a newer app version than this one
///  'not-app-db' - SQLite file but without the expected tables
String? validateSqliteBackupBytes(Uint8List bytes, int appSchemaVersion) {
  if (bytes.length < 1024) return 'too-small';
  const String header = 'SQLite format 3';
  for (int i = 0; i < header.length; i++) {
    if (bytes[i] != header.codeUnitAt(i)) return 'not-sqlite';
  }
  if (bytes[15] != 0) return 'not-sqlite';
  // user_version is a 4-byte big-endian integer at offset 60
  int userVersion =
      (bytes[60] << 24) | (bytes[61] << 16) | (bytes[62] << 8) | bytes[63];
  if (userVersion <= 0) return 'no-version';
  if (userVersion > appSchemaVersion) return 'too-new';
  String text = latin1.decode(bytes, allowInvalid: true);
  if (!text.contains('transactions') || !text.contains('wallets')) {
    return 'not-app-db';
  }
  return null;
}

/// Reads the schema version stored in the file header (or null).
int? readSqliteUserVersion(Uint8List bytes) {
  if (bytes.length < 64) return null;
  return (bytes[60] << 24) | (bytes[61] << 16) | (bytes[62] << 8) | bytes[63];
}
