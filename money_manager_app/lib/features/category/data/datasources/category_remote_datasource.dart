import '../../../../core/network/api_client.dart';
import '../models/category_model.dart';
import '../../domain/entities/category.dart';

abstract class CategoryRemoteDataSource {
  Future<List<CategoryModel>> getCategories();
  Future<List<CategoryModel>> getCategoriesByType(CategoryType type);
  Future<List<CategoryModel>> getSystemCategories();
  Future<CategoryModel> getCategoryById(String id);
  Future<CategoryModel> createCategory(CategoryModel category);
  Future<CategoryModel> updateCategory(CategoryModel category);
  Future<void> deleteCategory(String id);
}

class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final ApiClient apiClient;

  CategoryRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<CategoryModel>> getCategories() async {
    // Use authenticated endpoint to get System + User's custom categories
    try {
      final response = await apiClient.get('/Category');
      final List<dynamic> data = response.data;
      return data.map((json) => CategoryModel.fromJson(json)).toList();
    } catch (e) {
      // Fallback to system categories if not authenticated
      return getSystemCategories();
    }
  }

  @override
  Future<List<CategoryModel>> getCategoriesByType(CategoryType type) async {
    // Use authenticated endpoint for user's categories
    try {
      final endpoint = type == CategoryType.income
          ? '/Category/income'
          : '/Category/expense';
      final response = await apiClient.get(endpoint);
      final List<dynamic> data = response.data;
      return data.map((json) => CategoryModel.fromJson(json)).toList();
    } catch (e) {
      // Fallback to system categories if not authenticated
      final endpoint = type == CategoryType.income
          ? '/Category/system/income'
          : '/Category/system/expense';
      final response = await apiClient.get(endpoint);
      final List<dynamic> data = response.data;
      return data.map((json) => CategoryModel.fromJson(json)).toList();
    }
  }

  @override
  Future<List<CategoryModel>> getSystemCategories() async {
    // Public endpoint - no auth required
    final response = await apiClient.get('/Category/system');
    final List<dynamic> data = response.data;
    return data.map((json) => CategoryModel.fromJson(json)).toList();
  }

  @override
  Future<CategoryModel> getCategoryById(String id) async {
    final response = await apiClient.get('/Category/$id');
    return CategoryModel.fromJson(response.data);
  }

  @override
  Future<CategoryModel> createCategory(CategoryModel category) async {
    final response = await apiClient.post(
      '/Category',
      data: {
        'id': category.id,
        'name': category.name,
        'iconCode': category.iconCode,
        'type': category.type == CategoryType.income ? 'INCOME' : 'EXPENSE',
      },
    );
    return CategoryModel.fromJson(response.data);
  }

  @override
  Future<CategoryModel> updateCategory(CategoryModel category) async {
    final response = await apiClient.put(
      '/Category/${category.id}',
      data: {
        'name': category.name,
        'iconCode': category.iconCode,
      },
    );
    return CategoryModel.fromJson(response.data);
  }

  @override
  Future<void> deleteCategory(String id) async {
    await apiClient.delete('/Category/$id');
  }
}
