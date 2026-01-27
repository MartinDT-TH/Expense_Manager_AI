import 'package:equatable/equatable.dart';

/// Entity đại diện cho thành viên trong nhóm
class GroupMember extends Equatable {
  final String id;
  final String groupId;
  final String userId;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String role; // ADMIN, MEMBER
  final DateTime joinedAt;
  final double totalContribution; // Tổng đóng góp (chi tiêu) của thành viên
  final bool isDeleted;
  final bool isSynced;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.role = 'MEMBER',
    required this.joinedAt,
    this.totalContribution = 0,
    this.isDeleted = false,
    this.isSynced = true,
  });

  /// Kiểm tra thành viên có phải Admin không
  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  /// Lấy tên hiển thị (ưu tiên fullName, nếu không có thì dùng email)
  String get displayName => fullName ?? email ?? 'Unknown';

  /// Lấy initials cho avatar (VD: "Nguyễn Văn An" -> "NA")
  String get initials {
    if (fullName == null || fullName!.isEmpty) {
      return email?.substring(0, 1).toUpperCase() ?? '?';
    }
    final parts = fullName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName![0].toUpperCase();
  }

  GroupMember copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? fullName,
    String? email,
    String? avatarUrl,
    String? role,
    DateTime? joinedAt,
    double? totalContribution,
    bool? isDeleted,
    bool? isSynced,
  }) {
    return GroupMember(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      totalContribution: totalContribution ?? this.totalContribution,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        userId,
        fullName,
        email,
        avatarUrl,
        role,
        joinedAt,
        totalContribution,
        isDeleted,
        isSynced,
      ];
}
