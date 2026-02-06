namespace MoneyManager.Application.DTOs.Auth;

/// <summary>
/// Request từ Flutter gửi Google ID Token
/// </summary>
public class GoogleAuthRequest
{
    /// <summary>
    /// ID Token từ Google Sign-In (Flutter sẽ gửi)
    /// </summary>
    public string IdToken { get; set; } = string.Empty;
    
    /// <summary>
    /// Access Token (optional, for additional API calls)
    /// </summary>
    public string? AccessToken { get; set; }
}

/// <summary>
/// Request để link tài khoản Google với tài khoản hiện tại
/// </summary>
public class LinkGoogleRequest
{
    public string IdToken { get; set; } = string.Empty;
}
