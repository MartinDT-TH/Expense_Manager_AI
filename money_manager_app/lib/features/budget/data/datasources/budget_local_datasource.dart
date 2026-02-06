import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../models/budget_model.dart';

abstract class BudgetLocalDataSource {
  Future<List<BudgetModel>> getBudgets();
  Future<List<BudgetModel>> getActiveBudgets();
  Future<BudgetModel?> getBudgetById(String id);
  Future<BudgetModel?> getCurrentMonthBudget();
  Future<void> saveBudget(BudgetModel budget);
  Future<void> saveBudgets(List<BudgetModel> budgets);
  Future<void> updateBudget(BudgetModel budget);
  Future<void> deleteBudget(String id);
  Future<void> markAsSynced(String id);
  Future<List<BudgetModel>> getUnsyncedBudgets();
  Future<double> calculateSpentAmount(String? categoryId, DateTime startDate, DateTime endDate);
  Future<void> clearAllBudgets();
}

class BudgetLocalDataSourceImpl implements BudgetLocalDataSource {
  final LocalDatabase database;

  BudgetLocalDataSourceImpl({required this.database});

  @override
  Future<List<BudgetModel>> getBudgets() async {
    final db = await database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'is_deleted = 0',
      orderBy: 'start_date DESC',
    );
    
    // Calculate spent amount for each budget
    final budgets = <BudgetModel>[];
    for (final map in maps) {
      final spent = await calculateSpentAmount(
        map['category_id'] as String?,
        DateTime.parse(map['start_date'] as String),
        DateTime.parse(map['end_date'] as String),
      );
      budgets.add(BudgetModel.fromMap(map, calculatedSpent: spent));
    }
    return budgets;
  }

  @override
  Future<List<BudgetModel>> getActiveBudgets() async {
    final db = await database.database;
    final now = DateTime.now();
    
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'is_deleted = 0 AND (is_recurring = 1 OR (start_date <= ? AND end_date >= ?))',
      whereArgs: [now.toIso8601String(), now.toIso8601String()],
      orderBy: 'is_recurring DESC, start_date DESC',
    );
    
    final budgets = <BudgetModel>[];
    for (final map in maps) {
      final isRecurring = (map['is_recurring'] as int?) == 1;
      DateTime startDate, endDate;
      
      if (isRecurring) {
        // For recurring budgets, use current month dates
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else {
        startDate = DateTime.parse(map['start_date'] as String);
        endDate = DateTime.parse(map['end_date'] as String);
      }
      
      final spent = await calculateSpentAmount(
        map['category_id'] as String?,
        startDate,
        endDate,
      );
      budgets.add(BudgetModel.fromMap(map, calculatedSpent: spent));
    }
    return budgets;
  }

  @override
  Future<BudgetModel?> getBudgetById(String id) async {
    final db = await database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    final spent = await calculateSpentAmount(
      map['category_id'] as String?,
      DateTime.parse(map['start_date'] as String),
      DateTime.parse(map['end_date'] as String),
    );
    return BudgetModel.fromMap(map, calculatedSpent: spent);
  }

  @override
  Future<BudgetModel?> getCurrentMonthBudget() async {
    final db = await database.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    // First try to find a specific budget for this month (category_id IS NULL for total budget)
    List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'is_deleted = 0 AND category_id IS NULL AND is_recurring = 0 AND start_date <= ? AND end_date >= ?',
      whereArgs: [endOfMonth.toIso8601String(), startOfMonth.toIso8601String()],
      limit: 1,
    );
    
    // If no specific budget found, try recurring budget
    if (maps.isEmpty) {
      maps = await db.query(
        'budgets',
        where: 'is_deleted = 0 AND category_id IS NULL AND is_recurring = 1',
        limit: 1,
      );
    }
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    final spent = await calculateSpentAmount(null, startOfMonth, endOfMonth);
    return BudgetModel.fromMap(map, calculatedSpent: spent);
  }
  
  @override
  Future<double> calculateSpentAmount(String? categoryId, DateTime startDate, DateTime endDate) async {
    final db = await database.database;
    
    String whereClause;
    List<dynamic> whereArgs;
    
    if (categoryId == null) {
      // Total budget - sum all expense transactions
      whereClause = '''
        is_deleted = 0 
        AND transaction_date >= ? 
        AND transaction_date <= ?
        AND category_id IN (SELECT id FROM categories WHERE type = 'Expense')
      ''';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    } else {
      // Category-specific budget - include subcategories
      whereClause = '''
        is_deleted = 0 
        AND transaction_date >= ? 
        AND transaction_date <= ?
        AND (category_id = ? OR category_id IN (SELECT id FROM categories WHERE parent_id = ?))
      ''';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String(), categoryId, categoryId];
    }
    
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(ABS(amount)), 0) as total
      FROM transactions
      WHERE $whereClause
    ''', whereArgs);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<void> saveBudget(BudgetModel budget) async {
    final db = await database.database;
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveBudgets(List<BudgetModel> budgets) async {
    final db = await database.database;
    final batch = db.batch();
    for (final budget in budgets) {
      batch.insert(
        'budgets',
        budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updateBudget(BudgetModel budget) async {
    final db = await database.database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  @override
  Future<void> deleteBudget(String id) async {
    final db = await database.database;
    await db.update(
      'budgets',
      {'is_deleted': 1, 'is_synced': 0, 'last_updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markAsSynced(String id) async {
    final db = await database.database;
    await db.update(
      'budgets',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<BudgetModel>> getUnsyncedBudgets() async {
    final db = await database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'is_synced = 0',
    );
    return maps.map((map) => BudgetModel.fromMap(map)).toList();
  }

  @override
  Future<void> clearAllBudgets() async {
    final db = await database.database;
    await db.delete('budgets');
  }
}
