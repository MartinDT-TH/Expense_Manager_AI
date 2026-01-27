import '../../domain/entities/group.dart';

/// Model cho Group, dùng để parse JSON từ API
class GroupModel extends Group {
  const GroupModel({
    required super.id,
    required super.name,
    super.description,
    super.inviteCode,
    super.memberCount,
    super.currentUserRole,
    required super.createdByUserId,
    super.createdByUserName,
    super.totalExpense,
    super.totalIncome,
    required super.createdAt,
    required super.lastUpdatedAt,
    super.isDeleted,
    super.isSynced,
  });

  /// Parse từ JSON response của API
  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      inviteCode: json['inviteCode'],
      memberCount: json['memberCount'] ?? 0,
      currentUserRole: json['currentUserRole'] ?? 'MEMBER',
      createdByUserId: json['createdByUserId'] ?? '',
      createdByUserName: json['createdByUserName'],
      totalExpense: (json['totalExpense'] ?? 0).toDouble(),
      totalIncome: (json['totalIncome'] ?? 0).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastUpdatedAt: json['lastUpdatedAt'] != null
          ? DateTime.parse(json['lastUpdatedAt'])
          : DateTime.now(),
      isDeleted: json['isDeleted'] ?? false,
      isSynced: true,
    );
  }

  /// Convert sang JSON để gửi API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  /// Parse từ SQLite database
  factory GroupModel.fromDatabase(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      inviteCode: map['invite_code'],
      memberCount: map['member_count'] ?? 0,
      currentUserRole: map['current_user_role'] ?? 'MEMBER',
      createdByUserId: map['created_by_user_id'] ?? '',
      createdByUserName: map['created_by_user_name'],
      totalExpense: (map['total_expense'] ?? 0).toDouble(),
      totalIncome: (map['total_income'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
      lastUpdatedAt: DateTime.parse(map['last_updated_at']),
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }

  /// Convert sang Map để lưu SQLite
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'invite_code': inviteCode,
      'member_count': memberCount,
      'current_user_role': currentUserRole,
      'created_by_user_id': createdByUserId,
      'created_by_user_name': createdByUserName,
      'total_expense': totalExpense,
      'total_income': totalIncome,
      'created_at': createdAt.toIso8601String(),
      'last_updated_at': lastUpdatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Convert từ Entity sang Model
  factory GroupModel.fromEntity(Group group) {
    return GroupModel(
      id: group.id,
      name: group.name,
      description: group.description,
      inviteCode: group.inviteCode,
      memberCount: group.memberCount,
      currentUserRole: group.currentUserRole,
      createdByUserId: group.createdByUserId,
      createdByUserName: group.createdByUserName,
      totalExpense: group.totalExpense,
      totalIncome: group.totalIncome,
      createdAt: group.createdAt,
      lastUpdatedAt: group.lastUpdatedAt,
      isDeleted: group.isDeleted,
      isSynced: group.isSynced,
    );
  }
}
