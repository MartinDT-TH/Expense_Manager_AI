import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../models/notification_model.dart';

abstract class NotificationLocalDataSource {
  Future<List<NotificationModel>> getNotifications({int? limit, int? offset});
  Future<int> getUnreadCount();
  Future<void> saveNotification(NotificationModel notification);
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String id);
  Future<void> clearOldNotifications({int keepDays = 30});
}

class NotificationLocalDataSourceImpl implements NotificationLocalDataSource {
  final LocalDatabase database;

  NotificationLocalDataSourceImpl({required this.database});

  @override
  Future<List<NotificationModel>> getNotifications({int? limit, int? offset}) async {
    final db = await database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => NotificationModel.fromMap(map)).toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final db = await database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE is_read = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> saveNotification(NotificationModel notification) async {
    final db = await database.database;
    await db.insert(
      'notifications',
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    final db = await database.database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markAllAsRead() async {
    final db = await database.database;
    await db.update('notifications', {'is_read': 1});
  }

  @override
  Future<void> deleteNotification(String id) async {
    final db = await database.database;
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clearOldNotifications({int keepDays = 30}) async {
    final db = await database.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    await db.delete(
      'notifications',
      where: 'created_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }
}
