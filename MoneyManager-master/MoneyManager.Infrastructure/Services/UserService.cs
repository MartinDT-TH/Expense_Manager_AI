using Microsoft.AspNetCore.Identity;
using MoneyManager.Application.DTOs.User;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;

namespace MoneyManager.Infrastructure.Services;

public class UserService : IUserService
{
    private readonly UserManager<AppUser> _userManager;

    public UserService(UserManager<AppUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task<UserProfileResponse> GetProfileAsync(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null)
        {
            return new UserProfileResponse
            {
                Success = false,
                Message = "User không tồn tại."
            };
        }

        var roles = await _userManager.GetRolesAsync(user);
        var hasPassword = await _userManager.HasPasswordAsync(user);

        return new UserProfileResponse
        {
            Success = true,
            Profile = MapToProfileDto(user, roles.FirstOrDefault() ?? "Member", hasPassword)
        };
    }

    public async Task<UserProfileResponse> UpdateProfileAsync(Guid userId, UpdateProfileRequest request)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null)
        {
            return new UserProfileResponse
            {
                Success = false,
                Message = "User không tồn tại."
            };
        }

        // Update fields
        if (!string.IsNullOrEmpty(request.FullName))
            user.FullName = request.FullName;
        
        if (request.Phone != null)
            user.Phone = request.Phone;
        
        if (request.Address != null)
            user.Address = request.Address;

        user.UpdatedAt = DateTime.UtcNow;

        var result = await _userManager.UpdateAsync(user);
        if (!result.Succeeded)
        {
            return new UserProfileResponse
            {
                Success = false,
                Message = string.Join(", ", result.Errors.Select(e => e.Description))
            };
        }

        var roles = await _userManager.GetRolesAsync(user);
        var hasPassword = await _userManager.HasPasswordAsync(user);

        return new UserProfileResponse
        {
            Success = true,
            Message = "Cập nhật profile thành công.",
            Profile = MapToProfileDto(user, roles.FirstOrDefault() ?? "Member", hasPassword)
        };
    }

    public async Task<ProfileOperationResponse> ChangePasswordAsync(Guid userId, ChangePasswordRequest request)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null)
        {
            return new ProfileOperationResponse
            {
                Success = false,
                Message = "User không tồn tại."
            };
        }

        // Check if user has password (might be Google-only account)
        var hasPassword = await _userManager.HasPasswordAsync(user);
        
        if (!hasPassword)
        {
            // Add password for Google-only account
            var addResult = await _userManager.AddPasswordAsync(user, request.NewPassword);
            if (!addResult.Succeeded)
            {
                return new ProfileOperationResponse
                {
                    Success = false,
                    Message = string.Join(", ", addResult.Errors.Select(e => e.Description))
                };
            }
            
            return new ProfileOperationResponse
            {
                Success = true,
                Message = "Đã thêm mật khẩu cho tài khoản."
            };
        }

        // Change existing password
        var result = await _userManager.ChangePasswordAsync(user, request.CurrentPassword, request.NewPassword);
        if (!result.Succeeded)
        {
            return new ProfileOperationResponse
            {
                Success = false,
                Message = result.Errors.Any(e => e.Code == "PasswordMismatch") 
                    ? "Mật khẩu hiện tại không đúng."
                    : string.Join(", ", result.Errors.Select(e => e.Description))
            };
        }

        user.UpdatedAt = DateTime.UtcNow;
        await _userManager.UpdateAsync(user);

        return new ProfileOperationResponse
        {
            Success = true,
            Message = "Đổi mật khẩu thành công."
        };
    }

    public async Task<UserProfileResponse> UpdateAvatarAsync(Guid userId, string avatarUrl)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null)
        {
            return new UserProfileResponse
            {
                Success = false,
                Message = "User không tồn tại."
            };
        }

        user.AvatarUrl = avatarUrl;
        user.UpdatedAt = DateTime.UtcNow;

        var result = await _userManager.UpdateAsync(user);
        if (!result.Succeeded)
        {
            return new UserProfileResponse
            {
                Success = false,
                Message = string.Join(", ", result.Errors.Select(e => e.Description))
            };
        }

        var roles = await _userManager.GetRolesAsync(user);
        var hasPassword = await _userManager.HasPasswordAsync(user);

        return new UserProfileResponse
        {
            Success = true,
            Message = "Cập nhật avatar thành công.",
            Profile = MapToProfileDto(user, roles.FirstOrDefault() ?? "Member", hasPassword)
        };
    }

    public async Task<ProfileOperationResponse> DeleteAvatarAsync(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null)
        {
            return new ProfileOperationResponse
            {
                Success = false,
                Message = "User không tồn tại."
            };
        }

        user.AvatarUrl = null;
        user.UpdatedAt = DateTime.UtcNow;

        var result = await _userManager.UpdateAsync(user);
        if (!result.Succeeded)
        {
            return new ProfileOperationResponse
            {
                Success = false,
                Message = string.Join(", ", result.Errors.Select(e => e.Description))
            };
        }

        return new ProfileOperationResponse
        {
            Success = true,
            Message = "Đã xóa avatar."
        };
    }

    private static UserProfileDto MapToProfileDto(AppUser user, string role, bool hasPassword)
    {
        return new UserProfileDto
        {
            Id = user.Id,
            Email = user.Email!,
            FullName = user.FullName,
            Phone = user.Phone,
            Address = user.Address,
            AvatarUrl = user.AvatarUrl,
            Role = role,
            IsPremium = user.IsPremium,
            PremiumExpiryDate = user.PremiumExpiryDate,
            TwoFactorEnabled = user.TwoFactorEnabled,
            IsGoogleLinked = user.IsGoogleLinked,
            GoogleEmail = user.GoogleEmail,
            HasPassword = hasPassword,
            CreatedAt = user.CreatedAt,
            UpdatedAt = user.UpdatedAt
        };
    }
}
