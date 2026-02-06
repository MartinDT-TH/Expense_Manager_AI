import 'package:sqflite/sqflite.dart';

/// Migration v6: Add notifications table and extend user profile
/// 
/// Changes:
/// 1. Create notifications table
/// 2. Add phone, address, date_of_birth, gender to user table
/// 3. Add 2fa_enabled, 2fa_secret, google_linked to user table
/// 4. Create user_settings table
/// 5. Add performance indexes

class MigrationV6 {
  static Future<void> migrate(Database db) async {
    // 1. Create notifications table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        data TEXT,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Index for unread notifications
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(is_read, created_at DESC)'
    );

    // 2. Extend user table with profile fields
    // Note: SQLite doesn't support adding multiple columns in one ALTER statement
    await _addColumnIfNotExists(db, 'user', 'phone', 'TEXT');
    await _addColumnIfNotExists(db, 'user', 'address', 'TEXT');
    await _addColumnIfNotExists(db, 'user', 'date_of_birth', 'TEXT');
    await _addColumnIfNotExists(db, 'user', 'gender', 'TEXT');
    
    // 3. Add 2FA and Google auth fields
    await _addColumnIfNotExists(db, 'user', 'two_factor_enabled', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'user', 'two_factor_secret', 'TEXT');
    await _addColumnIfNotExists(db, 'user', 'google_linked', 'INTEGER DEFAULT 0');
    await _addColumnIfNotExists(db, 'user', 'google_email', 'TEXT');

    // 4. Create user_settings table for app preferences
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 5. Add performance indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_is_deleted ON transactions(is_deleted)'
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wallets_is_deleted ON wallets(is_deleted)'
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budgets_dates ON budgets(start_date, end_date)'
    );
    
    // Insert default settings
    await _insertDefaultSettings(db);
  }

  static Future<void> _addColumnIfNotExists(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (e) {
      // Column already exists, ignore error
      if (!e.toString().contains('duplicate column')) {
        rethrow;
      }
    }
  }

  static Future<void> _insertDefaultSettings(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaultSettings = {
      'notification_enabled': 'true',
      'budget_alert_threshold': '80',  // Percent
      'daily_reminder_enabled': 'false',
      'daily_reminder_time': '20:00',
      'currency': 'VND',
      'language': 'en',
      'first_day_of_week': '1',  // Monday
    };

    for (final entry in defaultSettings.entries) {
      await db.insert(
        'user_settings',
        {
          'key': entry.key,
          'value': entry.value,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
