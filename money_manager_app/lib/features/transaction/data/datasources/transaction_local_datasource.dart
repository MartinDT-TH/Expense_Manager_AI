import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../models/transaction_model.dart';

abstract class TransactionLocalDataSource {
  /// Get transactions with basic filters
  Future<List<TransactionModel>> getTransactions({
    String? walletId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  });
  
  /// Get transactions with full TransactionFilter support
  Future<TransactionListResponse> getTransactionsWithFilter(TransactionFilter filter);
  
  /// Get recent transactions for quick access (offline dashboard)
  Future<List<TransactionModel>> getRecentTransactions({int count = 20});
  
  Future<TransactionModel?> getTransactionById(String id);
  Future<void> saveTransaction(TransactionModel transaction);
  Future<void> saveTransactions(List<TransactionModel> transactions);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
  Future<void> markAsSynced(String id);
  Future<List<TransactionModel>> getUnsyncedTransactions();
  Future<void> clearAllTransactions();
  
  /// Replace a temp ID with server ID after sync
  Future<void> replaceTempId(String tempId, String serverId);
  
  /// Delete temp transactions that have been synced (cleanup)
  Future<void> deleteOldTempTransactions();
  
  /// Calculate totals for a filter (for offline reporting)
  Future<Map<String, double>> calculateTotals({
    DateTime? startDate,
    DateTime? endDate,
    String? walletId,
  });
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final LocalDatabase database;

  TransactionLocalDataSourceImpl({required this.database});

