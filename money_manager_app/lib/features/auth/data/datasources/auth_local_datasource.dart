import 'package:sqflite/sqflite.dart';
import '../../../../core/database/local_database.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> deleteUser();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final LocalDatabase database;

  AuthLocalDataSourceImpl({required this.database});

  @override
  Future<void> saveUser(UserModel user) async {
    final db = await database.database;
    await db.insert(
      'user',
      user.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<UserModel?> getUser() async {
    final db = await database.database;
    final results = await db.query('user', limit: 1);
    if (results.isNotEmpty) {
      return UserModel.fromDatabase(results.first);
    }
    return null;
  }

  @override
  Future<void> deleteUser() async {
    final db = await database.database;
    await db.delete('user');
  }
}
