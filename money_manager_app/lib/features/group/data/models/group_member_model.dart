import '../../domain/entities/group_member.dart';

/// Model cho GroupMember, dùng để parse JSON từ API
class GroupMemberModel extends GroupMember {
  const GroupMemberModel({
    required super.id,
    required super.groupId,
    required super.userId,
    super.fullName,
    super.email,
    super.avatarUrl,
    super.role,
    required super.joinedAt,
    super.totalContribution,
    super.isDeleted,
    super.isSynced,
  });

  /// Parse từ JSON response của API
  factory GroupMemberModel.fromJson(Map<String, dynamic> json, {String? groupId}) {
    return GroupMemberModel(
      id: json['id'] ?? '${json['userId']}_${groupId ?? json['groupId']}',
      groupId: groupId ?? json['groupId'] ?? '',
      userId: json['userId'] ?? '',
      fullName: json['fullName'],
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'MEMBER',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
      totalContribution: (json['totalContribution'] ?? 0).toDouble(),
      isDeleted: json['isDeleted'] ?? false,
      isSynced: true,
    );
  }

  /// Convert sang JSON để gửi API
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'groupId': groupId,
      'role': role,
    };
  }

  /// Parse từ SQLite database
  factory GroupMemberModel.fromDatabase(Map<String, dynamic> map) {
    return GroupMemberModel(
      id: map['id'],
      groupId: map['group_id'],
      userId: map['user_id'],
      fullName: map['full_name'],
      email: map['email'],
      avatarUrl: map['avatar_url'],
      role: map['role'] ?? 'MEMBER',
      joinedAt: DateTime.parse(map['joined_at']),
      totalContribution: (map['total_contribution'] ?? 0).toDouble(),
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }

  /// Convert sang Map để lưu SQLite
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'total_contribution': totalContribution,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Convert từ Entity sang Model
  factory GroupMemberModel.fromEntity(GroupMember member) {
    return GroupMemberModel(
      id: member.id,
      groupId: member.groupId,
      userId: member.userId,
      fullName: member.fullName,
      email: member.email,
      avatarUrl: member.avatarUrl,
      role: member.role,
      joinedAt: member.joinedAt,
      totalContribution: member.totalContribution,
      isDeleted: member.isDeleted,
      isSynced: member.isSynced,
    );
  }
}
