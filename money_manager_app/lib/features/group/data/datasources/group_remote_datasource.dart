import '../../../../core/network/api_client.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../../../transaction/data/models/transaction_model.dart';

/// Interface cho Group Remote DataSource
abstract class GroupRemoteDataSource {
  Future<List<GroupModel>> getGroups();
  Future<GroupModel?> getGroupById(String id);
  Future<GroupModel> createGroup({required String name, String? description});
  Future<GroupModel> updateGroup({required String id, String? name, String? description});
  Future<bool> deleteGroup(String id);
  Future<GroupModel> joinGroup(String inviteCode);
  Future<bool> leaveGroup(String groupId);
  Future<List<GroupMemberModel>> getGroupMembers(String groupId);
  Future<bool> kickMember(String groupId, String userId);
  Future<bool> changeRole(String groupId, String userId, String newRole);
  Future<String> regenerateInviteCode(String groupId);
  Future<List<TransactionModel>> getGroupTransactions(String groupId);
}

/// Implementation của Group Remote DataSource
class GroupRemoteDataSourceImpl implements GroupRemoteDataSource {
  final ApiClient apiClient;

  GroupRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<GroupModel>> getGroups() async {
    final response = await apiClient.get('/Group');
    final List<dynamic> data = response.data ?? [];
    return data.map((json) => GroupModel.fromJson(json)).toList();
  }

  @override
  Future<GroupModel?> getGroupById(String id) async {
    try {
      final response = await apiClient.get('/Group/$id');
      return GroupModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<GroupModel> createGroup({required String name, String? description}) async {
    final response = await apiClient.post(
      '/Group',
      data: {
        'name': name,
        'description': description,
      },
    );
    return GroupModel.fromJson(response.data);
  }

  @override
  Future<GroupModel> updateGroup({
    required String id,
    String? name,
    String? description,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;

    final response = await apiClient.put('/Group/$id', data: data);
    return GroupModel.fromJson(response.data);
  }

  @override
  Future<bool> deleteGroup(String id) async {
    await apiClient.delete('/Group/$id');
    return true;
  }

  @override
  Future<GroupModel> joinGroup(String inviteCode) async {
    final response = await apiClient.post(
      '/Group/join',
      data: {'inviteCode': inviteCode},
    );
    return GroupModel.fromJson(response.data);
  }

  @override
  Future<bool> leaveGroup(String groupId) async {
    await apiClient.delete('/Group/$groupId/leave');
    return true;
  }

  @override
  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    final response = await apiClient.get('/Group/$groupId/members');
    final List<dynamic> data = response.data ?? [];
    return data.map((json) => GroupMemberModel.fromJson(json, groupId: groupId)).toList();
  }

  @override
  Future<bool> kickMember(String groupId, String userId) async {
    await apiClient.delete('/Group/$groupId/members/$userId');
    return true;
  }

  @override
  Future<bool> changeRole(String groupId, String userId, String newRole) async {
    await apiClient.put(
      '/Group/$groupId/members/$userId/role',
      data: {'role': newRole},
    );
    return true;
  }

  @override
  Future<String> regenerateInviteCode(String groupId) async {
    final response = await apiClient.post('/Group/$groupId/regenerate-invite');
    return response.data['inviteCode'] ?? '';
  }

  @override
  Future<List<TransactionModel>> getGroupTransactions(String groupId) async {
    final response = await apiClient.get('/Transaction', queryParameters: {
      'groupId': groupId,
    });
    
    // Handle paginated response
    if (response.data is Map && response.data['items'] != null) {
      final List<dynamic> items = response.data['items'];
      return items.map((json) => TransactionModel.fromJson(json)).toList();
    }
    
    // Handle direct list response
    final List<dynamic> data = response.data ?? [];
    return data.map((json) => TransactionModel.fromJson(json)).toList();
  }
}
