import '../../data/models/budget_model.dart';

abstract class BudgetRepository {
  Future<List<BudgetModel>> getBudgets();
  Future<List<BudgetModel>> getActiveBudgets();
  Future<BudgetModel?> getCurrentMonthBudget();
  Future<BudgetModel?> getBudgetById(String id);
  Future<BudgetModel> createBudget(CreateBudgetRequest request);
  Future<BudgetModel> updateBudget(String id, UpdateBudgetRequest request);
  Future<bool> deleteBudget(String id);
  Future<BudgetWarningResponse> getBudgetWarnings();
}
