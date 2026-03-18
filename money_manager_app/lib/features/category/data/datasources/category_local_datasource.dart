import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../models/category_model.dart';
import '../../domain/entities/category.dart';

abstract class CategoryLocalDataSource {
  Future<List<CategoryModel>> getCategories();
  Future<List<CategoryModel>> getCategoriesByType(CategoryType type);
  Future<CategoryModel?> getCategoryById(String id);
  Future<void> insertCategory(CategoryModel category);
  Future<void> updateCategory(CategoryModel category);
  Future<void> deleteCategory(String id);
  Future<List<CategoryModel>> getUnsyncedCategories();
  Future<void> markAsSynced(String id);
  Future<void> upsertCategories(List<CategoryModel> categories);
}

class CategoryLocalDataSourceImpl implements CategoryLocalDataSource {
  final LocalDatabase database;

  CategoryLocalDataSourceImpl({required this.database});

  @override
  Future<List<CategoryModel>> getCategories() async {
    final db = await database.database;
    final result = await db.query(
      'categories',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'is_system DESC, name ASC',
    );
    return result.map((map) => CategoryModel.fromLocalDb(map)).toList();
  }

  @override
  Future<List<CategoryModel>> getCategoriesByType(CategoryType type) async {
    final db = await database.database;
    final typeStr = type == CategoryType.income ? 'INCOME' : 'EXPENSE';
    final result = await db.query(
      'categories',
      where: 'type = ? AND is_deleted = ?',
      whereArgs: [typeStr, 0],
      orderBy: 'is_system DESC, name ASC',
    );
    return result.map((map) => CategoryModel.fromLocalDb(map)).toList();
  }

  @override
  Future<CategoryModel?> getCategoryById(String id) async {
    final db = await database.database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return CategoryModel.fromLocalDb(result.first);
  }

  @override
  Future<void> insertCategory(CategoryModel category) async {
    final db = await database.database;
    await db.insert('categories', category.toLocalDb());
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    final db = await database.database;
    final data = category.toLocalDb();
    data['is_synced'] = 0; // Mark as unsynced after update
    await db.update(
      'categories',
      data,
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    final db = await database.database;
    await db.update(
      'categories',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<CategoryModel>> getUnsyncedCategories() async {
    final db = await database.database;
    final result = await db.query(
      'categories',
      where: 'is_synced = ? AND is_system = ?',
      whereArgs: [0, 0], // Only sync user categories
    );
    return result.map((map) => CategoryModel.fromLocalDb(map)).toList();
  }

  @override
  Future<void> markAsSynced(String id) async {
    final db = await database.database;
    await db.update(
      'categories',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> upsertCategories(List<CategoryModel> categories) async {
    final db = await database.database;

    // Merge: không xóa toàn bộ — giữ bản ghi local chưa sync (is_synced=0)
    final serverIds = categories.map((c) => c.id).toList();

    final batch = db.batch();
    for (final category in categories) {
      final data = category.toLocalDb();
      data['is_synced'] = 1; // Dữ liệu từ server = đã sync
      batch.insert(
        'categories',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    // Xóa bản ghi đã sync nhưng không còn trong response (bị xóa ở thiết bị khác)
    // Không xóa bản ghi is_synced=0 (user category chưa sync)
    if (serverIds.isNotEmpty) {
      final placeholders = List.filled(serverIds.length, '?').join(',');
      await db.delete(
        'categories',
        where: 'is_synced = 1 AND id NOT IN ($placeholders)',
        whereArgs: serverIds,
      );
    }
  }
}
