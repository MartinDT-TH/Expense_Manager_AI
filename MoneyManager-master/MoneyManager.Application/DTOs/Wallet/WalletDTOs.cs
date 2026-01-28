namespace MoneyManager.Application.DTOs.Wallet;

// ===== REQUEST DTOs =====

/// <summary>
/// Request tạo ví mới
/// </summary>
public class CreateWalletRequest
{
    /// <summary>
    /// ID do Client gen (GUID) - Hỗ trợ offline-first
    /// </summary>
    public Guid? Id { get; set; }
    
    /// <summary>
    /// Tên ví (VD: "Ví tiền mặt", "Vietcombank", "Momo")
    /// </summary>
    public string Name { get; set; } = string.Empty;
    
    /// <summary>
    /// Loại ví: CASH, BANK, EWALLET, CREDIT_CARD, OTHER
    /// </summary>
    public string Type { get; set; } = "CASH";
    
    /// <summary>
    /// Số dư ban đầu
    /// </summary>
    public decimal InitialBalance { get; set; } = 0;
    
    /// <summary>
    /// Đơn vị tiền tệ: VND, USD, EUR...
    /// </summary>
    public string Currency { get; set; } = "VND";
}

/// <summary>
/// Request cập nhật ví
/// </summary>
public class UpdateWalletRequest
{
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string Currency { get; set; } = "VND";
    
    /// <summary>
    /// Điều chỉnh số dư (nếu cần)
    /// </summary>
    public decimal? AdjustedBalance { get; set; }
}

// ===== RESPONSE DTOs =====

/// <summary>
/// Response trả về thông tin ví
/// </summary>
public class WalletResponse
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    
    /// <summary>
    /// Số dư ban đầu khi tạo ví
    /// </summary>
    public decimal InitialBalance { get; set; }
    
    /// <summary>
    /// Số dư hiện tại = InitialBalance + Income - Expense
    /// </summary>
    public decimal Balance { get; set; }
    
    public string Currency { get; set; } = "VND";
    public DateTime CreatedAt { get; set; }
    public DateTime LastUpdatedAt { get; set; }
    public bool IsDeleted { get; set; }
}

/// <summary>
/// Response tổng số dư tất cả ví
/// </summary>
public class TotalBalanceResponse
{
    /// <summary>
    /// Tổng số dư (theo từng loại tiền tệ)
    /// </summary>
    public List<CurrencyBalance> Balances { get; set; } = new();
    
    /// <summary>
    /// Số lượng ví đang hoạt động
    /// </summary>
    public int WalletCount { get; set; }
}

public class CurrencyBalance
{
    public string Currency { get; set; } = "VND";
    public decimal TotalBalance { get; set; }
}
