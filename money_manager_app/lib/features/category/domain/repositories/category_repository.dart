import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';

abstract class CategoryRepository {
  /// Get all categories (system + user's custom)
  Future<Either<Failure, List<Category>>> getCategories();
  
  /// Get only expense categories
  Future<Either<Failure, List<Category>>> getExpenseCategories();
  
  /// Get only income categories
  Future<Either<Failure, List<Category>>> getIncomeCategories();
  
  /// Get category by ID
  Future<Either<Failure, Category>> getCategoryById(String id);
  
  /// Create custom category
  Future<Either<Failure, Category>> createCategory(Category category);
  
  /// Update category (only user's custom categories)
  Future<Either<Failure, Category>> updateCategory(Category category);
  
  /// Delete category (soft delete, only user's custom)
  Future<Either<Failure, void>> deleteCategory(String id);
  
  /// Sync categories with server
  Future<Either<Failure, void>> syncCategories();
}
