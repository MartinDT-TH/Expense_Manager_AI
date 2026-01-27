import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../models/wallet_model.dart';

abstract class WalletLocalDataSource {
  Future<List<WalletModel>> getWallets();
  Future<WalletModel?> getWalletById(String id);
  Future<void> saveWallet(WalletModel wallet);
  Future<void> saveWallets(List<WalletModel> wallets);
  Future<void> deleteWallet(String id);
  Future<double> getTotalBalance();
  Future<List<WalletModel>> getUnsyncedWallets();
  Future<void> markAsSynced(String id);
}

class WalletLocalDataSourceImpl implements WalletLocalDataSource {
  final LocalDatabase database;

  WalletLocalDataSourceImpl({required this.database});

  @override
  Future<List<WalletModel>> getWallets() async {
    final db = await database.database;
    final results = await db.query(
      'wallets',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'name ASC',
    );
    return results.map((map) => WalletModel.fromDatabase(map)).toList();
  }

  @override
  Future<WalletModel?> getWalletById(String id) async {
    final db = await database.database;
    final results = await db.query(
      'wallets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return WalletModel.fromDatabase(results.first);
    }
    return null;
  }

  @override
  Future<void> saveWallet(WalletModel wallet) async {
    final db = await database.database;
    await db.insert(
      'wallets',
      wallet.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveWallets(List<WalletModel> wallets) async {
    final db = await database.database;
    
    // Xóa tất cả wallets cũ trước khi sync từ server
    // để tránh duplicate khi server reset data với ID mới
    await db.delete('wallets');
    
    final batch = db.batch();
    for (final wallet in wallets) {
      batch.insert(
        'wallets',
        wallet.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteWallet(String id) async {
    final db = await database.database;
    // Soft delete
    await db.update(
      'wallets',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'last_updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<double> getTotalBalance() async {
    final db = await database.database;
    final result = await db.rawQuery(
      'SELECT SUM(balance) as total FROM wallets WHERE is_deleted = 0',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<List<WalletModel>> getUnsyncedWallets() async {
    final db = await database.database;
    final results = await db.query(
      'wallets',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return results.map((map) => WalletModel.fromDatabase(map)).toList();
  }

  @override
  Future<void> markAsSynced(String id) async {
    final db = await database.database;
    await db.update(
      'wallets',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
