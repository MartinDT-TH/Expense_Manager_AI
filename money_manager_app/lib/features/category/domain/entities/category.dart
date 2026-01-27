import 'package:equatable/equatable.dart';

enum CategoryType { income, expense }

class Category extends Equatable {
  final String id;
  final String name;
  final String iconCode;
  final CategoryType type;
  final bool isSystem; // System categories cannot be edited/deleted
  final String? userId; // null for system categories
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const Category({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.type,
    this.isSystem = false,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Category copyWith({
    String? id,
    String? name,
    String? iconCode,
    CategoryType? type,
    bool? isSystem,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      type: type ?? this.type,
      isSystem: isSystem ?? this.isSystem,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        iconCode,
        type,
        isSystem,
        userId,
        createdAt,
        updatedAt,
        isDeleted,
      ];
}
