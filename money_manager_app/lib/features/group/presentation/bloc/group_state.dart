import 'package:equatable/equatable.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../../transaction/domain/entities/transaction.dart';

/// Base class cho tất cả GroupState
abstract class GroupState extends Equatable {
  const GroupState();

  @override
  List<Object?> get props => [];
}

/// State ban đầu
class GroupInitial extends GroupState {
  const GroupInitial();
}

/// Đang loading
class GroupLoading extends GroupState {
  const GroupLoading();
}

/// Load danh sách groups thành công
class GroupsLoaded extends GroupState {
  final List<Group> groups;

  const GroupsLoaded(this.groups);

  @override
  List<Object?> get props => [groups];
}

/// Load chi tiết group thành công
class GroupDetailLoaded extends GroupState {
  final Group group;
  final List<GroupMember> members;
  final List<Transaction> transactions;

  const GroupDetailLoaded({
    required this.group,
    this.members = const [],
    this.transactions = const [],
  });

  GroupDetailLoaded copyWith({
    Group? group,
    List<GroupMember>? members,
    List<Transaction>? transactions,
  }) {
    return GroupDetailLoaded(
      group: group ?? this.group,
      members: members ?? this.members,
      transactions: transactions ?? this.transactions,
    );
  }

  @override
  List<Object?> get props => [group, members, transactions];
}

/// Tạo group thành công
class GroupCreated extends GroupState {
  final Group group;

  const GroupCreated(this.group);

  @override
  List<Object?> get props => [group];
}

/// Cập nhật group thành công
class GroupUpdated extends GroupState {
  final Group group;

  const GroupUpdated(this.group);

  @override
  List<Object?> get props => [group];
}

/// Xóa group thành công
class GroupDeleted extends GroupState {
  const GroupDeleted();
}

/// Tham gia group thành công
class GroupJoined extends GroupState {
  final Group group;

  const GroupJoined(this.group);

  @override
  List<Object?> get props => [group];
}

/// Rời khỏi group thành công
class GroupLeft extends GroupState {
  const GroupLeft();
}

/// Kick thành viên thành công
class MemberKicked extends GroupState {
  const MemberKicked();
}

/// Thay đổi role thành công
class RoleChanged extends GroupState {
  const RoleChanged();
}

/// Tạo mã mời mới thành công
class InviteCodeRegenerated extends GroupState {
  final String inviteCode;

  const InviteCodeRegenerated(this.inviteCode);

  @override
  List<Object?> get props => [inviteCode];
}

/// Load thành viên thành công
class GroupMembersLoaded extends GroupState {
  final List<GroupMember> members;

  const GroupMembersLoaded(this.members);

  @override
  List<Object?> get props => [members];
}

/// Load giao dịch group thành công
class GroupTransactionsLoaded extends GroupState {
  final List<Transaction> transactions;

  const GroupTransactionsLoaded(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

/// Có lỗi xảy ra
class GroupError extends GroupState {
  final String message;

  const GroupError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Thao tác thành công (generic success message)
class GroupOperationSuccess extends GroupState {
  final String message;

  const GroupOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
