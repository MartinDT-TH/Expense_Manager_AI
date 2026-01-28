using MoneyManager.Application.DTOs.Wallet;

namespace MoneyManager.Application.Interfaces;

public interface IWalletService
{
    /// <summary>
    /// Lấy danh sách ví của user
    /// </summary>
    Task<List<WalletResponse>> GetWalletsAsync(Guid userId);
    
    /// <summary>
    /// Lấy chi tiết 1 ví
    /// </summary>
    Task<WalletResponse?> GetWalletByIdAsync(Guid walletId, Guid userId);
    
    /// <summary>
    /// Tạo ví mới (check Premium: max 2 ví cho Free user)
    /// </summary>
    Task<WalletResponse> CreateWalletAsync(CreateWalletRequest request, Guid userId, bool isPremium);
    
    /// <summary>
    /// Cập nhật ví
    /// </summary>
    Task<WalletResponse> UpdateWalletAsync(Guid walletId, UpdateWalletRequest request, Guid userId);
    
    /// <summary>
    /// Xóa mềm ví (IsDeleted = true)
    /// </summary>
    Task<bool> DeleteWalletAsync(Guid walletId, Guid userId);
    
    /// <summary>
    /// Lấy tổng số dư tất cả ví
    /// </summary>
    Task<TotalBalanceResponse> GetTotalBalanceAsync(Guid userId);
    
    /// <summary>
    /// Đếm số ví đang hoạt động của user
    /// </summary>
    Task<int> CountActiveWalletsAsync(Guid userId);
}
