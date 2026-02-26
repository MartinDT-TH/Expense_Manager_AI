import '../../domain/entities/budget.dart';

class BudgetModel extends Budget {
  const BudgetModel({
    required super.id,
    required super.amountLimit,
    required super.amountSpent,
    required super.amountRemaining,
    required super.percentUsed,
    required super.isWarning,
    required super.isExceeded,
    super.isRecurring = false,
    super.categoryId,
    required super.categoryName,
    super.categoryIcon,
    required super.startDate,
    required super.endDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String,
      amountLimit: (json['amountLimit'] as num).toDouble(),
      amountSpent: (json['amountSpent'] as num?)?.toDouble() ?? 0,
      amountRemaining: (json['amountRemaining'] as num?)?.toDouble() ?? 0,
      percentUsed: (json['percentUsed'] as num?)?.toDouble() ?? 0,
      isWarning: json['isWarning'] as bool? ?? false,
      isExceeded: json['isExceeded'] as bool? ?? false,
      isRecurring: json['isRecurring'] as bool? ?? false,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String? ?? '',
      categoryIcon: json['categoryIcon'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['lastUpdatedAt'] != null
          ? DateTime.parse(json['lastUpdatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amountLimit': amountLimit,
      if (categoryId != null) 'categoryId': categoryId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isRecurring': isRecurring,
    };
  }

  /// Convert to SQLite map (snake_case columns)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_icon': categoryIcon,
      'amount_limit': amountLimit,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
      'is_deleted': 0,
      'last_updated_at': updatedAt.toIso8601String(),
      'is_synced': 0,
    };
  }

  /// Create from SQLite map (snake_case columns)
  /// Note: amountSpent should be calculated separately from transactions
  factory BudgetModel.fromMap(Map<String, dynamic> map, {double? calculatedSpent}) {
    final amountLimit = (map['amount_limit'] as num).toDouble();
    final spent = calculatedSpent ?? 0;
    final remaining = amountLimit - spent;
    final percentUsed = amountLimit > 0 ? (spent / amountLimit) * 100 : 0.0;
    
    return BudgetModel(
      id: map['id'] as String,
      amountLimit: amountLimit,
      amountSpent: spent,
      amountRemaining: remaining,
      percentUsed: percentUsed,
      isWarning: percentUsed >= 80 && percentUsed < 100,
      isExceeded: percentUsed >= 100,
      isRecurring: (map['is_recurring'] as int?) == 1,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String? ?? '',
      categoryIcon: map['category_icon'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      createdAt: map['last_updated_at'] != null 
          ? DateTime.parse(map['last_updated_at'] as String)
          : DateTime.now(),
      updatedAt: map['last_updated_at'] != null 
          ? DateTime.parse(map['last_updated_at'] as String)
          : DateTime.now(),
    );
  }

  factory BudgetModel.fromEntity(Budget budget) {
    return BudgetModel(
      id: budget.id,
      amountLimit: budget.amountLimit,
      amountSpent: budget.amountSpent,
      amountRemaining: budget.amountRemaining,
      percentUsed: budget.percentUsed,
      isWarning: budget.isWarning,
      isExceeded: budget.isExceeded,
      isRecurring: budget.isRecurring,
      categoryId: budget.categoryId,
      categoryName: budget.categoryName,
      categoryIcon: budget.categoryIcon,
      startDate: budget.startDate,
      endDate: budget.endDate,
      createdAt: budget.createdAt,
      updatedAt: budget.updatedAt,
    );
  }
}

/// Request model for creating/updating budget
class CreateBudgetRequest {
  final String? id;
  final double amountLimit;
  final String? categoryId; // Optional - null means total monthly budget
  final DateTime? startDate; // Optional for recurring
  final DateTime? endDate;   // Optional for recurring
  final bool isRecurring;    // true = áp dụng cho mọi tháng

  CreateBudgetRequest({
    this.id,
    required this.amountLimit,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.isRecurring = false,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'amountLimit': amountLimit,
      if (categoryId != null) 'categoryId': categoryId,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      'isRecurring': isRecurring,
    };
  }
}

class UpdateBudgetRequest {
  final double? amountLimit;
  final String? categoryId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isRecurring;

  UpdateBudgetRequest({
    this.amountLimit,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.isRecurring,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (amountLimit != null) map['amountLimit'] = amountLimit;
    if (categoryId != null) map['categoryId'] = categoryId;
    if (startDate != null) map['startDate'] = startDate!.toIso8601String();
    if (endDate != null) map['endDate'] = endDate!.toIso8601String();
    if (isRecurring != null) map['isRecurring'] = isRecurring;
    return map;
  }
}

/// Response for budget warnings
class BudgetWarningResponse {
  final List<BudgetModel> warningBudgets;
  final List<BudgetModel> exceededBudgets;

  BudgetWarningResponse({
    required this.warningBudgets,
    required this.exceededBudgets,
  });

  factory BudgetWarningResponse.fromJson(Map<String, dynamic> json) {
    return BudgetWarningResponse(
      warningBudgets: (json['warningBudgets'] as List<dynamic>?)
              ?.map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      exceededBudgets: (json['exceededBudgets'] as List<dynamic>?)
              ?.map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get hasWarnings => warningBudgets.isNotEmpty || exceededBudgets.isNotEmpty;
}
