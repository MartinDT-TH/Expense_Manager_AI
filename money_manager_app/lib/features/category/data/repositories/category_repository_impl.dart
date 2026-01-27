import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_local_datasource.dart';
import '../datasources/category_remote_datasource.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryLocalDataSource localDataSource;
  final CategoryRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final Uuid _uuid = const Uuid();

  CategoryRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<Category>>> getCategories() async {
    try {
      // When connected, prefer remote to get correct GUIDs
      if (await networkInfo.isConnected) {
        try {
          final remoteCategories = await remoteDataSource.getCategories();
          // Update local with remote data (correct IDs)
          await localDataSource.upsertCategories(remoteCategories);
          return Right(remoteCategories);
        } catch (e) {
          // If remote fails, fallback to local
          final localCategories = await localDataSource.getCategories();
          return Right(localCategories);
        }
      }
      
      // Offline: get from local
      final localCategories = await localDataSource.getCategories();
      return Right(localCategories);
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Category>>> getExpenseCategories() async {
    try {
      // When connected, prefer remote to get correct GUIDs
      if (await networkInfo.isConnected) {
        try {
          final remoteCategories = await remoteDataSource.getCategoriesByType(CategoryType.expense);
          await localDataSource.upsertCategories(remoteCategories);
          return Right(remoteCategories);
        } catch (e) {
          // Fallback to local
          final categories = await localDataSource.getCategoriesByType(CategoryType.expense);
          return Right(categories);
        }
      }
      
      // Offline: get from local
      final categories = await localDataSource.getCategoriesByType(CategoryType.expense);
      return Right(categories);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Category>>> getIncomeCategories() async {
    try {
      // When connected, prefer remote to get correct GUIDs
      if (await networkInfo.isConnected) {
        try {
          final remoteCategories = await remoteDataSource.getCategoriesByType(CategoryType.income);
          await localDataSource.upsertCategories(remoteCategories);
          return Right(remoteCategories);
        } catch (e) {
          // Fallback to local
          final categories = await localDataSource.getCategoriesByType(CategoryType.income);
          return Right(categories);
        }
      }
      
      // Offline: get from local
      final categories = await localDataSource.getCategoriesByType(CategoryType.income);
      return Right(categories);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Category>> getCategoryById(String id) async {
    try {
      final category = await localDataSource.getCategoryById(id);
      if (category == null) {
        return const Left(NotFoundFailure(message: 'Category not found'));
      }
      return Right(category);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Category>> createCategory(Category category) async {
    try {
      final now = DateTime.now();
      final newCategory = CategoryModel(
        id: category.id.isEmpty ? _uuid.v4() : category.id,
        name: category.name,
        iconCode: category.iconCode,
        type: category.type,
        isSystem: false,
        userId: category.userId,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );

      // Save to local first
      await localDataSource.insertCategory(newCategory);

      // Try to sync to server
      if (await networkInfo.isConnected) {
        try {
          final remoteCategory = await remoteDataSource.createCategory(newCategory);
          await localDataSource.markAsSynced(remoteCategory.id);
          return Right(remoteCategory);
        } catch (_) {
          // Ignore remote errors, data is saved locally
        }
      }

      return Right(newCategory);
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Category>> updateCategory(Category category) async {
    try {
      // Check if system category
      final existing = await localDataSource.getCategoryById(category.id);
      if (existing != null && existing.isSystem) {
        return const Left(ValidationFailure(message: 'Cannot modify system category'));
      }

      final updatedCategory = CategoryModel.fromEntity(
        category.copyWith(updatedAt: DateTime.now()),
      );

      // Update locally first
      await localDataSource.updateCategory(updatedCategory);

      // Try to sync to server
      if (await networkInfo.isConnected) {
        try {
          final remoteCategory = await remoteDataSource.updateCategory(updatedCategory);
          await localDataSource.markAsSynced(remoteCategory.id);
          return Right(remoteCategory);
        } catch (_) {
          // Ignore remote errors
        }
      }

      return Right(updatedCategory);
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      // Check if system category
      final existing = await localDataSource.getCategoryById(id);
      if (existing != null && existing.isSystem) {
        return const Left(ValidationFailure(message: 'Cannot delete system category'));
      }

      // Soft delete locally
      await localDataSource.deleteCategory(id);

      // Try to sync to server
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.deleteCategory(id);
          await localDataSource.markAsSynced(id);
        } catch (_) {
          // Ignore remote errors
        }
      }

      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncCategories() async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure());
      }

      // Push unsynced categories
      final unsyncedCategories = await localDataSource.getUnsyncedCategories();
      for (final category in unsyncedCategories) {
        try {
          if (category.isDeleted) {
            await remoteDataSource.deleteCategory(category.id);
          } else {
            await remoteDataSource.createCategory(category);
          }
          await localDataSource.markAsSynced(category.id);
        } catch (_) {
          // Continue with next category
        }
      }

      // Pull from server
      final remoteCategories = await remoteDataSource.getCategories();
      await localDataSource.upsertCategories(remoteCategories);

      return const Right(null);
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Future<void> _syncInBackground() async {
    try {
      await syncCategories();
    } catch (_) {
      // Ignore background sync errors
    }
  }
}
