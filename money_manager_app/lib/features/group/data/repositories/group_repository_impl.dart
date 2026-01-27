import '../../../../core/network/network_info.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/repositories/group_repository.dart';
import '../../../transaction/domain/entities/transaction.dart';
import '../datasources/group_remote_datasource.dart';
import '../datasources/group_local_datasource.dart';

/// Implementation của GroupRepository
/// Sử dụng pattern offline-first: đọc từ local trước, sync với server khi có mạng
class GroupRepositoryImpl implements GroupRepository {
  final GroupRemoteDataSource remoteDataSource;
  final GroupLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  GroupRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<List<Group>> getGroups() async {
    if (await networkInfo.isConnected) {
      try {
        final remoteGroups = await remoteDataSource.getGroups();
        await localDataSource.saveGroups(remoteGroups);
        return remoteGroups;
      } catch (e) {
        // Fallback to local if network fails
        return await localDataSource.getGroups();
      }
    } else {
      return await localDataSource.getGroups();
    }
  }

  @override
  Future<Group?> getGroupById(String id) async {
    if (await networkInfo.isConnected) {
      try {
        final remoteGroup = await remoteDataSource.getGroupById(id);
        if (remoteGroup != null) {
          await localDataSource.saveGroup(remoteGroup);
        }
        return remoteGroup;
      } catch (e) {
        return await localDataSource.getGroupById(id);
      }
    } else {
      return await localDataSource.getGroupById(id);
    }
  }

  @override
  Future<Group> createGroup({
    required String name,
    String? description,
  }) async {
    final group = await remoteDataSource.createGroup(
      name: name,
      description: description,
    );
    await localDataSource.saveGroup(group);
    return group;
  }

  @override
  Future<Group> updateGroup({
    required String id,
    String? name,
    String? description,
  }) async {
    final group = await remoteDataSource.updateGroup(
      id: id,
      name: name,
      description: description,
    );
    await localDataSource.saveGroup(group);
    return group;
  }

  @override
  Future<bool> deleteGroup(String id) async {
    final result = await remoteDataSource.deleteGroup(id);
    if (result) {
      await localDataSource.deleteGroup(id);
    }
    return result;
  }

  @override
  Future<Group> joinGroup(String inviteCode) async {
    final group = await remoteDataSource.joinGroup(inviteCode);
    await localDataSource.saveGroup(group);
    return group;
  }

  @override
  Future<bool> leaveGroup(String groupId) async {
    final result = await remoteDataSource.leaveGroup(groupId);
    if (result) {
      await localDataSource.deleteGroup(groupId);
    }
    return result;
  }

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    if (await networkInfo.isConnected) {
      try {
        final remoteMembers = await remoteDataSource.getGroupMembers(groupId);
        await localDataSource.saveGroupMembers(remoteMembers);
        return remoteMembers;
      } catch (e) {
        return await localDataSource.getGroupMembers(groupId);
      }
    } else {
      return await localDataSource.getGroupMembers(groupId);
    }
  }

  @override
  Future<bool> kickMember(String groupId, String userId) async {
    final result = await remoteDataSource.kickMember(groupId, userId);
    if (result) {
      await localDataSource.deleteGroupMember('${userId}_$groupId');
    }
    return result;
  }

  @override
  Future<bool> changeRole(String groupId, String userId, String newRole) async {
    return await remoteDataSource.changeRole(groupId, userId, newRole);
  }

  @override
  Future<String> regenerateInviteCode(String groupId) async {
    return await remoteDataSource.regenerateInviteCode(groupId);
  }

  @override
  Future<List<Transaction>> getGroupTransactions(String groupId) async {
    final transactions = await remoteDataSource.getGroupTransactions(groupId);
    return transactions;
  }
}
