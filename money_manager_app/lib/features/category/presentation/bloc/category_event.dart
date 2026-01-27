import 'package:equatable/equatable.dart';
import '../../domain/entities/category.dart';

abstract class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => [];
}

/// Load all categories
class LoadCategories extends CategoryEvent {
  const LoadCategories();
}

/// Load categories by type (income/expense)
class LoadCategoriesByType extends CategoryEvent {
  final CategoryType type;

  const LoadCategoriesByType(this.type);

  @override
  List<Object?> get props => [type];
}

/// Create new category
class CreateCategory extends CategoryEvent {
  final String name;
  final String iconCode;
  final CategoryType type;

  const CreateCategory({
    required this.name,
    required this.iconCode,
    required this.type,
  });

  @override
  List<Object?> get props => [name, iconCode, type];
}

/// Update category
class UpdateCategory extends CategoryEvent {
  final Category category;

  const UpdateCategory(this.category);

  @override
  List<Object?> get props => [category];
}

/// Delete category
class DeleteCategory extends CategoryEvent {
  final String id;

  const DeleteCategory(this.id);

  @override
  List<Object?> get props => [id];
}

/// Sync categories with server
class SyncCategories extends CategoryEvent {
  const SyncCategories();
}
