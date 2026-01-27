import 'package:equatable/equatable.dart';

/// Summary report data
class SummaryReport extends Equatable {
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final int transactionCount;
  final int incomeCount;
  final int expenseCount;
  final double avgDailyIncome;
  final double avgDailyExpense;
  final DateTime startDate;
  final DateTime endDate;
  final ComparisonData? comparison;

  const SummaryReport({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.transactionCount,
    this.incomeCount = 0,
    this.expenseCount = 0,
    required this.avgDailyIncome,
    required this.avgDailyExpense,
    required this.startDate,
    required this.endDate,
    this.comparison,
  });

  @override
  List<Object?> get props => [
        totalIncome,
        totalExpense,
        netBalance,
        transactionCount,
        incomeCount,
        expenseCount,
        avgDailyIncome,
        avgDailyExpense,
        startDate,
        endDate,
        comparison,
      ];
}

/// Comparison with previous period
class ComparisonData extends Equatable {
  final double incomeChangePercent;
  final double expenseChangePercent;
  final String incomeTrend;
  final String expenseTrend;

  const ComparisonData({
    required this.incomeChangePercent,
    required this.expenseChangePercent,
    required this.incomeTrend,
    required this.expenseTrend,
  });

  @override
  List<Object?> get props => [
        incomeChangePercent,
        expenseChangePercent,
        incomeTrend,
        expenseTrend,
      ];
}

/// Category report data
class CategoryReport extends Equatable {
  final List<CategoryReportItem> expenseByCategory;
  final List<CategoryReportItem> incomeByCategory;
  final List<CategoryReportItem> topExpenseCategories;
  final double totalExpense;
  final double totalIncome;

  const CategoryReport({
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.topExpenseCategories,
    this.totalExpense = 0,
    this.totalIncome = 0,
  });

  /// Get combined items for display (use expense categories)
  List<CategoryReportItem> get items => expenseByCategory;

  @override
  List<Object?> get props => [
        expenseByCategory,
        incomeByCategory,
        topExpenseCategories,
        totalExpense,
        totalIncome,
      ];
}

class CategoryReportItem extends Equatable {
  final String categoryId;
  final String categoryName;
  final String? icon;
  final String? color;
  final double amount;
  final double percentage;
  final int transactionCount;

  const CategoryReportItem({
    required this.categoryId,
    required this.categoryName,
    this.icon,
    this.color,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
  });

  @override
  List<Object?> get props => [
        categoryId,
        categoryName,
        icon,
        color,
        amount,
        percentage,
        transactionCount,
      ];
}

/// Time-based report data
class TimeReport extends Equatable {
  final String groupBy;
  final List<TimeReportItem> data;

  const TimeReport({
    required this.groupBy,
    required this.data,
  });

  /// Alias for data to match UI expectations
  List<TimeReportItem> get items => data;

  @override
  List<Object?> get props => [groupBy, data];
}

class TimeReportItem extends Equatable {
  final String label;
  final DateTime date;
  final double income;
  final double expense;
  final double net;

  const TimeReportItem({
    required this.label,
    required this.date,
    required this.income,
    required this.expense,
    required this.net,
  });

  @override
  List<Object?> get props => [label, date, income, expense, net];
}

/// Export report response
class ExportReportResult extends Equatable {
  final String? downloadUrl;
  final String fileName;
  final String format;
  final String? base64Content;
  final bool emailSent;

  const ExportReportResult({
    this.downloadUrl,
    required this.fileName,
    required this.format,
    this.base64Content,
    required this.emailSent,
  });

  @override
  List<Object?> get props => [
        downloadUrl,
        fileName,
        format,
        base64Content,
        emailSent,
      ];
}
