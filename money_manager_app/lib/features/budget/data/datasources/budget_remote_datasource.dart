import '../../../../core/network/api_client.dart';
import '../models/budget_model.dart';
import 'budget_datasource.dart';

class BudgetRemoteDataSourceImpl implements BudgetRemoteDataSource {
  final ApiClient _apiClient;

  BudgetRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<BudgetModel>> getBudgets() async {
    final response = await _apiClient.get('/Budget');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => BudgetModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<BudgetModel>> getActiveBudgets() async {
    final response = await _apiClient.get('/Budget/active');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => BudgetModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<BudgetModel?> getCurrentMonthBudget() async {
    try {
      final response = await _apiClient.get('/Budget/current-month');
      // Check if response has 'hasBudget: false'
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['hasbudget'] == false) {
          return null;
        }
        return BudgetModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<BudgetModel?> getBudgetById(String id) async {
    try {
      final response = await _apiClient.get('/Budget/$id');
      return BudgetModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<BudgetModel> createBudget(CreateBudgetRequest request) async {
    final response = await _apiClient.post('/Budget', data: request.toJson());
    return BudgetModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<BudgetModel> updateBudget(String id, UpdateBudgetRequest request) async {
    final response = await _apiClient.put('/Budget/$id', data: request.toJson());
    return BudgetModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<bool> deleteBudget(String id) async {
    await _apiClient.delete('/Budget/$id');
    return true;
  }

  @override
  Future<BudgetWarningResponse> getBudgetWarnings() async {
    final response = await _apiClient.get('/Budget/warnings');
    return BudgetWarningResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
