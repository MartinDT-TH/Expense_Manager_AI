import 'package:equatable/equatable.dart';

/// Entity đại diện cho Quỹ nhóm
/// Quỹ nhóm là nơi để các thành viên xem chung chi tiêu, KHÔNG phải tiền chung
class Group extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? inviteCode;
  final int memberCount;
  final String currentUserRole; // ADMIN, MEMBER
  final String createdByUserId;
  final String? createdByUserName;
  final double totalExpense;
  final double totalIncome;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final bool isDeleted;
  final bool isSynced;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.inviteCode,
    this.memberCount = 0,
    this.currentUserRole = 'MEMBER',
    required this.createdByUserId,
    this.createdByUserName,
    this.totalExpense = 0,
    this.totalIncome = 0,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.isDeleted = false,
    this.isSynced = true,
  });

  /// Kiểm tra user hiện tại có phải Admin không
  bool get isAdmin => currentUserRole.toUpperCase() == 'ADMIN';

  /// Kiểm tra user hiện tại có phải người tạo không
  bool get isCreator => currentUserRole.toUpperCase() == 'ADMIN';

  /// Tổng số dư = Thu - Chi
  double get balance => totalIncome - totalExpense;

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? inviteCode,
    int? memberCount,
    String? currentUserRole,
    String? createdByUserId,
    String? createdByUserName,
    double? totalExpense,
    double? totalIncome,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    bool? isDeleted,
    bool? isSynced,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      memberCount: memberCount ?? this.memberCount,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      totalExpense: totalExpense ?? this.totalExpense,
      totalIncome: totalIncome ?? this.totalIncome,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        inviteCode,
        memberCount,
        currentUserRole,
        createdByUserId,
        createdByUserName,
        totalExpense,
        totalIncome,
        createdAt,
        lastUpdatedAt,
        isDeleted,
        isSynced,
      ];
}
