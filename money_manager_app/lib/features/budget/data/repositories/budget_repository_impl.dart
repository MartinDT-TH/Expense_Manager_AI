import '../../data/datasources/budget_datasource.dart';
import '../../data/models/budget_model.dart';
import '../../domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetRemoteDataSource _remoteDataSource;

  BudgetRepositoryImpl({required BudgetRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<BudgetModel>> getBudgets() {
    return _remoteDataSource.getBudgets();
  }

  @override
  Future<List<BudgetModel>> getActiveBudgets() {
    return _remoteDataSource.getActiveBudgets();
  }

  @override
  Future<BudgetModel?> getCurrentMonthBudget() {
    return _remoteDataSource.getCurrentMonthBudget();
  }

  @override
  Future<BudgetModel?> getBudgetById(String id) {
    return _remoteDataSource.getBudgetById(id);
  }

  @override
  Future<BudgetModel> createBudget(CreateBudgetRequest request) {
    return _remoteDataSource.createBudget(request);
  }

  @override
  Future<BudgetModel> updateBudget(String id, UpdateBudgetRequest request) {
    return _remoteDataSource.updateBudget(id, request);
  }

  @override
  Future<bool> deleteBudget(String id) {
    return _remoteDataSource.deleteBudget(id);
  }

  @override
  Future<BudgetWarningResponse> getBudgetWarnings() {
    return _remoteDataSource.getBudgetWarnings();
  }
}
