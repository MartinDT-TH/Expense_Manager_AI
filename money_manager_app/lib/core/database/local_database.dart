import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static Database? _database;
  static const String _databaseName = 'money_manager.db';
  static const int _databaseVersion = 5; // Version 5: Added created_by fields to transactions

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Wallets table (with initial_balance)
    await db.execute('''
      CREATE TABLE wallets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        initial_balance REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        currency TEXT NOT NULL,
        type TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        last_updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon_code TEXT,
        parent_id TEXT,
        user_id TEXT,
        is_system INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES categories (id)
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        note TEXT,
        transaction_date TEXT NOT NULL,
        wallet_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        group_id TEXT,
        bill_image_url TEXT,
        created_by_user_id TEXT,
        created_by_user_name TEXT,
        is_deleted INTEGER DEFAULT 0,
        last_updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (wallet_id) REFERENCES wallets (id),
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        amount_limit REAL NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        last_updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Groups table (updated with more fields)
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        invite_code TEXT,
        member_count INTEGER DEFAULT 0,
        current_user_role TEXT DEFAULT 'MEMBER',
        created_by_user_id TEXT NOT NULL,
        created_by_user_name TEXT,
        total_expense REAL DEFAULT 0,
        total_income REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // Group members table
    await db.execute('''
      CREATE TABLE group_members (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        full_name TEXT,
        email TEXT,
        avatar_url TEXT,
        role TEXT DEFAULT 'MEMBER',
        joined_at TEXT NOT NULL,
        total_contribution REAL DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 1,
        FOREIGN KEY (group_id) REFERENCES groups (id)
      )
    ''');

    // User table
    await db.execute('''
      CREATE TABLE user (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        avatar_url TEXT,
        is_premium INTEGER DEFAULT 0
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_transactions_wallet ON transactions(wallet_id)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category_id)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_budgets_category ON budgets(category_id)');
    await db.execute('CREATE INDEX idx_categories_parent ON categories(parent_id)');

    // Insert default categories
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      // Add new columns to categories table
      await db.execute('ALTER TABLE categories ADD COLUMN is_system INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE categories ADD COLUMN user_id TEXT');
      await db.execute('ALTER TABLE categories ADD COLUMN created_at TEXT');
      await db.execute('ALTER TABLE categories ADD COLUMN updated_at TEXT');
      
      // Migrate data: copy last_updated_at to created_at and updated_at
      await db.execute('''
        UPDATE categories SET 
          created_at = last_updated_at,
          updated_at = last_updated_at,
          is_system = CASE WHEN id LIKE 'cat-%' THEN 1 ELSE 0 END
      ''');
    }
    
    // Version 3: Add initial_balance to wallets
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE wallets ADD COLUMN initial_balance REAL DEFAULT 0');
      // Set initial_balance = balance for existing wallets
      await db.execute('UPDATE wallets SET initial_balance = balance');
    }

    // Version 4: Update groups table and add group_members table
    if (oldVersion < 4) {
      // Drop old groups table and recreate with new schema
      await db.execute('DROP TABLE IF EXISTS groups');
      await db.execute('''
        CREATE TABLE groups (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          invite_code TEXT,
          member_count INTEGER DEFAULT 0,
          current_user_role TEXT DEFAULT 'MEMBER',
          created_by_user_id TEXT NOT NULL DEFAULT '',
          created_by_user_name TEXT,
          total_expense REAL DEFAULT 0,
          total_income REAL DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT '',
          last_updated_at TEXT NOT NULL DEFAULT '',
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      // Create group_members table
      await db.execute('''
        CREATE TABLE group_members (
          id TEXT PRIMARY KEY,
          group_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          full_name TEXT,
          email TEXT,
          avatar_url TEXT,
          role TEXT DEFAULT 'MEMBER',
          joined_at TEXT NOT NULL DEFAULT '',
          total_contribution REAL DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 1,
          FOREIGN KEY (group_id) REFERENCES groups (id)
        )
      ''');

      // Add indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_group ON transactions(group_id)');
    }
    
    // Version 5: Add created_by fields to transactions table
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE transactions ADD COLUMN created_by_user_id TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN created_by_user_name TEXT');
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // Expense categories
    final expenseCategories = [
      {'id': 'cat-food', 'name': 'Food & Drinks', 'type': 'Expense', 'icon_code': 'restaurant'},
      {'id': 'cat-transport', 'name': 'Transportation', 'type': 'Expense', 'icon_code': 'directions_car'},
      {'id': 'cat-shopping', 'name': 'Shopping', 'type': 'Expense', 'icon_code': 'shopping_cart'},
      {'id': 'cat-entertainment', 'name': 'Entertainment', 'type': 'Expense', 'icon_code': 'movie'},
      {'id': 'cat-health', 'name': 'Health', 'type': 'Expense', 'icon_code': 'medical_services'},
      {'id': 'cat-education', 'name': 'Education', 'type': 'Expense', 'icon_code': 'school'},
      {'id': 'cat-utilities', 'name': 'Bills & Utilities', 'type': 'Expense', 'icon_code': 'receipt'},
      {'id': 'cat-groceries', 'name': 'Groceries', 'type': 'Expense', 'icon_code': 'local_grocery_store'},
      {'id': 'cat-rent', 'name': 'Rent', 'type': 'Expense', 'icon_code': 'home'},
      {'id': 'cat-insurance', 'name': 'Insurance', 'type': 'Expense', 'icon_code': 'security'},
      {'id': 'cat-pets', 'name': 'Pets', 'type': 'Expense', 'icon_code': 'pets'},
      {'id': 'cat-gifts', 'name': 'Gifts', 'type': 'Expense', 'icon_code': 'card_giftcard'},
      {'id': 'cat-travel', 'name': 'Travel', 'type': 'Expense', 'icon_code': 'flight'},
      {'id': 'cat-fitness', 'name': 'Fitness', 'type': 'Expense', 'icon_code': 'fitness_center'},
      {'id': 'cat-personal', 'name': 'Personal Care', 'type': 'Expense', 'icon_code': 'spa'},
      {'id': 'cat-other-expense', 'name': 'Other Expense', 'type': 'Expense', 'icon_code': 'more_horiz'},
    ];

    // Income categories
    final incomeCategories = [
      {'id': 'cat-salary', 'name': 'Salary', 'type': 'Income', 'icon_code': 'payments'},
      {'id': 'cat-bonus', 'name': 'Bonus', 'type': 'Income', 'icon_code': 'card_giftcard'},
      {'id': 'cat-investment', 'name': 'Investment', 'type': 'Income', 'icon_code': 'trending_up'},
      {'id': 'cat-freelance', 'name': 'Freelance', 'type': 'Income', 'icon_code': 'computer'},
      {'id': 'cat-business', 'name': 'Business', 'type': 'Income', 'icon_code': 'business'},
      {'id': 'cat-rental', 'name': 'Rental Income', 'type': 'Income', 'icon_code': 'house'},
      {'id': 'cat-refund', 'name': 'Refund', 'type': 'Income', 'icon_code': 'replay'},
      {'id': 'cat-other-income', 'name': 'Other Income', 'type': 'Income', 'icon_code': 'attach_money'},
    ];

    for (final category in [...expenseCategories, ...incomeCategories]) {
      await db.insert('categories', {
        ...category,
        'is_system': 1, // Default categories are system categories
        'is_deleted': 0,
        'created_at': now,
        'updated_at': now,
        'is_synced': 1,
      });
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('wallets');
    await db.delete('groups');
    await db.delete('user');
    await db.delete('sync_queue');
    // Keep default categories
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
