using System.ComponentModel.DataAnnotations;

namespace MoneyManager.Application.DTOs.User;

#region Request DTOs

/// <summary>
/// Request để cập nhật thông tin profile
/// </summary>
public class UpdateProfileRequest
{
    [MaxLength(100)]
    public string? FullName { get; set; }
    
    [Phone]
    [MaxLength(20)]
    public string? Phone { get; set; }
    
    [MaxLength(500)]
    public string? Address { get; set; }
}

/// <summary>
/// Request để đổi mật khẩu
/// </summary>
public class ChangePasswordRequest
{
    [Required(ErrorMessage = "Mật khẩu hiện tại là bắt buộc")]
    public string CurrentPassword { get; set; } = string.Empty;
    
    [Required(ErrorMessage = "Mật khẩu mới là bắt buộc")]
    [MinLength(6, ErrorMessage = "Mật khẩu phải có ít nhất 6 ký tự")]
    public string NewPassword { get; set; } = string.Empty;
    
    [Required(ErrorMessage = "Xác nhận mật khẩu là bắt buộc")]
    [Compare(nameof(NewPassword), ErrorMessage = "Mật khẩu xác nhận không khớp")]
    public string ConfirmPassword { get; set; } = string.Empty;
}

/// <summary>
/// Request để upload avatar
/// </summary>
public class UploadAvatarRequest
{
    /// <summary>
    /// Base64 encoded image hoặc URL
    /// </summary>
    public string? ImageData { get; set; }
    
    /// <summary>
    /// Cloudinary URL nếu đã upload từ client
    /// </summary>
    public string? AvatarUrl { get; set; }
}

#endregion

#region Response DTOs

/// <summary>
/// Response chứa thông tin profile đầy đủ
/// </summary>
public class UserProfileResponse
{
    public bool Success { get; set; }
    public string? Message { get; set; }
    public UserProfileDto? Profile { get; set; }
}

/// <summary>
/// DTO chứa thông tin user đầy đủ
/// </summary>
public class UserProfileDto
{
    public Guid Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string? FullName { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? AvatarUrl { get; set; }
    public string Role { get; set; } = "Member";
    public bool IsPremium { get; set; }
    public DateTime? PremiumExpiryDate { get; set; }
    
    // Security status
    public bool TwoFactorEnabled { get; set; }
    public bool IsGoogleLinked { get; set; }
    public string? GoogleEmail { get; set; }
    public bool HasPassword { get; set; }
    
    // Timestamps
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>
/// Response cơ bản cho các operations
/// </summary>
public class ProfileOperationResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
}

#endregion
