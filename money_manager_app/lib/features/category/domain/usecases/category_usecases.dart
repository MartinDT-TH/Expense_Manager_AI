import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';

// Get all categories
class GetCategoriesUseCase {
  final CategoryRepository repository;

  GetCategoriesUseCase(this.repository);

  Future<Either<Failure, List<Category>>> call() {
    return repository.getCategories();
  }
}

// Get expense categories only
class GetExpenseCategoriesUseCase {
  final CategoryRepository repository;

  GetExpenseCategoriesUseCase(this.repository);

  Future<Either<Failure, List<Category>>> call() {
    return repository.getExpenseCategories();
  }
}

// Get income categories only
class GetIncomeCategoriesUseCase {
  final CategoryRepository repository;

  GetIncomeCategoriesUseCase(this.repository);

  Future<Either<Failure, List<Category>>> call() {
    return repository.getIncomeCategories();
  }
}

// Get category by ID
class GetCategoryByIdUseCase {
  final CategoryRepository repository;

  GetCategoryByIdUseCase(this.repository);

  Future<Either<Failure, Category>> call(String id) {
    return repository.getCategoryById(id);
  }
}

// Create category
class CreateCategoryUseCase {
  final CategoryRepository repository;

  CreateCategoryUseCase(this.repository);

  Future<Either<Failure, Category>> call(Category category) {
    return repository.createCategory(category);
  }
}

// Update category
class UpdateCategoryUseCase {
  final CategoryRepository repository;

  UpdateCategoryUseCase(this.repository);

  Future<Either<Failure, Category>> call(Category category) {
    return repository.updateCategory(category);
  }
}

// Delete category
class DeleteCategoryUseCase {
  final CategoryRepository repository;

  DeleteCategoryUseCase(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteCategory(id);
  }
}
