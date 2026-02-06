namespace MoneyManager.Application.DTOs.Auth;

/// <summary>
/// Request để refresh JWT token
/// </summary>
public class RefreshTokenRequest
{
    /// <summary>
    /// Access token hiện tại (có thể đã expired)
    /// </summary>
    public string AccessToken { get; set; } = string.Empty;
    
    /// <summary>
    /// Refresh token (long-lived)
    /// </summary>
    public string RefreshToken { get; set; } = string.Empty;
}

/// <summary>
/// Response chứa cặp token mới
/// </summary>
public class TokenResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public string? AccessToken { get; set; }
    public string? RefreshToken { get; set; }
    public DateTime? AccessTokenExpiry { get; set; }
    public DateTime? RefreshTokenExpiry { get; set; }
}
