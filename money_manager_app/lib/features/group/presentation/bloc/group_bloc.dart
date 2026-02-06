import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/group_repository.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../../transaction/domain/entities/transaction.dart';
import 'group_event.dart';
import 'group_state.dart';

/// BLoC quản lý state cho Group Feature
class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final GroupRepository repository;

  // Cache data để không phải load lại
  List<Group> _cachedGroups = [];
  Group? _cachedGroupDetail;
  List<GroupMember> _cachedMembers = [];
  List<Transaction> _cachedTransactions = [];

  GroupBloc({required this.repository}) : super(const GroupInitial()) {
    on<LoadGroups>(_onLoadGroups);
    on<RefreshGroups>(_onRefreshGroups);
    on<LoadGroupDetail>(_onLoadGroupDetail);
    on<CreateGroup>(_onCreateGroup);
    on<UpdateGroup>(_onUpdateGroup);
    on<DeleteGroup>(_onDeleteGroup);
    on<JoinGroup>(_onJoinGroup);
    on<LeaveGroup>(_onLeaveGroup);
    on<LoadGroupMembers>(_onLoadGroupMembers);
    on<KickMember>(_onKickMember);
    on<ChangeRole>(_onChangeRole);
    on<RegenerateInviteCode>(_onRegenerateInviteCode);
    on<LoadGroupTransactions>(_onLoadGroupTransactions);
    on<ClearGroupDetail>(_onClearGroupDetail);
  }

  /// Load danh sách groups
  Future<void> _onLoadGroups(LoadGroups event, Emitter<GroupState> emit) async {
    emit(const GroupLoading());
    try {
      _cachedGroups = await repository.getGroups();
      emit(GroupsLoaded(_cachedGroups));
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Refresh danh sách groups
  Future<void> _onRefreshGroups(RefreshGroups event, Emitter<GroupState> emit) async {
    try {
      _cachedGroups = await repository.getGroups();
      emit(GroupsLoaded(_cachedGroups));
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Load chi tiết 1 group
  Future<void> _onLoadGroupDetail(LoadGroupDetail event, Emitter<GroupState> emit) async {
    emit(const GroupLoading());
    try {
      final group = await repository.getGroupById(event.groupId);
      if (group == null) {
        emit(const GroupError('Không tìm thấy nhóm'));
        return;
      }

      _cachedGroupDetail = group;
      _cachedMembers = await repository.getGroupMembers(event.groupId);
      _cachedTransactions = await repository.getGroupTransactions(event.groupId);

      emit(GroupDetailLoaded(
        group: _cachedGroupDetail!,
        members: _cachedMembers,
        transactions: _cachedTransactions,
      ));
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Tạo group mới
  Future<void> _onCreateGroup(CreateGroup event, Emitter<GroupState> emit) async {
    emit(const GroupLoading());
    try {
      final group = await repository.createGroup(
        name: event.name,
        description: event.description,
      );
      _cachedGroups.insert(0, group);
      emit(GroupCreated(group));
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Cập nhật group
  Future<void> _onUpdateGroup(UpdateGroup event, Emitter<GroupState> emit) async {
    emit(const GroupLoading());
    try {
      final group = await repository.updateGroup(
        id: event.id,
        name: event.name,
        description: event.description,
      );
      
      // Update cache
      final index = _cachedGroups.indexWhere((g) => g.id == event.id);
      if (index >= 0) {
        _cachedGroups[index] = group;
      }
      _cachedGroupDetail = group;

      emit(GroupUpdated(group));
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Xóa group
  Future<void> _onDeleteGroup(DeleteGroup event, Emitter<GroupState> emit) async {
    emit(const GroupLoading());
    try {
      await repository.deleteGroup(event.id);
      _cachedGroups.removeWhere((g) => g.id == event.id);
      _cachedGroupDetail = null;
      emit(const GroupDeleted());
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Tham gia group bằng invite code
  Future<void> _onJoinGroup(JoinGroup event, Emitter<GroupState> emit) async {
    emit(const GroupLoading());
    try {
      final group = await repository.joinGroup(event.inviteCode);
      _cachedGroups.insert(0, group);
      emit(GroupJoined(group));
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Rời khỏi group
  Future<void> _onLeaveGroup(LeaveGroup event, Emitter<GroupState> emit) async {
    emit(const GroupLoading());
    try {
      await repository.leaveGroup(event.groupId);
      _cachedGroups.removeWhere((g) => g.id == event.groupId);
      _cachedGroupDetail = null;
      emit(const GroupLeft());
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Load thành viên của group
  Future<void> _onLoadGroupMembers(LoadGroupMembers event, Emitter<GroupState> emit) async {
    try {
      _cachedMembers = await repository.getGroupMembers(event.groupId);
      
      if (_cachedGroupDetail != null) {
        emit(GroupDetailLoaded(
          group: _cachedGroupDetail!,
          members: _cachedMembers,
          transactions: _cachedTransactions,
        ));
      } else {
        emit(GroupMembersLoaded(_cachedMembers));
      }
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Kick thành viên
  Future<void> _onKickMember(KickMember event, Emitter<GroupState> emit) async {
    try {
      await repository.kickMember(event.groupId, event.userId);
      _cachedMembers.removeWhere((m) => m.userId == event.userId);
      
      if (_cachedGroupDetail != null) {
        _cachedGroupDetail = _cachedGroupDetail!.copyWith(
          memberCount: _cachedGroupDetail!.memberCount - 1,
        );
        emit(GroupDetailLoaded(
          group: _cachedGroupDetail!,
          members: _cachedMembers,
          transactions: _cachedTransactions,
        ));
      }
      emit(const MemberKicked());
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Thay đổi role
  Future<void> _onChangeRole(ChangeRole event, Emitter<GroupState> emit) async {
    try {
      await repository.changeRole(event.groupId, event.userId, event.newRole);
      
      // Update cached member
      final index = _cachedMembers.indexWhere((m) => m.userId == event.userId);
      if (index >= 0) {
        _cachedMembers[index] = _cachedMembers[index].copyWith(role: event.newRole);
      }

      if (_cachedGroupDetail != null) {
        emit(GroupDetailLoaded(
          group: _cachedGroupDetail!,
          members: _cachedMembers,
          transactions: _cachedTransactions,
        ));
      }
      emit(const RoleChanged());
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Tạo mã mời mới
  Future<void> _onRegenerateInviteCode(RegenerateInviteCode event, Emitter<GroupState> emit) async {
    try {
      final newCode = await repository.regenerateInviteCode(event.groupId);
      
      // Update cached group
      if (_cachedGroupDetail != null && _cachedGroupDetail!.id == event.groupId) {
        _cachedGroupDetail = _cachedGroupDetail!.copyWith(inviteCode: newCode);
        emit(GroupDetailLoaded(
          group: _cachedGroupDetail!,
          members: _cachedMembers,
          transactions: _cachedTransactions,
        ));
      }
      
      emit(InviteCodeRegenerated(newCode));
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Load giao dịch của group
  Future<void> _onLoadGroupTransactions(LoadGroupTransactions event, Emitter<GroupState> emit) async {
    try {
      _cachedTransactions = await repository.getGroupTransactions(event.groupId);
      
      if (_cachedGroupDetail != null) {
        emit(GroupDetailLoaded(
          group: _cachedGroupDetail!,
          members: _cachedMembers,
          transactions: _cachedTransactions,
        ));
      } else {
        emit(GroupTransactionsLoaded(_cachedTransactions));
      }
    } catch (e) {
      emit(GroupError(_getErrorMessage(e)));
    }
  }

  /// Clear group detail state
  void _onClearGroupDetail(ClearGroupDetail event, Emitter<GroupState> emit) {
    _cachedGroupDetail = null;
    _cachedMembers = [];
    _cachedTransactions = [];
    emit(GroupsLoaded(_cachedGroups));
  }

  /// Helper để lấy error message
  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('premium')) {
      return 'Tính năng này yêu cầu gói Premium';
    }
    if (error.toString().contains('401')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại';
    }
    if (error.toString().contains('404')) {
      return 'Không tìm thấy nhóm';
    }
    if (error.toString().contains('403')) {
      return 'You do not have permission for this action';
    }
    if (error.toString().contains('SocketException') || 
        error.toString().contains('Connection')) {
      return 'Không có kết nối mạng';
    }
    return error.toString();
  }

  /// Getter cho cached groups
  List<Group> get groups => _cachedGroups;
}
