using MoneyManager.Application.DTOs.Sync;

namespace MoneyManager.Application.Interfaces;

public interface ISyncService
{
    /// <summary>
    /// Kéo dữ liệu mới từ server
    /// </summary>
    Task<SyncPullResponse> PullAsync(SyncPullRequest request, Guid userId);
    
    /// <summary>
    /// Đẩy dữ liệu từ client lên server
    /// </summary>
    Task<SyncPushResponse> PushAsync(SyncPushRequest request, Guid userId, bool isPremium);
    
    /// <summary>
    /// Lấy timestamp lần sync cuối
    /// </summary>
    Task<DateTime?> GetLastSyncTimeAsync(Guid userId);
}
