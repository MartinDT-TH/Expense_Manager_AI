import 'package:equatable/equatable.dart';

enum NotificationType {
  budgetAlert,      // Vượt ngân sách
  budgetWarning,    // Gần vượt ngân sách (80%)
  transaction,      // Giao dịch mới
  reminder,         // Nhắc nhở
  groupInvite,      // Được mời vào group
  groupActivity,    // Hoạt động trong group
  general,          // Thông báo chung
}

class NotificationEntity extends Equatable {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, body, type, data, isRead, createdAt];
}
