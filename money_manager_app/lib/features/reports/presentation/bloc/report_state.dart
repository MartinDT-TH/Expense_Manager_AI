import 'package:equatable/equatable.dart';
import '../../domain/entities/report_data.dart';

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportLoaded extends ReportState {
  final SummaryReport summary;
  final CategoryReport categoryReport;
  final TimeReport timeReport;
  final String currentFilter; // 'week', 'month', 'custom'
  final String chartGroupBy; // 'daily', 'weekly', 'monthly'
  final DateTime startDate;
  final DateTime endDate;

  const ReportLoaded({
    required this.summary,
    required this.categoryReport,
    required this.timeReport,
    required this.currentFilter,
    required this.chartGroupBy,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [
        summary,
        categoryReport,
        timeReport,
        currentFilter,
        chartGroupBy,
        startDate,
        endDate,
      ];

  ReportLoaded copyWith({
    SummaryReport? summary,
    CategoryReport? categoryReport,
    TimeReport? timeReport,
    String? currentFilter,
    String? chartGroupBy,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ReportLoaded(
      summary: summary ?? this.summary,
      categoryReport: categoryReport ?? this.categoryReport,
      timeReport: timeReport ?? this.timeReport,
      currentFilter: currentFilter ?? this.currentFilter,
      chartGroupBy: chartGroupBy ?? this.chartGroupBy,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class ReportError extends ReportState {
  final String message;

  const ReportError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReportExporting extends ReportState {}

class ReportExported extends ReportState {
  final ExportReportResult result;

  const ReportExported(this.result);

  @override
  List<Object?> get props => [result];
}

class ReportExportError extends ReportState {
  final String message;

  const ReportExportError(this.message);

  @override
  List<Object?> get props => [message];
}
