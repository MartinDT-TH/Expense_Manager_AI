import 'package:equatable/equatable.dart';

/// Base class cho tất cả GroupEvent
abstract class GroupEvent extends Equatable {
  const GroupEvent();

  @override
  List<Object?> get props => [];
}

/// Load danh sách groups
class LoadGroups extends GroupEvent {
  const LoadGroups();
}

/// Refresh danh sách groups
class RefreshGroups extends GroupEvent {
  const RefreshGroups();
}

/// Load chi tiết 1 group
class LoadGroupDetail extends GroupEvent {
  final String groupId;

  const LoadGroupDetail(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

/// Tạo group mới
class CreateGroup extends GroupEvent {
  final String name;
  final String? description;

  const CreateGroup({required this.name, this.description});

  @override
  List<Object?> get props => [name, description];
}

/// Cập nhật group
class UpdateGroup extends GroupEvent {
  final String id;
  final String? name;
  final String? description;

  const UpdateGroup({required this.id, this.name, this.description});

  @override
  List<Object?> get props => [id, name, description];
}

/// Xóa group
class DeleteGroup extends GroupEvent {
  final String id;

  const DeleteGroup(this.id);

  @override
  List<Object?> get props => [id];
}

/// Tham gia group bằng invite code
class JoinGroup extends GroupEvent {
  final String inviteCode;

  const JoinGroup(this.inviteCode);

  @override
  List<Object?> get props => [inviteCode];
}

/// Rời khỏi group
class LeaveGroup extends GroupEvent {
  final String groupId;

  const LeaveGroup(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

/// Load danh sách thành viên của group
class LoadGroupMembers extends GroupEvent {
  final String groupId;

  const LoadGroupMembers(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

/// Kick thành viên khỏi group
class KickMember extends GroupEvent {
  final String groupId;
  final String userId;

  const KickMember({required this.groupId, required this.userId});

  @override
  List<Object?> get props => [groupId, userId];
}

/// Thay đổi role của thành viên
class ChangeRole extends GroupEvent {
  final String groupId;
  final String userId;
  final String newRole;

  const ChangeRole({
    required this.groupId,
    required this.userId,
    required this.newRole,
  });

  @override
  List<Object?> get props => [groupId, userId, newRole];
}

/// Tạo mã mời mới
class RegenerateInviteCode extends GroupEvent {
  final String groupId;

  const RegenerateInviteCode(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

/// Load giao dịch của group
class LoadGroupTransactions extends GroupEvent {
  final String groupId;

  const LoadGroupTransactions(this.groupId);

  @override
  List<Object?> get props => [groupId];
}

/// Clear group detail state
class ClearGroupDetail extends GroupEvent {
  const ClearGroupDetail();
}
