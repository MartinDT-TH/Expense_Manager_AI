import '../entities/group.dart';
import '../entities/group_member.dart';
import '../../../transaction/domain/entities/transaction.dart';

/// Repository interface cho Group Feature
abstract class GroupRepository {
  /// Lấy danh sách các nhóm mà user tham gia
  Future<List<Group>> getGroups();

  /// Lấy chi tiết một nhóm theo ID
  Future<Group?> getGroupById(String id);

  /// Tạo nhóm mới (Premium only)
  Future<Group> createGroup({
    required String name,
    String? description,
  });

  /// Cập nhật thông tin nhóm (Admin only)
  Future<Group> updateGroup({
    required String id,
    String? name,
    String? description,
  });

  /// Xóa nhóm (Creator only)
  Future<bool> deleteGroup(String id);

  /// Tham gia nhóm bằng mã mời
  Future<Group> joinGroup(String inviteCode);

  /// Rời khỏi nhóm
  Future<bool> leaveGroup(String groupId);

  /// Lấy danh sách thành viên của nhóm
  Future<List<GroupMember>> getGroupMembers(String groupId);

  /// Kick thành viên khỏi nhóm (Admin only)
  Future<bool> kickMember(String groupId, String userId);

  /// Thay đổi vai trò thành viên (Admin only)
  Future<bool> changeRole(String groupId, String userId, String newRole);

  /// Tạo mã mời mới (Admin only)
  Future<String> regenerateInviteCode(String groupId);

  /// Lấy danh sách giao dịch của nhóm
  Future<List<Transaction>> getGroupTransactions(String groupId);
}
