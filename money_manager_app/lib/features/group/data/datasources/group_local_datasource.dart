import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';

/// Interface cho Group Local DataSource (SQLite)
abstract class GroupLocalDataSource {
  Future<List<GroupModel>> getGroups();
  Future<GroupModel?> getGroupById(String id);
  Future<void> saveGroup(GroupModel group);
  Future<void> saveGroups(List<GroupModel> groups);
  Future<void> deleteGroup(String id);
  Future<List<GroupMemberModel>> getGroupMembers(String groupId);
  Future<void> saveGroupMember(GroupMemberModel member);
  Future<void> saveGroupMembers(List<GroupMemberModel> members);
  Future<void> deleteGroupMember(String id);
  Future<void> clearAllGroups();
}

/// Implementation của Group Local DataSource
class GroupLocalDataSourceImpl implements GroupLocalDataSource {
  final LocalDatabase database;

  GroupLocalDataSourceImpl({required this.database});

  @override
  Future<List<GroupModel>> getGroups() async {
    final db = await database.database;
    final result = await db.query(
      'groups',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'last_updated_at DESC',
    );
    return result.map((map) => GroupModel.fromDatabase(map)).toList();
  }

  @override
  Future<GroupModel?> getGroupById(String id) async {
    final db = await database.database;
    final result = await db.query(
      'groups',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (result.isEmpty) return null;
    return GroupModel.fromDatabase(result.first);
  }

  @override
  Future<void> saveGroup(GroupModel group) async {
    final db = await database.database;
    await db.insert(
      'groups',
      group.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveGroups(List<GroupModel> groups) async {
    final db = await database.database;
    final batch = db.batch();
    for (final group in groups) {
      batch.insert(
        'groups',
        group.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteGroup(String id) async {
    final db = await database.database;
    await db.update(
      'groups',
      {'is_deleted': 1, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    final db = await database.database;
    final result = await db.query(
      'group_members',
      where: 'group_id = ? AND is_deleted = ?',
      whereArgs: [groupId, 0],
      orderBy: 'role ASC, joined_at ASC', // Admin trước, Member sau
    );
    return result.map((map) => GroupMemberModel.fromDatabase(map)).toList();
  }

  @override
  Future<void> saveGroupMember(GroupMemberModel member) async {
    final db = await database.database;
    await db.insert(
      'group_members',
      member.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveGroupMembers(List<GroupMemberModel> members) async {
    final db = await database.database;
    final batch = db.batch();
    for (final member in members) {
      batch.insert(
        'group_members',
        member.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteGroupMember(String id) async {
    final db = await database.database;
    await db.update(
      'group_members',
      {'is_deleted': 1, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clearAllGroups() async {
    final db = await database.database;
    await db.delete('group_members');
    await db.delete('groups');
  }
}
