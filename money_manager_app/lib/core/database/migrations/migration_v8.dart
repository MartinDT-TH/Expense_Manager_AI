import 'package:sqflite/sqflite.dart';

/// Migration v8: Align user auth columns with model naming and add password flag
///
/// - Adds `is_google_linked` (int, default 0)
/// - Adds `has_password` (int, default 1)
/// - Copies existing data from legacy `google_linked` into `is_google_linked` when present
class MigrationV8 {
  static Future<void> migrate(Database db) async {
    await _addColumnIfNotExists(db, 'user', 'is_google_linked', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'user', 'has_password', 'INTEGER DEFAULT 1');

    await _copyLegacyGoogleLinked(db);
  }

  static Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final exists = await _columnExists(db, table, column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  static Future<bool> _columnExists(Database db, String table, String column) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    return result.any((row) => row['name'] == column);
  }

  static Future<void> _copyLegacyGoogleLinked(Database db) async {
    final hasGoogleLinked = await _columnExists(db, 'user', 'google_linked');
    final hasIsGoogleLinked = await _columnExists(db, 'user', 'is_google_linked');

    if (hasGoogleLinked && hasIsGoogleLinked) {
      // Preserve any existing value in is_google_linked, otherwise copy legacy value
      await db.execute('''
        UPDATE user
        SET is_google_linked = google_linked
        WHERE google_linked IS NOT NULL
          AND (is_google_linked IS NULL OR is_google_linked = 0)
      ''');
    }
  }
}
