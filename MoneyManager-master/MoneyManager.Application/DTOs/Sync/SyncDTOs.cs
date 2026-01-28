namespace MoneyManager.Application.DTOs.Sync;

// ===== REQUEST DTOs =====

/// <summary>
/// Request đồng bộ dữ liệu từ Server xuống Client
/// </summary>
public class SyncPullRequest
{
    /// <summary>
    /// Thời điểm đồng bộ lần cuối (UTC)
    /// Client gửi lên để server chỉ trả về dữ liệu mới hơn
    /// </summary>
    public DateTime? LastSyncedAt { get; set; }
    
    /// <summary>
    /// Các entity cần pull
    /// Nếu null = pull tất cả
    /// </summary>
    public List<string>? EntityTypes { get; set; }
}

/// <summary>
/// Request đẩy dữ liệu từ Client lên Server
/// </summary>
public class SyncPushRequest
{
    /// <summary>
    /// Danh sách Wallet cần sync
    /// </summary>
    public List<SyncWalletItem>? Wallets { get; set; }
    
    /// <summary>
    /// Danh sách Category cần sync
    /// </summary>
    public List<SyncCategoryItem>? Categories { get; set; }
    
    /// <summary>
    /// Danh sách Transaction cần sync
    /// </summary>
    public List<SyncTransactionItem>? Transactions { get; set; }
    
    /// <summary>
    /// Danh sách Budget cần sync
    /// </summary>
    public List<SyncBudgetItem>? Budgets { get; set; }
}

// ===== SYNC ITEM DTOs =====

public class SyncWalletItem
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Balance { get; set; }
    public string Currency { get; set; } = "VND";
    public string? Type { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime LastUpdatedAt { get; set; }
}

public class SyncCategoryItem
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty; // Expense, Income
    public string? IconCode { get; set; }
    public Guid? ParentId { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime LastUpdatedAt { get; set; }
}

public class SyncTransactionItem
{
    public Guid Id { get; set; }
    public decimal Amount { get; set; }
    public string? Note { get; set; }
    public DateTime TransactionDate { get; set; }
    public Guid WalletId { get; set; }
    public Guid CategoryId { get; set; }
    public Guid? GroupId { get; set; }
    public string? BillImageUrl { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime LastUpdatedAt { get; set; }
}

public class SyncBudgetItem
{
    public Guid Id { get; set; }
    public Guid? CategoryId { get; set; } // Nullable - null means monthly budget
    public decimal AmountLimit { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public bool IsRecurring { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime LastUpdatedAt { get; set; }
}

// ===== RESPONSE DTOs =====

/// <summary>
/// Response trả về dữ liệu đồng bộ
/// </summary>
public class SyncPullResponse
{
    /// <summary>
    /// Timestamp của server khi xử lý request
    /// Client lưu lại để dùng cho lần sync tiếp theo
    /// </summary>
    public DateTime ServerTimestamp { get; set; }
    
    /// <summary>
    /// Có thay đổi hay không
    /// </summary>
    public bool HasChanges { get; set; }
    
    public SyncData Data { get; set; } = new();
}

public class SyncData
{
    public List<SyncWalletItem> Wallets { get; set; } = new();
    public List<SyncCategoryItem> Categories { get; set; } = new();
    public List<SyncTransactionItem> Transactions { get; set; } = new();
    public List<SyncBudgetItem> Budgets { get; set; } = new();
}

/// <summary>
/// Response sau khi push dữ liệu
/// </summary>
public class SyncPushResponse
{
    public bool Success { get; set; }
    public int WalletsSynced { get; set; }
    public int CategoriesSynced { get; set; }
    public int TransactionsSynced { get; set; }
    public int BudgetsSynced { get; set; }
    
    /// <summary>
    /// Danh sách các conflict (nếu có)
    /// </summary>
    public List<SyncConflict> Conflicts { get; set; } = new();
    
    /// <summary>
    /// Timestamp server để client cập nhật
    /// </summary>
    public DateTime ServerTimestamp { get; set; }
}

public class SyncConflict
{
    public string EntityType { get; set; } = string.Empty;
    public Guid EntityId { get; set; }
    public string Message { get; set; } = string.Empty;
    public string Resolution { get; set; } = string.Empty; // SERVER_WIN, CLIENT_WIN, MERGE
}
