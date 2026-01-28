namespace MoneyManager.Application.DTOs.Transaction;

// ===== REQUEST DTOs =====

/// <summary>
/// Request tạo giao dịch mới
/// </summary>
public class CreateTransactionRequest
{
    /// <summary>
    /// ID do Client gen (GUID) - Hỗ trợ offline-first
    /// </summary>
    public Guid? Id { get; set; }
    
    /// <summary>
    /// Số tiền (luôn dương, Type của Category quyết định Thu/Chi)
    /// </summary>
    public decimal Amount { get; set; }
    
    /// <summary>
    /// ID danh mục
    /// </summary>
    public Guid CategoryId { get; set; }
    
    /// <summary>
    /// ID ví thanh toán
    /// </summary>
    public Guid WalletId { get; set; }
    
    /// <summary>
    /// Ghi chú
    /// </summary>
    public string? Note { get; set; }
    
    /// <summary>
    /// Ngày giao dịch (mặc định = Today)
    /// </summary>
    public DateTime TransactionDate { get; set; } = DateTime.Today;
    
    /// <summary>
    /// ID nhóm (nếu là giao dịch nhóm)
    /// </summary>
    public Guid? GroupId { get; set; }
    
    /// <summary>
    /// URL ảnh hóa đơn (Premium feature)
    /// </summary>
    public string? BillImageUrl { get; set; }
    
    /// <summary>
    /// Dữ liệu OCR thô (Premium feature)
    /// </summary>
    public string? OcrRawData { get; set; }
}

/// <summary>
/// Request cập nhật giao dịch
/// </summary>
public class UpdateTransactionRequest
{
    public decimal? Amount { get; set; }
    public Guid? CategoryId { get; set; }
    public Guid? WalletId { get; set; }
    public string? Note { get; set; }
    public DateTime? TransactionDate { get; set; }
    public Guid? GroupId { get; set; }
    public string? BillImageUrl { get; set; }
}

/// <summary>
/// Request filter danh sách giao dịch
/// </summary>
public class TransactionFilterRequest
{
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public Guid? WalletId { get; set; }
    public Guid? CategoryId { get; set; }
    public string? Type { get; set; } // EXPENSE, INCOME
    public Guid? GroupId { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

// ===== RESPONSE DTOs =====

/// <summary>
/// Response trả về thông tin giao dịch
/// </summary>
public class TransactionResponse
{
    public Guid Id { get; set; }
    public decimal Amount { get; set; }
    
    // Category info
    public Guid CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string? CategoryIcon { get; set; }
    public string CategoryType { get; set; } = string.Empty; // EXPENSE, INCOME
    
    // Wallet info
    public Guid WalletId { get; set; }
    public string WalletName { get; set; } = string.Empty;
    
    public string? Note { get; set; }
    public DateTime TransactionDate { get; set; }
    
    // Group info (nếu có)
    public Guid? GroupId { get; set; }
    public string? GroupName { get; set; }
    
    // Premium features
    public string? BillImageUrl { get; set; }
    
    // User info
    public Guid CreatedByUserId { get; set; }
    public string? CreatedByUserName { get; set; }
    
    // Sync info
    public DateTime CreatedAt { get; set; }
    public DateTime LastUpdatedAt { get; set; }
    public bool IsDeleted { get; set; }
}

/// <summary>
/// Response danh sách giao dịch có phân trang
/// </summary>
public class TransactionListResponse
{
    public List<TransactionResponse> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
    public int TotalPages { get; set; }
    
    /// <summary>
    /// Tổng thu trong khoảng filter
    /// </summary>
    public decimal TotalIncome { get; set; }
    
    /// <summary>
    /// Tổng chi trong khoảng filter
    /// </summary>
    public decimal TotalExpense { get; set; }
}

/// <summary>
/// Response OCR hóa đơn
/// </summary>
public class OcrResultResponse
{
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
    
    /// <summary>
    /// Số tiền nhận diện được
    /// </summary>
    public decimal? Amount { get; set; }
    
    /// <summary>
    /// Ngày nhận diện được
    /// </summary>
    public DateTime? Date { get; set; }
    
    /// <summary>
    /// Nội dung/Note nhận diện được
    /// </summary>
    public string? Description { get; set; }
    
    /// <summary>
    /// Tên cửa hàng/đơn vị
    /// </summary>
    public string? MerchantName { get; set; }
    
    /// <summary>
    /// Dữ liệu thô từ OCR (JSON)
    /// </summary>
    public string? RawData { get; set; }
    
    /// <summary>
    /// Gợi ý danh mục
    /// </summary>
    public Guid? SuggestedCategoryId { get; set; }
    public string? SuggestedCategoryName { get; set; }
}
