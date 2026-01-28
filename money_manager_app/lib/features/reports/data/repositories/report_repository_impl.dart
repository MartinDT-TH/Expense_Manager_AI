import '../../domain/entities/report_data.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_datasource.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource remoteDataSource;

  ReportRepositoryImpl({required this.remoteDataSource});

  @override
  Future<SummaryReport> getSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
  }) async {
    return await remoteDataSource.getSummary(
      startDate: startDate,
      endDate: endDate,
      walletId: walletId,
    );
  }

  @override
  Future<CategoryReport> getByCategory({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
  }) async {
    return await remoteDataSource.getByCategory(
      startDate: startDate,
      endDate: endDate,
      walletId: walletId,
    );
  }

  @override
  Future<TimeReport> getByTime({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String groupBy = 'daily',
  }) async {
    return await remoteDataSource.getByTime(
      startDate: startDate,
      endDate: endDate,
      walletId: walletId,
      groupBy: groupBy,
    );
  }

  @override
  Future<SummaryReport> getQuickSummary() async {
    return await remoteDataSource.getQuickSummary();
  }

  @override
  Future<SummaryReport> getMonthlySummary() async {
    return await remoteDataSource.getMonthlySummary();
  }

  @override
  Future<ExportReportResult> exportReport({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String format = 'EXCEL',
  }) async {
    final normalized = _normalizeExportFormat(format);
    return await remoteDataSource.exportReport(
      startDate: startDate,
      endDate: endDate,
      walletId: walletId,
      format: normalized,
    );
  }

  String _normalizeExportFormat(String format) {
    final raw = format.trim();
    final lower = raw.toLowerCase();
    if (lower == 'excel' || lower == 'xlsx' || lower == 'xls') return 'EXCEL';
    if (lower == 'pdf') return 'PDF';
    return raw.toUpperCase();
  }
}
