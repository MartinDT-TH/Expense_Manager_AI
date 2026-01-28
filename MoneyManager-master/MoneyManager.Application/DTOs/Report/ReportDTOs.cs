namespace MoneyManager.Application.DTOs.Report;

// ===== REQUEST DTOs =====

/// <summary>
/// Request lấy báo cáo tổng quan
/// </summary>
public class ReportFilterRequest
{
    /// <summary>
    /// Ngày bắt đầu (UTC)
    /// </summary>
    public DateTime StartDate { get; set; }
    
    /// <summary>
    /// Ngày kết thúc (UTC)
    /// </summary>
    public DateTime EndDate { get; set; }
    
    /// <summary>
    /// Filter theo ví cụ thể (null = tất cả ví)
    /// </summary>
    public Guid? WalletId { get; set; }
    
    /// <summary>
    /// Filter theo loại tiền (null = tất cả)
    /// </summary>
    public string? Currency { get; set; }
}

/// <summary>
/// Request xuất báo cáo
/// </summary>
public class ExportReportRequest : ReportFilterRequest
{
    /// <summary>
    /// Định dạng xuất: CSV, EXCEL, PDF
    /// </summary>
    public string Format { get; set; } = "CSV";
    
    /// <summary>
    /// Email nhận báo cáo (tùy chọn)
    /// </summary>
    public string? Email { get; set; }
}

// ===== RESPONSE DTOs =====

/// <summary>
/// Response báo cáo tổng quan
/// </summary>
public class SummaryReportResponse
{
    /// <summary>
    /// Tổng thu nhập
    /// </summary>
    public decimal TotalIncome { get; set; }
    
    /// <summary>
    /// Tổng chi tiêu
    /// </summary>
    public decimal TotalExpense { get; set; }
    
    /// <summary>
    /// Số dư (Thu - Chi)
    /// </summary>
    public decimal NetBalance { get; set; }
    
    /// <summary>
    /// Số giao dịch
    /// </summary>
    public int TransactionCount { get; set; }
    
    /// <summary>
    /// Thu nhập trung bình/ngày
    /// </summary>
    public decimal AvgDailyIncome { get; set; }
    
    /// <summary>
    /// Chi tiêu trung bình/ngày
    /// </summary>
    public decimal AvgDailyExpense { get; set; }
    
    /// <summary>
    /// So sánh với kỳ trước
    /// </summary>
    public ComparisonData? Comparison { get; set; }
    
    /// <summary>
    /// Thời gian báo cáo
    /// </summary>
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
}

public class ComparisonData
{
    /// <summary>
    /// % thay đổi thu nhập so với kỳ trước
    /// </summary>
    public decimal IncomeChangePercent { get; set; }
    
    /// <summary>
    /// % thay đổi chi tiêu so với kỳ trước
    /// </summary>
    public decimal ExpenseChangePercent { get; set; }
    
    /// <summary>
    /// Xu hướng: Increase, Decrease, Stable
    /// </summary>
    public string IncomeTrend { get; set; } = string.Empty;
    public string ExpenseTrend { get; set; } = string.Empty;
}

/// <summary>
/// Response báo cáo theo danh mục
/// </summary>
public class CategoryReportResponse
{
    public List<CategoryReportItem> ExpenseByCategory { get; set; } = new();
    public List<CategoryReportItem> IncomeByCategory { get; set; } = new();
    
    /// <summary>
    /// Top 5 danh mục chi tiêu nhiều nhất
    /// </summary>
    public List<CategoryReportItem> TopExpenseCategories { get; set; } = new();
}

public class CategoryReportItem
{
    public Guid CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? Icon { get; set; }
    public string? Color { get; set; }
    public decimal Amount { get; set; }
    
    /// <summary>
    /// % so với tổng
    /// </summary>
    public decimal Percentage { get; set; }
    
    /// <summary>
    /// Số giao dịch
    /// </summary>
    public int TransactionCount { get; set; }
}

/// <summary>
/// Response báo cáo theo thời gian
/// </summary>
public class TimeReportResponse
{
    /// <summary>
    /// Loại nhóm: Daily, Weekly, Monthly
    /// </summary>
    public string GroupBy { get; set; } = string.Empty;
    
    public List<TimeReportItem> Data { get; set; } = new();
}

public class TimeReportItem
{
    /// <summary>
    /// Label (VD: "01/01", "Tuần 1", "Tháng 1")
    /// </summary>
    public string Label { get; set; } = string.Empty;
    
    /// <summary>
    /// Ngày bắt đầu của period
    /// </summary>
    public DateTime Date { get; set; }
    
    public decimal Income { get; set; }
    public decimal Expense { get; set; }
    public decimal Net { get; set; }
}

/// <summary>
/// Response xu hướng chi tiêu (Premium)
/// </summary>
public class TrendReportResponse
{
    /// <summary>
    /// Dự đoán chi tiêu tháng này
    /// </summary>
    public decimal PredictedExpenseThisMonth { get; set; }
    
    /// <summary>
    /// Chi tiêu trung bình 3 tháng gần nhất
    /// </summary>
    public decimal Avg3MonthExpense { get; set; }
    
    /// <summary>
    /// Xu hướng chi tiêu
    /// </summary>
    public string SpendingTrend { get; set; } = string.Empty; // Increasing, Decreasing, Stable
    
    /// <summary>
    /// Danh mục tăng nhiều nhất
    /// </summary>
    public string? FastestGrowingCategory { get; set; }
    
    /// <summary>
    /// % tăng của danh mục đó
    /// </summary>
    public decimal? FastestGrowingPercent { get; set; }
    
    /// <summary>
    /// Khuyến nghị
    /// </summary>
    public List<string> Recommendations { get; set; } = new();
    
    /// <summary>
    /// Dữ liệu xu hướng theo tháng
    /// </summary>
    public List<MonthlyTrendItem> MonthlyTrend { get; set; } = new();
}

public class MonthlyTrendItem
{
    public string Month { get; set; } = string.Empty;
    public int Year { get; set; }
    public decimal Expense { get; set; }
    public decimal Income { get; set; }
}

/// <summary>
/// Response xuất báo cáo
/// </summary>
public class ExportReportResponse
{
    /// <summary>
    /// URL download file (valid trong 24h)
    /// </summary>
    public string? DownloadUrl { get; set; }
    
    /// <summary>
    /// Tên file
    /// </summary>
    public string FileName { get; set; } = string.Empty;
    
    /// <summary>
    /// Định dạng
    /// </summary>
    public string Format { get; set; } = string.Empty;
    
    /// <summary>
    /// File content dạng Base64 (nếu nhỏ)
    /// </summary>
    public string? Base64Content { get; set; }
    
    /// <summary>
    /// Đã gửi email hay chưa
    /// </summary>
    public bool EmailSent { get; set; }
}
