import '../../../../core/network/api_client.dart';
import '../models/report_models.dart';

class ReportRemoteDataSource {
  final ApiClient apiClient;

  ReportRemoteDataSource({required this.apiClient});

  Future<SummaryReportModel> getSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
  }) async {
    final response = await apiClient.post(
      '/Report/summary',
      data: {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        if (walletId != null) 'walletId': walletId,
      },
    );
    return SummaryReportModel.fromJson(response.data);
  }

  Future<CategoryReportModel> getByCategory({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
  }) async {
    final response = await apiClient.post(
      '/Report/by-category',
      data: {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        if (walletId != null) 'walletId': walletId,
      },
    );
    return CategoryReportModel.fromJson(response.data);
  }

  Future<TimeReportModel> getByTime({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String groupBy = 'daily',
  }) async {
    final response = await apiClient.post(
      '/Report/by-time',
      data: {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        if (walletId != null) 'walletId': walletId,
      },
      queryParameters: {'groupBy': groupBy},
    );
    return TimeReportModel.fromJson(response.data);
  }

  Future<SummaryReportModel> getQuickSummary() async {
    final response = await apiClient.get('/Report/quick-summary');
    return SummaryReportModel.fromJson(response.data);
  }

  Future<SummaryReportModel> getMonthlySummary() async {
    final response = await apiClient.get('/Report/monthly-summary');
    return SummaryReportModel.fromJson(response.data);
  }

  Future<ExportReportResultModel> exportReport({
    required DateTime startDate,
    required DateTime endDate,
    String? walletId,
    String format = 'EXCEL',
  }) async {
    final response = await apiClient.post(
      '/Report/export',
      data: {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        if (walletId != null) 'walletId': walletId,
        'format': format,
      },
    );
    return ExportReportResultModel.fromJson(response.data);
  }
}
