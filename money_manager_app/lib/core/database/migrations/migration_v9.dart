import 'package:sqflite/sqflite.dart';

/// Migration v9: Extend transactions table for offline-first support
/// Adds missing columns: type, category_name, category_icon, wallet_name,
/// group_name, receipt_url, location, is_recurring, recurring_id, created_at, updated_at
class MigrationV9 {
  static Future<void> migrate(Database db) async {
    // Check if columns already exist before adding
    final tableInfo = await db.rawQuery('PRAGMA table_info(transactions)');
    final existingColumns = tableInfo.map((e) => e['name'] as String).toSet();

    // Add type column (INCOME/EXPENSE)
    if (!existingColumns.contains('type')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN type TEXT DEFAULT "EXPENSE"');
    }

    // Add category display info for offline
    if (!existingColumns.contains('category_name')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN category_name TEXT');
    }
    if (!existingColumns.contains('category_icon')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN category_icon TEXT');
    }

    // Add wallet display info for offline
    if (!existingColumns.contains('wallet_name')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN wallet_name TEXT');
    }

    // Add group display info for offline
    if (!existingColumns.contains('group_name')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN group_name TEXT');
    }

    // Add receipt_url (separate from bill_image_url for clarity)
    if (!existingColumns.contains('receipt_url')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN receipt_url TEXT');
      // Copy existing bill_image_url to receipt_url
      await db.execute('UPDATE transactions SET receipt_url = bill_image_url WHERE bill_image_url IS NOT NULL');
    }

    // Add location
    if (!existingColumns.contains('location')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN location TEXT');
    }

    // Add recurring fields
    if (!existingColumns.contains('is_recurring')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN is_recurring INTEGER DEFAULT 0');
    }
    if (!existingColumns.contains('recurring_id')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN recurring_id TEXT');
    }

    // Add created_at and updated_at
    if (!existingColumns.contains('created_at')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN created_at TEXT');
      // Copy last_updated_at to created_at for existing records
      await db.execute('UPDATE transactions SET created_at = last_updated_at WHERE created_at IS NULL');
    }
    if (!existingColumns.contains('updated_at')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN updated_at TEXT');
      // Copy last_updated_at to updated_at for existing records
      await db.execute('UPDATE transactions SET updated_at = last_updated_at WHERE updated_at IS NULL');
    }

    // Add index for is_synced to optimize sync queries
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_is_synced ON transactions(is_synced)');
    } catch (e) {
      // Index might already exist
    }

    // Add index for type to optimize filtered queries
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)');
    } catch (e) {
      // Index might already exist
    }
  }
}
