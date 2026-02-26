import '../../../../core/network/network_info.dart';
import '../datasources/budget_datasource.dart';
import '../datasources/budget_local_datasource.dart';
import '../models/budget_model.dart';
import '../../domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetRemoteDataSource _remoteDataSource;
  final BudgetLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;

  BudgetRepositoryImpl({
    required BudgetRemoteDataSource remoteDataSource,
    required BudgetLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkInfo = networkInfo;

  @override
  Future<List<BudgetModel>> getBudgets() async {
    if (await _networkInfo.checkConnection()) {
      try {
        final remoteBudgets = await _remoteDataSource.getBudgets();
        // Cache to local database
        await _localDataSource.saveBudgets(remoteBudgets);
        return remoteBudgets;
      } catch (e) {
        // Fallback to local data on error
        return _localDataSource.getBudgets();
      }
    }
    return _localDataSource.getBudgets();
  }

  @override
  Future<List<BudgetModel>> getActiveBudgets() async {
    if (await _networkInfo.checkConnection()) {
      try {
        final remoteBudgets = await _remoteDataSource.getActiveBudgets();
        // Cache to local database
        await _localDataSource.saveBudgets(remoteBudgets);
        return remoteBudgets;
      } catch (e) {
        return _localDataSource.getActiveBudgets();
      }
    }
    return _localDataSource.getActiveBudgets();
  }

  @override
  Future<BudgetModel?> getCurrentMonthBudget() async {
    if (await _networkInfo.checkConnection()) {
      try {
        final remoteBudget = await _remoteDataSource.getCurrentMonthBudget();
        if (remoteBudget != null) {
          await _localDataSource.saveBudget(remoteBudget);
        }
        return remoteBudget;
      } catch (e) {
        return _localDataSource.getCurrentMonthBudget();
      }
    }
    return _localDataSource.getCurrentMonthBudget();
  }

  @override
  Future<BudgetModel?> getBudgetById(String id) async {
    if (await _networkInfo.checkConnection()) {
      try {
        final remoteBudget = await _remoteDataSource.getBudgetById(id);
        if (remoteBudget != null) {
          await _localDataSource.saveBudget(remoteBudget);
        }
        return remoteBudget;
      } catch (e) {
        return _localDataSource.getBudgetById(id);
      }
    }
    return _localDataSource.getBudgetById(id);
  }

  @override
  Future<BudgetModel> createBudget(CreateBudgetRequest request) async {
    if (await _networkInfo.checkConnection()) {
      final budget = await _remoteDataSource.createBudget(request);
      // Save to local with synced flag
      await _localDataSource.saveBudget(budget);
      await _localDataSource.markAsSynced(budget.id);
      return budget;
    }
    
    // Offline: Create locally and queue for sync
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    final offlineBudget = BudgetModel(
      id: request.id ?? 'offline_${DateTime.now().millisecondsSinceEpoch}',
      amountLimit: request.amountLimit,
      amountSpent: 0,
      amountRemaining: request.amountLimit,
      percentUsed: 0,
      isWarning: false,
      isExceeded: false,
      isRecurring: request.isRecurring,
      categoryId: request.categoryId,
      categoryName: '',
      startDate: request.startDate ?? startOfMonth,
      endDate: request.endDate ?? endOfMonth,
      createdAt: now,
      updatedAt: now,
    );
    
    await _localDataSource.saveBudget(offlineBudget);
    return offlineBudget;
  }

  @override
  Future<BudgetModel> updateBudget(String id, UpdateBudgetRequest request) async {
    if (await _networkInfo.checkConnection()) {
      final budget = await _remoteDataSource.updateBudget(id, request);
      await _localDataSource.saveBudget(budget);
      await _localDataSource.markAsSynced(budget.id);
      return budget;
    }
    
    // Offline: Update locally
    final existingBudget = await _localDataSource.getBudgetById(id);
    if (existingBudget == null) {
      throw Exception('Không tìm thấy ngân sách');
    }
    
    final updatedBudget = BudgetModel(
      id: existingBudget.id,
      amountLimit: request.amountLimit ?? existingBudget.amountLimit,
      amountSpent: existingBudget.amountSpent,
      amountRemaining: (request.amountLimit ?? existingBudget.amountLimit) - existingBudget.amountSpent,
      percentUsed: existingBudget.amountLimit > 0 
          ? (existingBudget.amountSpent / (request.amountLimit ?? existingBudget.amountLimit)) * 100 
          : 0,
      isWarning: existingBudget.isWarning,
      isExceeded: existingBudget.isExceeded,
      isRecurring: request.isRecurring ?? existingBudget.isRecurring,
      categoryId: request.categoryId ?? existingBudget.categoryId,
      categoryName: existingBudget.categoryName,
      categoryIcon: existingBudget.categoryIcon,
      startDate: request.startDate ?? existingBudget.startDate,
      endDate: request.endDate ?? existingBudget.endDate,
      createdAt: existingBudget.createdAt,
      updatedAt: DateTime.now(),
    );
    
    await _localDataSource.updateBudget(updatedBudget);
    return updatedBudget;
  }

  @override
  Future<bool> deleteBudget(String id) async {
    if (await _networkInfo.checkConnection()) {
      final success = await _remoteDataSource.deleteBudget(id);
      if (success) {
        await _localDataSource.deleteBudget(id);
      }
      return success;
    }
    
    // Offline: Mark as deleted locally
    await _localDataSource.deleteBudget(id);
    return true;
  }

  @override
  Future<BudgetWarningResponse> getBudgetWarnings() async {
    if (await _networkInfo.checkConnection()) {
      try {
        return await _remoteDataSource.getBudgetWarnings();
      } catch (e) {
        // Calculate warnings from local data
        return _calculateLocalWarnings();
      }
    }
    return _calculateLocalWarnings();
  }

  Future<BudgetWarningResponse> _calculateLocalWarnings() async {
    final budgets = await _localDataSource.getActiveBudgets();
    final warningBudgets = budgets.where((b) => b.isWarning && !b.isExceeded).toList();
    final exceededBudgets = budgets.where((b) => b.isExceeded).toList();
    
    return BudgetWarningResponse(
      warningBudgets: warningBudgets,
      exceededBudgets: exceededBudgets,
    );
  }

  /// Sync unsynced budgets to server
  Future<void> syncPendingChanges() async {
    if (!await _networkInfo.checkConnection()) return;
    
    final unsyncedBudgets = await _localDataSource.getUnsyncedBudgets();
    for (final budget in unsyncedBudgets) {
      try {
        if (budget.id.startsWith('offline_')) {
          // New budget created offline
          final request = CreateBudgetRequest(
            amountLimit: budget.amountLimit,
            categoryId: budget.categoryId,
            startDate: budget.startDate,
            endDate: budget.endDate,
            isRecurring: budget.isRecurring,
          );
          final remoteBudget = await _remoteDataSource.createBudget(request);
          // Update local with server ID
          await _localDataSource.deleteBudget(budget.id);
          await _localDataSource.saveBudget(remoteBudget);
          await _localDataSource.markAsSynced(remoteBudget.id);
        } else {
          // Existing budget updated offline
          final request = UpdateBudgetRequest(
            amountLimit: budget.amountLimit,
            categoryId: budget.categoryId,
            startDate: budget.startDate,
            endDate: budget.endDate,
            isRecurring: budget.isRecurring,
          );
          await _remoteDataSource.updateBudget(budget.id, request);
          await _localDataSource.markAsSynced(budget.id);
        }
      } catch (e) {
        // Keep unsynced for retry later
        continue;
      }
    }
  }
}