  @override
  Future<List<TransactionModel>> getTransactions({
    String? walletId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    final db = await database.database;
    
    String whereClause = 'is_deleted = 0';
    List<dynamic> whereArgs = [];
    
    if (walletId != null) {
      whereClause += ' AND wallet_id = ?';
      whereArgs.add(walletId);
    }
    if (categoryId != null) {
      whereClause += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }
    if (startDate != null) {
      whereClause += ' AND transaction_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND transaction_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    
    return maps.map((map) => TransactionModel.fromDatabase(map)).toList();
  }

  @override
  Future<TransactionListResponse> getTransactionsWithFilter(TransactionFilter filter) async {
    final db = await database.database;
    
    String whereClause = 'is_deleted = 0';
    List<dynamic> whereArgs = [];
    
    if (filter.walletId != null) {
      whereClause += ' AND wallet_id = ?';
      whereArgs.add(filter.walletId);
    }
    if (filter.categoryId != null) {
      whereClause += ' AND category_id = ?';
      whereArgs.add(filter.categoryId);
    }
    if (filter.type != null) {
      whereClause += ' AND type = ?';
      whereArgs.add(filter.type);
    }
    if (filter.groupId != null) {
      whereClause += ' AND group_id = ?';
      whereArgs.add(filter.groupId);
    }
    if (filter.startDate != null) {
      whereClause += ' AND transaction_date >= ?';
      whereArgs.add(filter.startDate!.toIso8601String());
    }
    if (filter.endDate != null) {
      whereClause += ' AND transaction_date <= ?';
      whereArgs.add(filter.endDate!.toIso8601String());
    }
    
    // Get total count
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions WHERE $whereClause',
      whereArgs,
    );
    final totalCount = Sqflite.firstIntValue(countResult) ?? 0;
    
    // Get totals
    final totalsResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END), 0) as totalIncome,
        COALESCE(SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END), 0) as totalExpense
      FROM transactions 
      WHERE $whereClause
    ''', whereArgs);
    
    final totalIncome = (totalsResult.first['totalIncome'] as num?)?.toDouble() ?? 0.0;
    final totalExpense = (totalsResult.first['totalExpense'] as num?)?.toDouble() ?? 0.0;
    
    // Calculate pagination
    final offset = (filter.page - 1) * filter.pageSize;
    final totalPages = (totalCount / filter.pageSize).ceil();
    
    // Get paginated items
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: filter.pageSize,
      offset: offset,
    );
    
    final items = maps.map((map) => TransactionModel.fromDatabase(map)).toList();
    
    return TransactionListResponse(
      items: items,
      totalCount: totalCount,
      page: filter.page,
      pageSize: filter.pageSize,
      totalPages: totalPages > 0 ? totalPages : 1,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }

  @override
  Future<List<TransactionModel>> getRecentTransactions({int count = 20}) async {
    final db = await database.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'is_deleted = 0',
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: count,
    );
    
    return maps.map((map) => TransactionModel.fromDatabase(map)).toList();
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TransactionModel.fromDatabase(maps.first);
  }

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    final db = await database.database;
    final data = transaction.toDatabase();
    // Ensure last_updated_at is set
    data['last_updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'transactions',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveTransactions(List<TransactionModel> transactions) async {
    final db = await database.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    
    for (final transaction in transactions) {
      final data = transaction.toDatabase();
      data['last_updated_at'] = now;
      batch.insert(
        'transactions',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await database.database;
    final data = transaction.toDatabase();
    data['last_updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'transactions',
      data,
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final db = await database.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'transactions',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': now,
        'last_updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markAsSynced(String id) async {
    final db = await database.database;
    await db.update(
      'transactions',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    final db = await database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'is_synced = 0 AND is_deleted = 0',
      orderBy: 'created_at ASC', // Process oldest first
    );
    return maps.map((map) => TransactionModel.fromDatabase(map)).toList();
  }

  @override
  Future<void> clearAllTransactions() async {
    final db = await database.database;
    await db.delete('transactions');
  }

  @override
  Future<void> replaceTempId(String tempId, String serverId) async {
    final db = await database.database;
    
    // Get the transaction with temp ID
    final existing = await getTransactionById(tempId);
    if (existing == null) return;
    
    // Delete the temp record
    await db.delete('transactions', where: 'id = ?', whereArgs: [tempId]);
    
    // Insert with new server ID
    final updatedTransaction = TransactionModel(
      id: serverId,
      amount: existing.amount,
      type: existing.type,
      categoryId: existing.categoryId,
      categoryName: existing.categoryName,
      categoryIcon: existing.categoryIcon,
      walletId: existing.walletId,
      walletName: existing.walletName,
      groupId: existing.groupId,
      groupName: existing.groupName,
      note: existing.note,
      description: existing.description,
      transactionDate: existing.transactionDate,
      receiptUrl: existing.receiptUrl,
      location: existing.location,
      isRecurring: existing.isRecurring,
      recurringId: existing.recurringId,
      createdByUserId: existing.createdByUserId,
      createdByUserName: existing.createdByUserName,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
      isSynced: true,
    );
    
    await saveTransaction(updatedTransaction);
  }

  @override
  Future<void> deleteOldTempTransactions() async {
    final db = await database.database;
    // Delete temp transactions that are older than 7 days and already synced
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    await db.delete(
      'transactions',
      where: "id LIKE 'temp_%' AND is_synced = 1 AND created_at < ?",
      whereArgs: [cutoffDate],
    );
  }

  @override
  Future<Map<String, double>> calculateTotals({
    DateTime? startDate,
    DateTime? endDate,
    String? walletId,
  }) async {
    final db = await database.database;
    
    String whereClause = 'is_deleted = 0';
    List<dynamic> whereArgs = [];
    
    if (walletId != null) {
      whereClause += ' AND wallet_id = ?';
      whereArgs.add(walletId);
    }
    if (startDate != null) {
      whereClause += ' AND transaction_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND transaction_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END), 0) as totalIncome,
        COALESCE(SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END), 0) as totalExpense
      FROM transactions 
      WHERE $whereClause
    ''', whereArgs);
    
    return {
      'totalIncome': (result.first['totalIncome'] as num?)?.toDouble() ?? 0.0,
      'totalExpense': (result.first['totalExpense'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
