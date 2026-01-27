import 'package:equatable/equatable.dart';
import '../../domain/entities/category.dart';

abstract class CategoryState extends Equatable {
  const CategoryState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class CategoryInitial extends CategoryState {
  const CategoryInitial();
}

/// Loading categories
class CategoryLoading extends CategoryState {
  const CategoryLoading();
}

/// Categories loaded successfully
class CategoryLoaded extends CategoryState {
  final List<Category> categories;
  final List<Category> incomeCategories;
  final List<Category> expenseCategories;

  const CategoryLoaded({
    required this.categories,
    required this.incomeCategories,
    required this.expenseCategories,
  });

  @override
  List<Object?> get props => [categories, incomeCategories, expenseCategories];
}

/// Category operation success (create/update/delete)
class CategoryOperationSuccess extends CategoryState {
  final String message;
  final Category? category;

  const CategoryOperationSuccess({
    required this.message,
    this.category,
  });

  @override
  List<Object?> get props => [message, category];
}

/// Error state
class CategoryError extends CategoryState {
  final String message;

  const CategoryError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Syncing categories
class CategorySyncing extends CategoryState {
  const CategorySyncing();
}

/// Sync completed
class CategorySyncComplete extends CategoryState {
  final bool success;
  final String? message;

  const CategorySyncComplete({
    required this.success,
    this.message,
  });

  @override
  List<Object?> get props => [success, message];
}
