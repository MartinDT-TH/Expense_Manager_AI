import '../../../../core/network/network_info.dart';
import '../../../../core/sync/sync_queue_processor.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_local_datasource.dart';
import '../datasources/transaction_remote_datasource.dart';
import '../models/transaction_model.dart';

/// Offline-first implementation of TransactionRepository
/// 
/// Strategy:
/// - READ: Try remote first, cache locally, fallback to local on error/offline
/// - CREATE: Save locally immediately, sync to remote when online
/// - UPDATE: Update locally immediately, sync to remote when online
/// - DELETE: Mark deleted locally, sync to remote when online
class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;
  final TransactionLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final SyncQueueProcessor syncQueue;

  TransactionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.syncQueue,
  });

  @override
  Future<TransactionListResponse> getTransactions(TransactionFilter filter) async {
    if (await networkInfo.checkConnection()) {
      try {
        // Fetch from remote
        final remoteResponse = await remoteDataSource.getTransactions(filter);
        
        // Cache to local (mark as synced)
        final syncedItems = remoteResponse.items.map((item) => TransactionModel(
          id: item.id,
          amount: item.amount,
          type: item.type,
          categoryId: item.categoryId,
          categoryName: item.categoryName,
          categoryIcon: item.categoryIcon,
          walletId: item.walletId,
          walletName: item.walletName,
          groupId: item.groupId,
          groupName: item.groupName,
          note: item.note,
          description: item.description,
          transactionDate: item.transactionDate,
          receiptUrl: item.receiptUrl,
          location: item.location,
          isRecurring: item.isRecurring,
          recurringId: item.recurringId,
          createdByUserId: item.createdByUserId,
          createdByUserName: item.createdByUserName,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
          isSynced: true,
        )).toList();
        
        await localDataSource.saveTransactions(syncedItems);
        
        return remoteResponse;
      } catch (e) {
        // Fallback to local on error
        return await localDataSource.getTransactionsWithFilter(filter);
      }
    }
    
    // Offline: return local data
    return await localDataSource.getTransactionsWithFilter(filter);
  }

  @override
  Future<List<Transaction>> getRecentTransactions({int count = 5}) async {
    if (await networkInfo.checkConnection()) {
      try {
        final remoteTransactions = await remoteDataSource.getRecentTransactions(count: count);
        
        // Cache to local
        final models = remoteTransactions.map((t) => TransactionModel.fromEntity(t).copyWithSynced(true)).toList();
        await localDataSource.saveTransactions(models);
        
        return remoteTransactions;
      } catch (e) {
        // Fallback to local
        return await localDataSource.getRecentTransactions(count: count);
      }
    }
    
    // Offline: return local data
    return await localDataSource.getRecentTransactions(count: count);
  }

  @override
  Future<Transaction?> getTransactionById(String id) async {
    if (await networkInfo.checkConnection()) {
      try {
        final remoteTransaction = await remoteDataSource.getTransactionById(id);
        // Cache to local
        final model = TransactionModel.fromEntity(remoteTransaction).copyWithSynced(true);
        await localDataSource.saveTransaction(model);
        return remoteTransaction;
      } catch (e) {
        // Fallback to local
        return await localDataSource.getTransactionById(id);
      }
    }
    
    // Offline: return local data
    return await localDataSource.getTransactionById(id);
  }

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    final now = DateTime.now();
    
    // Generate temp ID for offline transactions
    final isOffline = !await networkInfo.checkConnection();
    final tempId = isOffline ? 'temp_${now.millisecondsSinceEpoch}' : transaction.id;
    
    // Create model with temp ID and mark as unsynced if offline
    final localModel = TransactionModel(
      id: tempId.isEmpty ? 'temp_${now.millisecondsSinceEpoch}' : tempId,
      amount: transaction.amount,
      type: transaction.type,
      categoryId: transaction.categoryId,
      categoryName: transaction.categoryName,
      categoryIcon: transaction.categoryIcon,
      walletId: transaction.walletId,
      walletName: transaction.walletName,
      groupId: transaction.groupId,
      groupName: transaction.groupName,
      note: transaction.note,
      description: transaction.description,
      transactionDate: transaction.transactionDate,
      receiptUrl: transaction.receiptUrl,
      location: transaction.location,
      isRecurring: transaction.isRecurring,
      recurringId: transaction.recurringId,
      createdByUserId: transaction.createdByUserId,
      createdByUserName: transaction.createdByUserName,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );
    
    // Save to local immediately (user sees instant feedback)
    await localDataSource.saveTransaction(localModel);
    
    if (await networkInfo.checkConnection()) {
      try {
        // Try to sync to remote
        final remoteModel = TransactionModel.fromEntity(transaction);
        final createdTransaction = await remoteDataSource.createTransaction(remoteModel);
        
        // Delete old local record and save new one with server ID
        final db = await (localDataSource as TransactionLocalDataSourceImpl).database.database;
        await db.delete('transactions', where: 'id = ?', whereArgs: [localModel.id]);
        
        // Save with server ID and mark as synced
        final syncedModel = TransactionModel(
          id: createdTransaction.id,
          amount: createdTransaction.amount,
          type: createdTransaction.type,
          categoryId: createdTransaction.categoryId,
          categoryName: createdTransaction.categoryName,
          categoryIcon: createdTransaction.categoryIcon,
          walletId: createdTransaction.walletId,
          walletName: createdTransaction.walletName,
          groupId: createdTransaction.groupId,
          groupName: createdTransaction.groupName,
          note: createdTransaction.note,
          description: createdTransaction.description,
          transactionDate: createdTransaction.transactionDate,
          receiptUrl: createdTransaction.receiptUrl,
          location: createdTransaction.location,
          isRecurring: createdTransaction.isRecurring,
          recurringId: createdTransaction.recurringId,
          createdByUserId: createdTransaction.createdByUserId,
          createdByUserName: createdTransaction.createdByUserName,
          createdAt: createdTransaction.createdAt,
          updatedAt: createdTransaction.updatedAt,
          isSynced: true,
        );
        await localDataSource.saveTransaction(syncedModel);
        
        return createdTransaction;
      } catch (e) {
        // Failed to sync - queue for later
        await syncQueue.addToQueue(
          entityType: 'transaction',
          entityId: localModel.id,
          action: SyncAction.create,
          data: localModel.toJson(),
        );
        
        // Return local model - user still sees their transaction
        return localModel;
      }
    }
    
    // Offline: queue for sync when online
    await syncQueue.addToQueue(
      entityType: 'transaction',
      entityId: localModel.id,
      action: SyncAction.create,
      data: localModel.toJson(),
    );
    
    return localModel;
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    final now = DateTime.now();
    
    // Update local immediately
    final localModel = TransactionModel(
      id: transaction.id,
      amount: transaction.amount,
      type: transaction.type,
      categoryId: transaction.categoryId,
      categoryName: transaction.categoryName,
      categoryIcon: transaction.categoryIcon,
      walletId: transaction.walletId,
      walletName: transaction.walletName,
      groupId: transaction.groupId,
      groupName: transaction.groupName,
      note: transaction.note,
      description: transaction.description,
      transactionDate: transaction.transactionDate,
      receiptUrl: transaction.receiptUrl,
      location: transaction.location,
      isRecurring: transaction.isRecurring,
      recurringId: transaction.recurringId,
      createdByUserId: transaction.createdByUserId,
      createdByUserName: transaction.createdByUserName,
      createdAt: transaction.createdAt,
      updatedAt: now,
      isSynced: false,
    );
    
    await localDataSource.updateTransaction(localModel);
    
    if (await networkInfo.checkConnection()) {
      try {
        // Skip remote update for temp IDs (will be created, not updated)
        if (transaction.id.startsWith('temp_')) {
          return localModel;
        }
        
        final remoteModel = TransactionModel.fromEntity(transaction);
        final updatedTransaction = await remoteDataSource.updateTransaction(remoteModel);
        
        // Mark as synced
        await localDataSource.markAsSynced(updatedTransaction.id);
        
        return updatedTransaction;
      } catch (e) {
        // Failed to sync - queue for later
        if (!transaction.id.startsWith('temp_')) {
          await syncQueue.addToQueue(
            entityType: 'transaction',
            entityId: transaction.id,
            action: SyncAction.update,
            data: localModel.toJson(),
          );
        }
        
        return localModel;
      }
    }
    
    // Offline: queue for sync (only if not temp)
    if (!transaction.id.startsWith('temp_')) {
      await syncQueue.addToQueue(
        entityType: 'transaction',
        entityId: transaction.id,
        action: SyncAction.update,
        data: localModel.toJson(),
      );
    }
    
    return localModel;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    // Mark as deleted locally immediately
    await localDataSource.deleteTransaction(id);
    
    if (await networkInfo.checkConnection()) {
      try {
        // Skip remote delete for temp IDs
        if (id.startsWith('temp_')) {
          return;
        }
        
        await remoteDataSource.deleteTransaction(id);
        // Physically delete from local since server confirmed
        final db = await (localDataSource as TransactionLocalDataSourceImpl).database.database;
        await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        // Failed to sync - queue for later
        if (!id.startsWith('temp_')) {
          await syncQueue.addToQueue(
            entityType: 'transaction',
            entityId: id,
            action: SyncAction.delete,
            data: {'id': id},
          );
        }
      }
      return;
    }
    
    // Offline: queue for sync (only if not temp)
    if (!id.startsWith('temp_')) {
      await syncQueue.addToQueue(
        entityType: 'transaction',
        entityId: id,
        action: SyncAction.delete,
        data: {'id': id},
      );
    }
  }

  /// Get count of pending sync items (from sync_queue)
  Future<int> getUnsyncedCount() async {
    return await syncQueue.getPendingCount();
  }
}

/// Extension to create synced copy of TransactionModel
extension TransactionModelExtension on TransactionModel {
  TransactionModel copyWithSynced(bool synced) {
    return TransactionModel(
      id: id,
      amount: amount,
      type: type,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      walletId: walletId,
      walletName: walletName,
      groupId: groupId,
      groupName: groupName,
      note: note,
      description: description,
      transactionDate: transactionDate,
      receiptUrl: receiptUrl,
      location: location,
      isRecurring: isRecurring,
      recurringId: recurringId,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: synced,
    );
  }
}
