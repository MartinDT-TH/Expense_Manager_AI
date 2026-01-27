import 'package:equatable/equatable.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class LoadReportData extends ReportEvent {
  final DateTime startDate;
  final DateTime endDate;
  final String? walletId;
  final String timeGroupBy;

  const LoadReportData({
    required this.startDate,
    required this.endDate,
    this.walletId,
    this.timeGroupBy = 'daily',
  });

  @override
  List<Object?> get props => [startDate, endDate, walletId, timeGroupBy];
}

class LoadQuickSummary extends ReportEvent {}

class LoadMonthlySummary extends ReportEvent {}

class ExportReport extends ReportEvent {
  final DateTime startDate;
  final DateTime endDate;
  final String? walletId;
  final String format;

  const ExportReport({
    required this.startDate,
    required this.endDate,
    this.walletId,
    this.format = 'EXCEL',
  });

  @override
  List<Object?> get props => [startDate, endDate, walletId, format];
}

class ChangeTimeFilter extends ReportEvent {
  final String filter; // 'week', 'month', 'custom'
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const ChangeTimeFilter({
    required this.filter,
    this.customStartDate,
    this.customEndDate,
  });

  @override
  List<Object?> get props => [filter, customStartDate, customEndDate];
}

class ChangeChartGroupBy extends ReportEvent {
  final String groupBy; // 'daily', 'weekly', 'monthly'

  const ChangeChartGroupBy({required this.groupBy});

  @override
  List<Object?> get props => [groupBy];
}
