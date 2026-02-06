/// Budget history item for a specific month
class BudgetHistoryItem {
  final int year;
  final int month;
  final String monthName;
  final double budgetLimit;
  final double amountSpent;
  final double amountRemaining;
  final double percentUsed;
  final bool wasExceeded;

  const BudgetHistoryItem({
    required this.year,
    required this.month,
    required this.monthName,
    required this.budgetLimit,
    required this.amountSpent,
    required this.amountRemaining,
    required this.percentUsed,
    required this.wasExceeded,
  });

  factory BudgetHistoryItem.fromJson(Map<String, dynamic> json) {
    return BudgetHistoryItem(
      year: json['year'] as int,
      month: json['month'] as int,
      monthName: json['monthName'] as String? ?? '',
      budgetLimit: (json['budgetLimit'] as num?)?.toDouble() ?? 0,
      amountSpent: (json['amountSpent'] as num?)?.toDouble() ?? 0,
      amountRemaining: (json['amountRemaining'] as num?)?.toDouble() ?? 0,
      percentUsed: (json['percentUsed'] as num?)?.toDouble() ?? 0,
      wasExceeded: json['wasExceeded'] as bool? ?? false,
    );
  }
}

/// Budget history response
class BudgetHistoryResponse {
  final List<BudgetHistoryItem> history;
  final double averageMonthlySpending;
  final double averageMonthlyBudget;
  final int monthsExceeded;
  final int totalMonths;

  const BudgetHistoryResponse({
    required this.history,
    required this.averageMonthlySpending,
    required this.averageMonthlyBudget,
    required this.monthsExceeded,
    required this.totalMonths,
  });

  factory BudgetHistoryResponse.fromJson(Map<String, dynamic> json) {
    return BudgetHistoryResponse(
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => BudgetHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      averageMonthlySpending: (json['averageMonthlySpending'] as num?)?.toDouble() ?? 0,
      averageMonthlyBudget: (json['averageMonthlyBudget'] as num?)?.toDouble() ?? 0,
      monthsExceeded: json['monthsExceeded'] as int? ?? 0,
      totalMonths: json['totalMonths'] as int? ?? 0,
    );
  }
}

/// Category budget analytics
class CategoryBudgetAnalytics {
  final String? categoryId;
  final String categoryName;
  final String? categoryIcon;
  final double totalBudget;
  final double totalSpent;
  final double percentUsed;
  final double averageMonthlySpent;

  const CategoryBudgetAnalytics({
    this.categoryId,
    required this.categoryName,
    this.categoryIcon,
    required this.totalBudget,
    required this.totalSpent,
    required this.percentUsed,
    required this.averageMonthlySpent,
  });

  factory CategoryBudgetAnalytics.fromJson(Map<String, dynamic> json) {
    return CategoryBudgetAnalytics(
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String? ?? '',
      categoryIcon: json['categoryIcon'] as String?,
      totalBudget: (json['totalBudget'] as num?)?.toDouble() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
      percentUsed: (json['percentUsed'] as num?)?.toDouble() ?? 0,
      averageMonthlySpent: (json['averageMonthlySpent'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Budget analytics response
class BudgetAnalyticsResponse {
  // Summary
  final double totalBudgetThisMonth;
  final double totalSpentThisMonth;
  final double remainingThisMonth;
  final double percentUsedThisMonth;

  // Trends
  final List<BudgetHistoryItem> monthlyTrend;

  // Category breakdown
  final List<CategoryBudgetAnalytics> categoryBreakdown;

  // Insights
  final double averageDailySpending;
  final double projectedMonthlySpending;
  final bool willExceedBudget;
  final int daysUntilBudgetExceeded;

  // Recommendations
  final double suggestedDailyLimit;
  final String? insightMessage;

  const BudgetAnalyticsResponse({
    required this.totalBudgetThisMonth,
    required this.totalSpentThisMonth,
    required this.remainingThisMonth,
    required this.percentUsedThisMonth,
    required this.monthlyTrend,
    required this.categoryBreakdown,
    required this.averageDailySpending,
    required this.projectedMonthlySpending,
    required this.willExceedBudget,
    required this.daysUntilBudgetExceeded,
    required this.suggestedDailyLimit,
    this.insightMessage,
  });

  factory BudgetAnalyticsResponse.fromJson(Map<String, dynamic> json) {
    return BudgetAnalyticsResponse(
      totalBudgetThisMonth: (json['totalBudgetThisMonth'] as num?)?.toDouble() ?? 0,
      totalSpentThisMonth: (json['totalSpentThisMonth'] as num?)?.toDouble() ?? 0,
      remainingThisMonth: (json['remainingThisMonth'] as num?)?.toDouble() ?? 0,
      percentUsedThisMonth: (json['percentUsedThisMonth'] as num?)?.toDouble() ?? 0,
      monthlyTrend: (json['monthlyTrend'] as List<dynamic>?)
              ?.map((e) => BudgetHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      categoryBreakdown: (json['categoryBreakdown'] as List<dynamic>?)
              ?.map((e) => CategoryBudgetAnalytics.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      averageDailySpending: (json['averageDailySpending'] as num?)?.toDouble() ?? 0,
      projectedMonthlySpending: (json['projectedMonthlySpending'] as num?)?.toDouble() ?? 0,
      willExceedBudget: json['willExceedBudget'] as bool? ?? false,
      daysUntilBudgetExceeded: json['daysUntilBudgetExceeded'] as int? ?? 0,
      suggestedDailyLimit: (json['suggestedDailyLimit'] as num?)?.toDouble() ?? 0,
      insightMessage: json['insightMessage'] as String?,
    );
  }
}

/// Smart budget suggestion
class BudgetSuggestion {
  final String? categoryId;
  final String categoryName;
  final double suggestedAmount;
  final double averageSpent;
  final double minSpent;
  final double maxSpent;
  final String reason;

  const BudgetSuggestion({
    this.categoryId,
    required this.categoryName,
    required this.suggestedAmount,
    required this.averageSpent,
    required this.minSpent,
    required this.maxSpent,
    required this.reason,
  });

  factory BudgetSuggestion.fromJson(Map<String, dynamic> json) {
    return BudgetSuggestion(
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String? ?? '',
      suggestedAmount: (json['suggestedAmount'] as num?)?.toDouble() ?? 0,
      averageSpent: (json['averageSpent'] as num?)?.toDouble() ?? 0,
      minSpent: (json['minSpent'] as num?)?.toDouble() ?? 0,
      maxSpent: (json['maxSpent'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
    );
  }
}
