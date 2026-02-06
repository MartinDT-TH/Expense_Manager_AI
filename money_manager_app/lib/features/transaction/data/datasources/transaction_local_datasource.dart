import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../models/transaction_model.dart';

abstract class TransactionLocalDataSource {
  Future<List<TransactionModel>> getTransactions({
    String? walletId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  });
  Future<TransactionModel?> getTransactionById(String id);
  Future<void> saveTransaction(TransactionModel transaction);
  Future<void> saveTransactions(List<TransactionModel> transactions);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
  Future<void> markAsSynced(String id);
  Future<List<TransactionModel>> getUnsyncedTransactions();
  Future<void> clearAllTransactions();
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
      orderBy: 'transaction_date DESC',
      limit: limit,
      offset: offset,
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
    await db.insert(
      'transactions',
      transaction.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveTransactions(List<TransactionModel> transactions) async {
    final db = await database.database;
    final batch = db.batch();
    for (final transaction in transactions) {
      batch.insert(
        'transactions',
        transaction.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await database.database;
    await db.update(
      'transactions',
      transaction.toDatabase(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final db = await database.database;
    await db.update(
      'transactions',
      {'is_deleted': 1, 'is_synced': 0, 'last_updated_at': DateTime.now().toIso8601String()},
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
      where: 'is_synced = 0',
    );
    return maps.map((map) => TransactionModel.fromDatabase(map)).toList();
  }

  @override
  Future<void> clearAllTransactions() async {
    final db = await database.database;
    await db.delete('transactions');
  }
}
