using MoneyManager.Application.DTOs.User;

namespace MoneyManager.Application.Interfaces;

public interface IUserService
{
    /// <summary>
    /// Lấy thông tin profile đầy đủ của user
    /// </summary>
    Task<UserProfileResponse> GetProfileAsync(Guid userId);
    
    /// <summary>
    /// Cập nhật thông tin profile
    /// </summary>
    Task<UserProfileResponse> UpdateProfileAsync(Guid userId, UpdateProfileRequest request);
    
    /// <summary>
    /// Đổi mật khẩu
    /// </summary>
    Task<ProfileOperationResponse> ChangePasswordAsync(Guid userId, ChangePasswordRequest request);
    
    /// <summary>
    /// Cập nhật avatar
    /// </summary>
    Task<UserProfileResponse> UpdateAvatarAsync(Guid userId, string avatarUrl);
    
    /// <summary>
    /// Xóa avatar
    /// </summary>
    Task<ProfileOperationResponse> DeleteAvatarAsync(Guid userId);
}
