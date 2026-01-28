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
