import 'package:sqflite/sqflite.dart';

/// Migration v7: Budget improvements
/// 
/// Changes:
/// 1. Add is_recurring column to budgets table
/// 2. Add category_name, category_icon columns for offline display
/// 3. Add owner_id for multi-user support
/// 4. Add index for budget queries

class MigrationV7 {
  static Future<void> migrate(Database db) async {
    // 1. Add is_recurring column to budgets
    await _addColumnIfNotExists(db, 'budgets', 'is_recurring', 'INTEGER DEFAULT 0');
    
    // 2. Add category info for offline display
    await _addColumnIfNotExists(db, 'budgets', 'category_name', 'TEXT');
    await _addColumnIfNotExists(db, 'budgets', 'category_icon', 'TEXT');
    
    // 3. Add owner_id for multi-user support
    await _addColumnIfNotExists(db, 'budgets', 'owner_id', 'TEXT');
    
    // 4. Add indexes for better query performance
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budgets_owner ON budgets(owner_id)'
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budgets_recurring ON budgets(is_recurring)'
    );
    
    // 5. Update existing budgets - set is_recurring based on date range
    // If start_date is very old (before 2020) or end_date is very far (after 2050), 
    // it's likely a recurring budget
    await db.execute('''
      UPDATE budgets SET is_recurring = 1 
      WHERE start_date < '2020-01-01' OR end_date > '2050-01-01'
    ''');
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
}
