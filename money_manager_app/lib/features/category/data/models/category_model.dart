import '../../domain/entities/category.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.iconCode,
    required super.type,
    super.isSystem = false,
    super.userId,
    required super.createdAt,
    required super.updatedAt,
    super.isDeleted = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCode: (json['iconCode'] as String?) ?? 'category',
      type: (json['type'] as String).toLowerCase() == 'income'
          ? CategoryType.income
          : CategoryType.expense,
      isSystem: json['isSystemCategory'] as bool? ?? false,
      userId: json['ownerId'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['lastUpdatedAt'] != null
          ? DateTime.parse(json['lastUpdatedAt'] as String)
          : DateTime.now(),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'type': type == CategoryType.income ? 'INCOME' : 'EXPENSE',
      'isSystem': isSystem,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory CategoryModel.fromEntity(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      iconCode: category.iconCode,
      type: category.type,
      isSystem: category.isSystem,
      userId: category.userId,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
      isDeleted: category.isDeleted,
    );
  }

  factory CategoryModel.fromLocalDb(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      iconCode: map['icon_code'] as String,
      type: (map['type'] as String).toLowerCase() == 'income'
          ? CategoryType.income
          : CategoryType.expense,
      isSystem: (map['is_system'] as int) == 1,
      userId: map['user_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int) == 1,
    );
  }

  Map<String, dynamic> toLocalDb() {
    return {
      'id': id,
      'name': name,
      'icon_code': iconCode,
      'type': type == CategoryType.income ? 'INCOME' : 'EXPENSE',
      'is_system': isSystem ? 1 : 0,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': 0,
    };
  }
}
