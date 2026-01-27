import 'package:equatable/equatable.dart';

class Budget extends Equatable {
  final String id;
  final double amountLimit;
  final double amountSpent;
  final double amountRemaining;
  final double percentUsed;
  final bool isWarning;
  final bool isExceeded;
  final bool isRecurring; // true = budget mặc định cho mọi tháng
  final String? categoryId; // null = ngân sách tổng tháng
  final String categoryName;
  final String? categoryIcon;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.amountLimit,
    required this.amountSpent,
    required this.amountRemaining,
    required this.percentUsed,
    required this.isWarning,
    required this.isExceeded,
    this.isRecurring = false,
    this.categoryId,
    required this.categoryName,
    this.categoryIcon,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get status color based on percentage
  BudgetStatus get status {
    if (isExceeded) return BudgetStatus.exceeded;
    if (isWarning) return BudgetStatus.warning;
    return BudgetStatus.normal;
  }

  @override
  List<Object?> get props => [
        id,
        amountLimit,
        amountSpent,
        amountRemaining,
        percentUsed,
        isWarning,
        isExceeded,
        isRecurring,
        categoryId,
        categoryName,
        categoryIcon,
        startDate,
        endDate,
        createdAt,
        updatedAt,
      ];
}

enum BudgetStatus {
  normal,  // < 80%
  warning, // 80% - 100%
  exceeded, // > 100%
}
