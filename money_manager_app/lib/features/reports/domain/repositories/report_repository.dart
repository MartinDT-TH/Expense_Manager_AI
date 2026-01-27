import '../entities/report_data.dart';

abstract class ReportRepository {
  Future<SummaryReport> getSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
  });

  Future<CategoryReport> getByCategory({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
  });

  Future<TimeReport> getByTime({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String groupBy = 'daily',
  });

  Future<SummaryReport> getQuickSummary();
  
  Future<SummaryReport> getMonthlySummary();

  Future<ExportReportResult> exportReport({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String format = 'EXCEL',
  });
}
