namespace MoneyManager.Application.DTOs.Auth;

/// <summary>
/// Response khi setup 2FA - chứa QR code và backup codes
/// </summary>
public class TwoFactorSetupResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    
    /// <summary>
    /// Secret key để nhập thủ công vào authenticator app
    /// </summary>
    public string? Secret { get; set; }
    
    /// <summary>
    /// URL cho QR code (otpauth://totp/...)
    /// </summary>
    public string? QrCodeUrl { get; set; }
    
    /// <summary>
    /// Mã backup codes (10 mã, mỗi mã dùng 1 lần)
    /// </summary>
    public List<string>? BackupCodes { get; set; }
}

/// <summary>
/// Request verify OTP code
/// </summary>
public class VerifyOtpRequest
{
    /// <summary>
    /// 6-digit OTP code từ authenticator app
    /// </summary>
    public string Code { get; set; } = string.Empty;
    
    /// <summary>
    /// True nếu đang confirm setup 2FA lần đầu
    /// </summary>
    public bool IsSetupConfirmation { get; set; } = false;
}

/// <summary>
/// Request gửi OTP qua email
/// </summary>
public class SendEmailOtpRequest
{
    public string Email { get; set; } = string.Empty;
}

/// <summary>
/// Request verify email OTP
/// </summary>
public class VerifyEmailOtpRequest
{
    public string Email { get; set; } = string.Empty;
    public string Code { get; set; } = string.Empty;
}

/// <summary>
/// Response cho 2FA verification
/// </summary>
public class TwoFactorVerifyResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public bool TwoFactorRequired { get; set; } = false;
    
    /// <summary>
    /// Temporary token để hoàn tất 2FA (chỉ có khi TwoFactorRequired = true)
    /// </summary>
    public string? TempToken { get; set; }
}
