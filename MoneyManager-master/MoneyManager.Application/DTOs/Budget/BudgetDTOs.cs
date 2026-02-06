namespace MoneyManager.Application.DTOs.Budget;

// ===== REQUEST DTOs =====

/// <summary>
/// Request tạo ngân sách mới
/// </summary>
public class CreateBudgetRequest
{
    /// <summary>
    /// ID do Client gen (GUID) - Hỗ trợ offline-first
    /// </summary>
    public Guid? Id { get; set; }
    
    /// <summary>
    /// Hạn mức chi tiêu
    /// </summary>
    public decimal AmountLimit { get; set; }
    
    /// <summary>
    /// ID danh mục áp dụng - Nếu null thì là ngân sách tổng cho tháng
    /// </summary>
    public Guid? CategoryId { get; set; }
    
    /// <summary>
    /// Ngày bắt đầu - Bỏ qua nếu IsRecurring = true
    /// </summary>
    public DateTime? StartDate { get; set; }
    
    /// <summary>
    /// Ngày kết thúc - Bỏ qua nếu IsRecurring = true
    /// </summary>
    public DateTime? EndDate { get; set; }
    
    /// <summary>
    /// Nếu true = Budget mặc định áp dụng cho mọi tháng
    /// Nếu false = Budget cho tháng cụ thể (StartDate/EndDate)
    /// </summary>
    public bool IsRecurring { get; set; } = false;
}

/// <summary>
/// Request cập nhật ngân sách
/// </summary>
public class UpdateBudgetRequest
{
    public decimal? AmountLimit { get; set; }
    public Guid? CategoryId { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public bool? IsRecurring { get; set; }
}

// ===== RESPONSE DTOs =====

/// <summary>
/// Response trả về thông tin ngân sách
/// </summary>
public class BudgetResponse
{
    public Guid Id { get; set; }
    
    /// <summary>
    /// Hạn mức
    /// </summary>
    public decimal AmountLimit { get; set; }
    
    /// <summary>
    /// Đã chi tiêu (tính từ Transaction)
    /// </summary>
    public decimal AmountSpent { get; set; }
    
    /// <summary>
    /// Còn lại
    /// </summary>
    public decimal AmountRemaining { get; set; }
    
    /// <summary>
    /// Phần trăm đã sử dụng (0-100+)
    /// </summary>
    public double PercentUsed { get; set; }
    
    /// <summary>
    /// Cảnh báo khi > 80%
    /// </summary>
    public bool IsWarning { get; set; }
    
    /// <summary>
    /// Vượt quá khi > 100%
    /// </summary>
    public bool IsExceeded { get; set; }
    
    /// <summary>
    /// Budget mặc định cho mọi tháng hay cho tháng cụ thể
    /// </summary>
    public bool IsRecurring { get; set; }
    
    // Category info - Null nếu là ngân sách tổng
    public Guid? CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? CategoryIcon { get; set; }
    
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    
    public DateTime CreatedAt { get; set; }
    public DateTime LastUpdatedAt { get; set; }
}

/// <summary>
/// Response cảnh báo ngân sách
/// </summary>
public class BudgetWarningResponse
{
    public List<BudgetResponse> WarningBudgets { get; set; } = new();
    public List<BudgetResponse> ExceededBudgets { get; set; } = new();
    public int TotalWarnings { get; set; }
    public int TotalExceeded { get; set; }
}

// ===== ANALYTICS DTOs =====

/// <summary>
/// Budget history for a specific month
/// </summary>
public class BudgetHistoryItem
{
    public int Year { get; set; }
    public int Month { get; set; }
    public string MonthName { get; set; } = string.Empty;
    public decimal BudgetLimit { get; set; }
    public decimal AmountSpent { get; set; }
    public decimal AmountRemaining { get; set; }
    public double PercentUsed { get; set; }
    public bool WasExceeded { get; set; }
}

/// <summary>
/// Budget history response
/// </summary>
public class BudgetHistoryResponse
{
    public List<BudgetHistoryItem> History { get; set; } = new();
    public decimal AverageMonthlySpending { get; set; }
    public decimal AverageMonthlyBudget { get; set; }
    public int MonthsExceeded { get; set; }
    public int TotalMonths { get; set; }
}

/// <summary>
/// Budget analytics by category
/// </summary>
public class CategoryBudgetAnalytics
{
    public Guid? CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? CategoryIcon { get; set; }
    public decimal TotalBudget { get; set; }
    public decimal TotalSpent { get; set; }
    public double PercentUsed { get; set; }
    public decimal AverageMonthlySpent { get; set; }
}

/// <summary>
/// Budget analytics response
/// </summary>
public class BudgetAnalyticsResponse
{
    // Summary
    public decimal TotalBudgetThisMonth { get; set; }
    public decimal TotalSpentThisMonth { get; set; }
    public decimal RemainingThisMonth { get; set; }
    public double PercentUsedThisMonth { get; set; }
    
    // Trends
    public List<BudgetHistoryItem> MonthlyTrend { get; set; } = new();
    
    // Category breakdown
    public List<CategoryBudgetAnalytics> CategoryBreakdown { get; set; } = new();
    
    // Insights
    public decimal AverageDailySpending { get; set; }
    public decimal ProjectedMonthlySpending { get; set; }
    public bool WillExceedBudget { get; set; }
    public int DaysUntilBudgetExceeded { get; set; }
    
    // Recommendations
    public decimal SuggestedDailyLimit { get; set; }
    public string? InsightMessage { get; set; }
}

/// <summary>
/// Smart budget suggestion based on spending history
/// </summary>
public class BudgetSuggestion
{
    public Guid? CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public decimal SuggestedAmount { get; set; }
    public decimal AverageSpent { get; set; }
    public decimal MinSpent { get; set; }
    public decimal MaxSpent { get; set; }
    public string Reason { get; set; } = string.Empty;
}
