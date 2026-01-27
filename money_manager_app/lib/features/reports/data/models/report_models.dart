import '../../domain/entities/report_data.dart';

class SummaryReportModel extends SummaryReport {
  const SummaryReportModel({
    required super.totalIncome,
    required super.totalExpense,
    required super.netBalance,
    required super.transactionCount,
    super.incomeCount,
    super.expenseCount,
    required super.avgDailyIncome,
    required super.avgDailyExpense,
    required super.startDate,
    required super.endDate,
    super.comparison,
  });

  factory SummaryReportModel.fromJson(Map<String, dynamic> json) {
    return SummaryReportModel(
      totalIncome: (json['totalIncome'] ?? 0).toDouble(),
      totalExpense: (json['totalExpense'] ?? 0).toDouble(),
      netBalance: (json['netBalance'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
      incomeCount: json['incomeCount'] ?? 0,
      expenseCount: json['expenseCount'] ?? 0,
      avgDailyIncome: (json['avgDailyIncome'] ?? 0).toDouble(),
      avgDailyExpense: (json['avgDailyExpense'] ?? 0).toDouble(),
      startDate: json['startDate'] != null 
          ? DateTime.parse(json['startDate']) 
          : DateTime.now(),
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate']) 
          : DateTime.now(),
      comparison: json['comparison'] != null 
          ? ComparisonDataModel.fromJson(json['comparison'])
          : null,
    );
  }
}

class ComparisonDataModel extends ComparisonData {
  const ComparisonDataModel({
    required super.incomeChangePercent,
    required super.expenseChangePercent,
    required super.incomeTrend,
    required super.expenseTrend,
  });

  factory ComparisonDataModel.fromJson(Map<String, dynamic> json) {
    return ComparisonDataModel(
      incomeChangePercent: (json['incomeChangePercent'] ?? 0).toDouble(),
      expenseChangePercent: (json['expenseChangePercent'] ?? 0).toDouble(),
      incomeTrend: json['incomeTrend'] ?? 'Stable',
      expenseTrend: json['expenseTrend'] ?? 'Stable',
    );
  }
}

class CategoryReportModel extends CategoryReport {
  const CategoryReportModel({
    required super.expenseByCategory,
    required super.incomeByCategory,
    required super.topExpenseCategories,
    super.totalExpense,
    super.totalIncome,
  });

  factory CategoryReportModel.fromJson(Map<String, dynamic> json) {
    final expenseItems = (json['expenseByCategory'] as List? ?? [])
        .map((e) => CategoryReportItemModel.fromJson(e))
        .toList();
    final incomeItems = (json['incomeByCategory'] as List? ?? [])
        .map((e) => CategoryReportItemModel.fromJson(e))
        .toList();
        
    // Calculate totals from items
    final totalExpense = expenseItems.fold<double>(0, (sum, item) => sum + item.amount);
    final totalIncome = incomeItems.fold<double>(0, (sum, item) => sum + item.amount);
    
    return CategoryReportModel(
      expenseByCategory: expenseItems,
      incomeByCategory: incomeItems,
      topExpenseCategories: (json['topExpenseCategories'] as List? ?? [])
          .map((e) => CategoryReportItemModel.fromJson(e))
          .toList(),
      totalExpense: totalExpense,
      totalIncome: totalIncome,
    );
  }
}

class CategoryReportItemModel extends CategoryReportItem {
  const CategoryReportItemModel({
    required super.categoryId,
    required super.categoryName,
    super.icon,
    super.color,
    required super.amount,
    required super.percentage,
    required super.transactionCount,
  });

  factory CategoryReportItemModel.fromJson(Map<String, dynamic> json) {
    return CategoryReportItemModel(
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'] ?? 'Unknown',
      icon: json['icon'],
      color: json['color'],
      amount: (json['amount'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
    );
  }
}

class TimeReportModel extends TimeReport {
  const TimeReportModel({
    required super.groupBy,
    required super.data,
  });

  factory TimeReportModel.fromJson(Map<String, dynamic> json) {
    return TimeReportModel(
      groupBy: json['groupBy'] ?? 'daily',
      data: (json['data'] as List? ?? [])
          .map((e) => TimeReportItemModel.fromJson(e))
          .toList(),
    );
  }
}

class TimeReportItemModel extends TimeReportItem {
  const TimeReportItemModel({
    required super.label,
    required super.date,
    required super.income,
    required super.expense,
    required super.net,
  });

  factory TimeReportItemModel.fromJson(Map<String, dynamic> json) {
    return TimeReportItemModel(
      label: json['label'] ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      income: (json['income'] ?? 0).toDouble(),
      expense: (json['expense'] ?? 0).toDouble(),
      net: (json['net'] ?? 0).toDouble(),
    );
  }
}

class ExportReportResultModel extends ExportReportResult {
  const ExportReportResultModel({
    super.downloadUrl,
    required super.fileName,
    required super.format,
    super.base64Content,
    required super.emailSent,
  });

  factory ExportReportResultModel.fromJson(Map<String, dynamic> json) {
    return ExportReportResultModel(
      downloadUrl: json['downloadUrl'],
      fileName: json['fileName'] ?? 'report',
      format: json['format'] ?? 'EXCEL',
      base64Content: json['base64Content'],
      emailSent: json['emailSent'] ?? false,
    );
  }
}
