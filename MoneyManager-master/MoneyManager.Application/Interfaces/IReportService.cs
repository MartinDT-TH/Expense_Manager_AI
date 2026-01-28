using MoneyManager.Application.DTOs.Report;

namespace MoneyManager.Application.Interfaces;

public interface IReportService
{
    /// <summary>
    /// Lấy báo cáo tổng quan
    /// </summary>
    Task<SummaryReportResponse> GetSummaryAsync(ReportFilterRequest request, Guid userId);
    
    /// <summary>
    /// Lấy báo cáo theo danh mục
    /// </summary>
    Task<CategoryReportResponse> GetByCategoryAsync(ReportFilterRequest request, Guid userId);
    
    /// <summary>
    /// Lấy báo cáo theo thời gian
    /// </summary>
    Task<TimeReportResponse> GetByTimeAsync(ReportFilterRequest request, Guid userId, string groupBy);
    
    /// <summary>
    /// Lấy xu hướng chi tiêu (Premium)
    /// </summary>
    Task<TrendReportResponse> GetTrendAsync(Guid userId);
    
    /// <summary>
    /// Xuất báo cáo (Premium)
    /// </summary>
    Task<ExportReportResponse> ExportAsync(ExportReportRequest request, Guid userId, bool isPremium);
}
