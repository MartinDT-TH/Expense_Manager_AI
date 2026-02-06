namespace MoneyManager.Application.DTOs.Auth;

public class AuthResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    
    /// <summary>
    /// JWT Access Token
    /// </summary>
    public string? Token { get; set; }
    
    /// <summary>
    /// Refresh Token (long-lived)
    /// </summary>
    public string? RefreshToken { get; set; }
    
    /// <summary>
    /// Access Token expiry time
    /// </summary>
    public DateTime? TokenExpiry { get; set; }
    
    /// <summary>
    /// True nếu user bật 2FA và cần verify OTP
    /// </summary>
    public bool RequiresTwoFactor { get; set; } = false;
    
    /// <summary>
    /// Temporary token để hoàn tất 2FA (chỉ có khi RequiresTwoFactor = true)
    /// </summary>
    public string? TwoFactorToken { get; set; }
    
    /// <summary>
    /// True nếu cần xác thực email (sau đăng ký)
    /// </summary>
    public bool RequiresEmailVerification { get; set; } = false;
    
    public UserDto? User { get; set; }
}

public class UserDto
{
    public Guid Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string? FullName { get; set; }
    public bool IsPremium { get; set; }
    public string? AvatarUrl { get; set; }
    public string Role { get; set; } = "Member";
    
    /// <summary>
    /// True nếu user đã bật 2FA
    /// </summary>
    public bool TwoFactorEnabled { get; set; } = false;
    
    /// <summary>
    /// True nếu tài khoản liên kết với Google
    /// </summary>
    public bool IsGoogleLinked { get; set; } = false;
}