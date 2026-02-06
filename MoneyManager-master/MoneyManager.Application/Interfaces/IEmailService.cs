namespace MoneyManager.Application.Interfaces;

public interface IEmailService
{
    /// <summary>
    /// Send email verification link to user
    /// </summary>
    Task<bool> SendEmailVerificationAsync(string email, string fullName, string verificationLink);
    
    /// <summary>
    /// Send password reset email
    /// </summary>
    Task<bool> SendPasswordResetAsync(string email, string fullName, string resetLink);
    
    /// <summary>
    /// Send OTP code to email
    /// </summary>
    Task<bool> SendOtpAsync(string email, string otpCode, int expiryMinutes = 10);
    
    /// <summary>
    /// Send welcome email after successful verification
    /// </summary>
    Task<bool> SendWelcomeEmailAsync(string email, string fullName);
    
    /// <summary>
    /// Send premium subscription confirmation
    /// </summary>
    Task<bool> SendPremiumConfirmationAsync(string email, string fullName, DateTime expiryDate);
}
