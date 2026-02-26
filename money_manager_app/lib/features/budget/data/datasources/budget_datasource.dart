import '../models/budget_model.dart';
import '../models/budget_analytics_models.dart';

abstract class BudgetRemoteDataSource {
  Future<List<BudgetModel>> getBudgets();
  Future<List<BudgetModel>> getActiveBudgets();
  Future<BudgetModel?> getCurrentMonthBudget();
  Future<BudgetModel?> getBudgetById(String id);
  Future<BudgetModel> createBudget(CreateBudgetRequest request);
  Future<BudgetModel> updateBudget(String id, UpdateBudgetRequest request);
  Future<bool> deleteBudget(String id);
  Future<BudgetWarningResponse> getBudgetWarnings();
  
  // Analytics endpoints
  Future<BudgetHistoryResponse> getBudgetHistory({int months = 6});
  Future<BudgetAnalyticsResponse> getBudgetAnalytics();
  Future<List<BudgetSuggestion>> getBudgetSuggestions();
}
