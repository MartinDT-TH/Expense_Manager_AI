using MoneyManager.Application.DTOs.Auth;

namespace MoneyManager.Application.Interfaces
{
    public interface IAuthService
    {
        // Basic Auth
        Task<AuthResponse> RegisterAsync(RegisterRequest request);
        Task<AuthResponse> LoginAsync(LoginRequest request);
        
        // Email Verification
        Task<bool> SendVerificationEmailAsync(string email);
        Task<AuthResponse> ConfirmEmailAsync(string token, string email);
        Task<bool> ResendVerificationEmailAsync(string email);
        
        // Google OAuth
        Task<AuthResponse> GoogleLoginAsync(GoogleAuthRequest request);
        Task<AuthResponse> LinkGoogleAccountAsync(Guid userId, LinkGoogleRequest request);
        Task<bool> UnlinkGoogleAccountAsync(Guid userId);
        
        // Two-Factor Authentication
        Task<TwoFactorSetupResponse> SetupTwoFactorAsync(Guid userId);
        Task<AuthResponse> VerifyTwoFactorAsync(string twoFactorToken, VerifyOtpRequest request);
        Task<bool> DisableTwoFactorAsync(Guid userId, string code);
        Task<bool> IsTwoFactorEnabledAsync(Guid userId);
        
        // Email OTP (fallback 2FA method)
        Task<bool> SendEmailOtpAsync(string email);
        Task<AuthResponse> VerifyEmailOtpAsync(VerifyEmailOtpRequest request);
        
        // Refresh Token
        Task<TokenResponse> RefreshTokenAsync(RefreshTokenRequest request);
        Task<bool> RevokeTokenAsync(Guid userId);
        
        // Token validation
        Task<UserDto?> GetUserFromTokenAsync(string token);
    }
}