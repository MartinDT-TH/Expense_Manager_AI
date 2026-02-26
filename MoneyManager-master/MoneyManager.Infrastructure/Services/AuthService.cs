using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using MoneyManager.Application.DTOs.Auth;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Web;
using Google.Apis.Auth;

namespace MoneyManager.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly UserManager<AppUser> _userManager;
    private readonly SignInManager<AppUser> _signInManager;
    private readonly IConfiguration _configuration;
    private readonly IMemoryCache _cache;
    private readonly IEmailService _emailService;
    private readonly ILogger<AuthService> _logger;
    
    // Token lifetimes
    private const int AccessTokenExpiryMinutes = 60; // 1 hour
    private const int RefreshTokenExpiryDays = 30;
    private const int TwoFactorTokenExpiryMinutes = 5;
    private const int EmailOtpExpiryMinutes = 10;
    private const int EmailVerificationTokenExpiryHours = 24;

    public AuthService(
        UserManager<AppUser> userManager,
        SignInManager<AppUser> signInManager,
        IConfiguration configuration,
        IMemoryCache cache,
        IEmailService emailService,
        ILogger<AuthService> logger)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _configuration = configuration;
        _cache = cache;
        _emailService = emailService;
        _logger = logger;
    }

    #region Basic Auth

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request)
    {
        var existingUser = await _userManager.FindByEmailAsync(request.Email);
        if (existingUser != null)
        {
            return new AuthResponse { Success = false, Message = "Email đã được sử dụng." };
        }

        var user = new AppUser
        {
            UserName = request.Email,
            Email = request.Email,
            FullName = request.FullName,
            EmailConfirmed = false, // Require email verification
            IsActive = false, // Inactive until verified
            IsPremium = false, // Default to free tier
            CreatedAt = DateTime.UtcNow
        };

        var result = await _userManager.CreateAsync(user, request.Password);

        if (!result.Succeeded)
        {
            return new AuthResponse
            {
                Success = false,
                Message = string.Join(", ", result.Errors.Select(e => e.Description))
            };
        }

        await _userManager.AddToRoleAsync(user, "Member");
        
        // Send verification email
        var emailSent = await SendVerificationEmailAsync(request.Email);
        
        if (!emailSent)
        {
            _logger.LogWarning("Failed to send verification email to {Email}", request.Email);
        }

        return new AuthResponse
        {
            Success = true,
            Message = "Đăng ký thành công! Vui lòng kiểm tra email để xác thực tài khoản.",
            RequiresEmailVerification = true,
            User = new UserDto
            {
                Id = user.Id,
                Email = user.Email!,
                FullName = user.FullName,
                IsPremium = user.IsPremium,
                AvatarUrl = user.AvatarUrl
            }
        };
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request)
    {
        var user = await _userManager.FindByEmailAsync(request.Email);

        if (user == null)
        {
            return new AuthResponse { Success = false, Message = "Email hoặc mật khẩu không đúng." };
        }

        if (!user.IsActive)
        {
            return new AuthResponse
            {
                Success = false,
                Message = "TÃ i khoáº£n chÆ°a Ä‘Æ°á»£c kÃ­ch hoáº¡t. Vui lÃ²ng xÃ¡c thá»±c email trÆ°á»›c khi Ä‘Äƒng nháº­p.",
                RequiresEmailVerification = true,
                User = new UserDto
                {
                    Id = user.Id,
                    Email = user.Email!,
                    FullName = user.FullName
                }
            };
        }

        var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, false);

        if (!result.Succeeded)
        {
            return new AuthResponse { Success = false, Message = "Email hoặc mật khẩu không đúng." };
        }

        // Check if email is confirmed
        if (!user.EmailConfirmed)
        {
            return new AuthResponse
            {
                Success = false,
                Message = "Vui lòng xác thực email trước khi đăng nhập. Kiểm tra hộp thư của bạn.",
                RequiresEmailVerification = true,
                User = new UserDto
                {
                    Id = user.Id,
                    Email = user.Email!,
                    FullName = user.FullName
                }
            };
        }

        // Check if 2FA is enabled
        if (user.TwoFactorEnabled)
        {
            var twoFactorToken = GenerateTwoFactorToken(user.Id);
            return new AuthResponse
            {
                Success = true,
                Message = "Vui lòng nhập mã OTP.",
                RequiresTwoFactor = true,
                TwoFactorToken = twoFactorToken
            };
        }

        return await GenerateAuthResponseAsync(user, "Đăng nhập thành công!");
    }

    #endregion

    #region Email Verification

    public async Task<bool> SendVerificationEmailAsync(string email)
    {
        try
        {
            var user = await _userManager.FindByEmailAsync(email);
            if (user == null)
            {
                _logger.LogWarning("SendVerificationEmail: Kh�ng t�m th?y ngu?i d�ng for email {Email}", email);
                return false;
            }

            if (user.EmailConfirmed)
            {
                _logger.LogInformation("Email already confirmed for {Email}", email);
                return true;
            }

            // Generate email confirmation token using Identity
            var token = await _userManager.GenerateEmailConfirmationTokenAsync(user);
            
            // URL encode the token
            var encodedToken = HttpUtility.UrlEncode(token);
            
            // Build verification link
            var baseUrl = _configuration["App:BaseUrl"] ?? "https://moneymanager.app";
            var verificationLink = $"{baseUrl}/api/Auth/confirm-email?token={encodedToken}&email={HttpUtility.UrlEncode(email)}";

            // For mobile deep link (alternative)
            var mobileDeepLink = $"moneymanager://confirm-email?token={encodedToken}&email={HttpUtility.UrlEncode(email)}";

            // Send email
            var sent = await _emailService.SendEmailVerificationAsync(
                email, 
                user.FullName ?? "User", 
                verificationLink);

            if (sent)
            {
                _logger.LogInformation("Verification email sent to {Email}", email);
            }

            return sent;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending verification email to {Email}", email);
            return false;
        }
    }

    public async Task<AuthResponse> ConfirmEmailAsync(string token, string email)
    {
        try
        {
            var user = await _userManager.FindByEmailAsync(email);
            if (user == null)
            {
                return new AuthResponse
                {
                    Success = false,
                    Message = "Không tìm thấy tài khoản với email này."
                };
            }

            if (user.EmailConfirmed)
            {
                return new AuthResponse
                {
                    Success = true,
                    Message = "Email đã được xác thực trước đó."
                };
            }

            // Verify the token using Identity
            var result = await _userManager.ConfirmEmailAsync(user, token);

            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                _logger.LogWarning("Email confirmation failed for {Email}: {Errors}", email, errors);
                
                return new AuthResponse
                {
                    Success = false,
                    Message = "Link xác thực không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu gửi lại email."
                };
            }

            _logger.LogInformation("Email confirmed successfully for {Email}", email);

            if (!user.IsActive)
            {
                user.IsActive = true;
                await _userManager.UpdateAsync(user);
            }

            // Send welcome email
            await _emailService.SendWelcomeEmailAsync(email, user.FullName ?? "User");

            // Generate tokens and return full auth response
            return await GenerateAuthResponseAsync(user, "Xác thực email thành công! Chào mừng bạn đến với Smart Money.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error confirming email for {Email}", email);
            return new AuthResponse
            {
                Success = false,
                Message = "Có lỗi xảy ra khi xác thực email. Vui lòng thử lại."
            };
        }
    }

    public async Task<bool> ResendVerificationEmailAsync(string email)
    {
        var user = await _userManager.FindByEmailAsync(email);
        if (user == null)
        {
            return false;
        }

        if (user.EmailConfirmed)
        {
            return true; // Already verified
        }

        return await SendVerificationEmailAsync(email);
    }

    #endregion

    #region Google OAuth

    public async Task<AuthResponse> GoogleLoginAsync(GoogleAuthRequest request)
    {
        try
        {
            if (string.IsNullOrEmpty(request.IdToken))
            {
                return new AuthResponse { Success = false, Message = "Thiếu ID Token." };
            }

            // Verify Google ID Token
            // Allow multiple client IDs (web/android/ios/legacy keys)
            var validAudiences = GetGoogleValidAudiences();
            if (validAudiences.Count == 0)
            {
                _logger.LogError("Google OAuth client IDs not configured. Expected keys: Google:WebClientId, Google:AndroidClientId, Google:ClientId, Google:iOSClientId.");
                return new AuthResponse
                {
                    Success = false,
                    Message = "Google Client ID is not configured. Please check appsettings/env."
                };
            }

            var payload = await GoogleJsonWebSignature.ValidateAsync(request.IdToken, new GoogleJsonWebSignature.ValidationSettings
            {
                Audience = validAudiences
            });

            // Find user by Google ID or Email
            var user = await FindUserByGoogleIdOrEmail(payload.Subject, payload.Email);

            if (user == null)
            {
                // Create new user (freemium + chưa active)
                user = new AppUser
                {
                    UserName = payload.Email,
                    Email = payload.Email,
                    EmailConfirmed = false,
                    IsActive = false,
                    FullName = payload.Name,
                    AvatarUrl = payload.Picture,
                    GoogleId = payload.Subject,
                    GoogleEmail = payload.Email,
                    IsGoogleLinked = true,
                    IsPremium = false,
                    CreatedAt = DateTime.UtcNow
                };

                var result = await _userManager.CreateAsync(user);
                if (!result.Succeeded)
                {
                    return new AuthResponse
                    {
                        Success = false,
                        Message = string.Join(", ", result.Errors.Select(e => e.Description))
                    };
                }
                
                await _userManager.AddToRoleAsync(user, "Member");

                // Send verification email for Google sign-up
                var emailSent = await SendVerificationEmailAsync(user.Email!);
                if (!emailSent)
                {
                    _logger.LogWarning("Failed to send verification email to {Email}", user.Email);
                }

                return new AuthResponse
                {
                    Success = true,
                    Message = "Đăng ký Google thành công! Vui lòng kiểm tra email để xác thực tài khoản.",
                    RequiresEmailVerification = true,
                    User = new UserDto
                    {
                        Id = user.Id,
                        Email = user.Email!,
                        FullName = user.FullName,
                        IsPremium = user.IsPremium,
                        AvatarUrl = user.AvatarUrl,
                        IsGoogleLinked = user.IsGoogleLinked
                    }
                };
            }
            else if (!user.IsGoogleLinked)
            {
                // Link Google account to existing user
                user.GoogleId = payload.Subject;
                user.GoogleEmail = payload.Email;
                user.IsGoogleLinked = true;
                if (string.IsNullOrEmpty(user.AvatarUrl))
                    user.AvatarUrl = payload.Picture;
                
                await _userManager.UpdateAsync(user);
            }

            // If email not confirmed, require verification
            if (!user.EmailConfirmed)
            {
                var emailSent = await SendVerificationEmailAsync(user.Email!);
                if (!emailSent)
                {
                    _logger.LogWarning("Failed to send verification email to {Email}", user.Email);
                }

                return new AuthResponse
                {
                    Success = false,
                    Message = "Vui lòng xác thực email trước khi đăng nhập. Kiểm tra hộp thư của bạn.",
                    RequiresEmailVerification = true,
                    User = new UserDto
                    {
                        Id = user.Id,
                        Email = user.Email!,
                        FullName = user.FullName,
                        IsPremium = user.IsPremium,
                        AvatarUrl = user.AvatarUrl,
                        IsGoogleLinked = user.IsGoogleLinked
                    }
                };
            }

            // Check if 2FA is enabled
            if (user.TwoFactorEnabled)
            {
                var twoFactorToken = GenerateTwoFactorToken(user.Id);
                return new AuthResponse
                {
                    Success = true,
                    Message = "Vui lòng nhập mã OTP.",
                    RequiresTwoFactor = true,
                    TwoFactorToken = twoFactorToken
                };
            }

            return await GenerateAuthResponseAsync(user, "Đăng nhập Google thành công!");
        }
        catch (InvalidJwtException ex)
        {
            return new AuthResponse { Success = false, Message = $"Google token không hợp lệ: {ex.Message}" };
        }
        catch (Exception ex)
        {
            return new AuthResponse { Success = false, Message = $"Lỗi xác thực Google: {ex.Message}" };
        }
    }

    public async Task<AuthResponse> LinkGoogleAccountAsync(Guid userId, LinkGoogleRequest request)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null)
            return new AuthResponse { Success = false, Message = "Người dùng không tồn tại." };

        try
        {
            // Verify Google ID Token
            // Allow multiple client IDs (web/android/ios/legacy keys)
            var validAudiences = GetGoogleValidAudiences();
            if (validAudiences.Count == 0)
            {
                _logger.LogError("Google OAuth client IDs not configured. Expected keys: Google:WebClientId, Google:AndroidClientId, Google:ClientId, Google:iOSClientId.");
                return new AuthResponse
                {
                    Success = false,
                    Message = "Google Client ID is not configured. Please check appsettings/env."
                };
            }

            var payload = await GoogleJsonWebSignature.ValidateAsync(request.IdToken, new GoogleJsonWebSignature.ValidationSettings
            {
                Audience = validAudiences
            });

            // Check if Google account is already linked to another user
            var existingUser = await FindUserByGoogleIdOrEmail(payload.Subject, null);
            if (existingUser != null && existingUser.Id != userId)
            {
                return new AuthResponse { Success = false, Message = "Tài khoản Google đã liên kết với người dùng khác." };
            }

            user.GoogleId = payload.Subject;
            user.GoogleEmail = payload.Email;
            user.IsGoogleLinked = true;
            
            await _userManager.UpdateAsync(user);

            return new AuthResponse { Success = true, Message = "Liên kết Google thành công!" };
        }
        catch (InvalidJwtException)
        {
            return new AuthResponse { Success = false, Message = "Google token không hợp lệ." };
        }
    }

    public async Task<bool> UnlinkGoogleAccountAsync(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null) return false;

        // Only allow unlink if user has password set
        if (!await _userManager.HasPasswordAsync(user))
            return false;

        user.GoogleId = null;
        user.GoogleEmail = null;
        user.IsGoogleLinked = false;
        
        await _userManager.UpdateAsync(user);
        return true;
    }

    private async Task<AppUser?> FindUserByGoogleIdOrEmail(string googleId, string? email)
    {
        // First try to find by GoogleId
        var users = _userManager.Users.Where(u => u.GoogleId == googleId);
        var user = users.FirstOrDefault();
        
        if (user == null && !string.IsNullOrEmpty(email))
        {
            user = await _userManager.FindByEmailAsync(email);
        }
        
        return user;
    }

    private List<string> GetGoogleValidAudiences()
    {
        var audiences = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        void Add(string? value)
        {
            if (!string.IsNullOrWhiteSpace(value))
            {
                audiences.Add(value.Trim());
            }
        }

        Add(_configuration["Google:WebClientId"]);
        Add(_configuration["Google:AndroidClientId"]);
        Add(_configuration["Google:ClientId"]);
        Add(_configuration["Google:iOSClientId"]);
        Add(_configuration["Google:IOSClientId"]);
        Add(_configuration["Google:WebClientID"]);
        Add(_configuration["Google:AndroidClientID"]);

        var csv = _configuration["Google:ClientIds"];
        if (!string.IsNullOrWhiteSpace(csv))
        {
            foreach (var id in csv.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                Add(id);
            }
        }

        return audiences.ToList();
    }
    #endregion

    #region Two-Factor Authentication

    public async Task<TwoFactorSetupResponse> SetupTwoFactorAsync(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null)
            return new TwoFactorSetupResponse { Success = false, Message = "Người dùng không tồn tại." };

        // Generate TOTP secret
        var secret = GenerateTotpSecret();
        var issuer = _configuration["App:Name"] ?? "MoneyManager";
        var qrCodeUrl = $"otpauth://totp/{issuer}:{user.Email}?secret={secret}&issuer={issuer}&algorithm=SHA1&digits=6&period=30";

        // Generate backup codes
        var backupCodes = GenerateBackupCodes(10);

        // Store temporarily (not enabled until verified)
        user.TwoFactorSecret = EncryptSecret(secret);
        user.BackupCodes = JsonSerializer.Serialize(backupCodes.Select(HashCode).ToList());
        await _userManager.UpdateAsync(user);

        return new TwoFactorSetupResponse
        {
            Success = true,
            Message = "Quét QR code bằng authenticator app.",
            Secret = secret,
            QrCodeUrl = qrCodeUrl,
            BackupCodes = backupCodes
        };
    }

    public async Task<AuthResponse> VerifyTwoFactorAsync(string twoFactorToken, VerifyOtpRequest request)
    {
        // Validate two-factor token
        var userId = ValidateTwoFactorToken(twoFactorToken);
        if (userId == null)
            return new AuthResponse { Success = false, Message = "Token 2FA không hợp lệ hoặc đã hết hạn." };

        var user = await _userManager.FindByIdAsync(userId.Value.ToString());
        if (user == null)
            return new AuthResponse { Success = false, Message = "Người dùng không tồn tại." };

        // Verify TOTP code
        var secret = DecryptSecret(user.TwoFactorSecret!);
        if (!ValidateTotpCode(secret, request.Code))
        {
            // Try backup codes
            if (!await ValidateAndConsumeBackupCode(user, request.Code))
            {
                return new AuthResponse { Success = false, Message = "Mã OTP không đúng." };
            }
        }

        // If this is setup confirmation, enable 2FA
        if (request.IsSetupConfirmation)
        {
            user.TwoFactorEnabled = true;
            await _userManager.UpdateAsync(user);
            return new AuthResponse { Success = true, Message = "2FA đã được bật thành công!" };
        }

        return await GenerateAuthResponseAsync(user, "Xác thực 2FA thành công!");
    }

    public async Task<bool> DisableTwoFactorAsync(Guid userId, string code)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null || !user.TwoFactorEnabled) return false;

        var secret = DecryptSecret(user.TwoFactorSecret!);
        if (!ValidateTotpCode(secret, code))
            return false;

        user.TwoFactorEnabled = false;
        user.TwoFactorSecret = null;
        user.BackupCodes = null;
        await _userManager.UpdateAsync(user);
        
        return true;
    }

    public async Task<bool> IsTwoFactorEnabledAsync(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        return user?.TwoFactorEnabled ?? false;
    }

    #endregion

    #region Email OTP

    public async Task<bool> SendEmailOtpAsync(string email)
    {
        var user = await _userManager.FindByEmailAsync(email);
        if (user == null) return false;

        var otp = GenerateOtp(6);
        var cacheKey = $"email_otp_{email}";
        
        _cache.Set(cacheKey, otp, TimeSpan.FromMinutes(EmailOtpExpiryMinutes));

        // TODO: Send email via email service
        // For now, log it (in production, use SendGrid/SES/etc)
        Console.WriteLine($"[EMAIL OTP] {email}: {otp}");

        return true;
    }

    public async Task<AuthResponse> VerifyEmailOtpAsync(VerifyEmailOtpRequest request)
    {
        var cacheKey = $"email_otp_{request.Email}";
        
        if (!_cache.TryGetValue(cacheKey, out string? storedOtp) || storedOtp != request.Code)
        {
            return new AuthResponse { Success = false, Message = "Mã OTP không đúng hoặc đã hết hạn." };
        }

        _cache.Remove(cacheKey);

        var user = await _userManager.FindByEmailAsync(request.Email);
        if (user == null)
            return new AuthResponse { Success = false, Message = "Người dùng không tồn tại." };

        return await GenerateAuthResponseAsync(user, "Xác thực email OTP thành công!");
    }

    #endregion

    #region Refresh Token

    public async Task<TokenResponse> RefreshTokenAsync(RefreshTokenRequest request)
    {
        var principal = GetPrincipalFromExpiredToken(request.AccessToken);
        if (principal == null)
            return new TokenResponse { Success = false, Message = "Access token không hợp lệ." };

        var userId = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
            return new TokenResponse { Success = false, Message = "Token không chứa user ID." };

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null || user.RefreshToken != request.RefreshToken || 
            user.RefreshTokenExpiryTime <= DateTime.UtcNow)
        {
            return new TokenResponse { Success = false, Message = "Refresh token không hợp lệ hoặc đã hết hạn." };
        }

        var (accessToken, accessExpiry) = await GenerateJwtTokenAsync(user);
        var (refreshToken, refreshExpiry) = GenerateRefreshToken();

        user.RefreshToken = refreshToken;
        user.RefreshTokenExpiryTime = refreshExpiry;
        await _userManager.UpdateAsync(user);

        return new TokenResponse
        {
            Success = true,
            Message = "Token đã được refresh.",
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            AccessTokenExpiry = accessExpiry,
            RefreshTokenExpiry = refreshExpiry
        };
    }

    public async Task<bool> RevokeTokenAsync(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null) return false;

        user.RefreshToken = null;
        user.RefreshTokenExpiryTime = null;
        await _userManager.UpdateAsync(user);
        
        return true;
    }

    public async Task<UserDto?> GetUserFromTokenAsync(string token)
    {
        var principal = GetPrincipalFromExpiredToken(token);
        if (principal == null) return null;

        var userId = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId)) return null;

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null) return null;

        var roles = await _userManager.GetRolesAsync(user);
        
        return new UserDto
        {
            Id = user.Id,
            Email = user.Email!,
            FullName = user.FullName,
            IsPremium = user.IsPremium,
            AvatarUrl = user.AvatarUrl,
            Role = roles.FirstOrDefault() ?? "Member",
            TwoFactorEnabled = user.TwoFactorEnabled,
            IsGoogleLinked = user.IsGoogleLinked
        };
    }

    #endregion

    #region Private Helpers

    private async Task<AuthResponse> GenerateAuthResponseAsync(AppUser user, string message)
    {
        var (accessToken, accessExpiry) = await GenerateJwtTokenAsync(user);
        var (refreshToken, refreshExpiry) = GenerateRefreshToken();

        user.RefreshToken = refreshToken;
        user.RefreshTokenExpiryTime = refreshExpiry;
        await _userManager.UpdateAsync(user);

        var roles = await _userManager.GetRolesAsync(user);

        return new AuthResponse
        {
            Success = true,
            Message = message,
            Token = accessToken,
            RefreshToken = refreshToken,
            TokenExpiry = accessExpiry,
            User = new UserDto
            {
                Id = user.Id,
                Email = user.Email!,
                FullName = user.FullName,
                IsPremium = user.IsPremium,
                AvatarUrl = user.AvatarUrl,
                Role = roles.FirstOrDefault() ?? "Member",
                TwoFactorEnabled = user.TwoFactorEnabled,
                IsGoogleLinked = user.IsGoogleLinked
            }
        };
    }

    private async Task<(string token, DateTime expiry)> GenerateJwtTokenAsync(AppUser user)
    {
        var roles = await _userManager.GetRolesAsync(user);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Email, user.Email!),
            new(ClaimTypes.Name, user.FullName ?? ""),
            new("IsPremium", user.IsPremium.ToString())
        };

        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var key = new SymmetricSecurityKey(
            Encoding.ASCII.GetBytes(_configuration["JwtSettings:Key"]!));
        
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expiry = DateTime.UtcNow.AddMinutes(AccessTokenExpiryMinutes);

        var token = new JwtSecurityToken(
            issuer: _configuration["JwtSettings:Issuer"],
            audience: _configuration["JwtSettings:Audience"],
            claims: claims,
            expires: expiry,
            signingCredentials: creds
        );

        return (new JwtSecurityTokenHandler().WriteToken(token), expiry);
    }

    private (string token, DateTime expiry) GenerateRefreshToken()
    {
        var randomNumber = new byte[64];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomNumber);
        
        return (
            Convert.ToBase64String(randomNumber),
            DateTime.UtcNow.AddDays(RefreshTokenExpiryDays)
        );
    }

    private ClaimsPrincipal? GetPrincipalFromExpiredToken(string token)
    {
        var tokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = false,
            ValidateIssuer = false,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.ASCII.GetBytes(_configuration["JwtSettings:Key"]!)),
            ValidateLifetime = false // Allow expired tokens
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        try
        {
            var principal = tokenHandler.ValidateToken(token, tokenValidationParameters, out var securityToken);
            
            if (securityToken is not JwtSecurityToken jwtSecurityToken ||
                !jwtSecurityToken.Header.Alg.Equals(SecurityAlgorithms.HmacSha256, 
                    StringComparison.InvariantCultureIgnoreCase))
            {
                return null;
            }

            return principal;
        }
        catch
        {
            return null;
        }
    }

    private string GenerateTwoFactorToken(Guid userId)
    {
        var data = $"{userId}:{DateTime.UtcNow.AddMinutes(TwoFactorTokenExpiryMinutes).Ticks}";
        var bytes = Encoding.UTF8.GetBytes(data);
        
        using var aes = Aes.Create();
        aes.Key = Encoding.ASCII.GetBytes(_configuration["JwtSettings:Key"]![..32]);
        aes.GenerateIV();
        
        using var encryptor = aes.CreateEncryptor();
        var encrypted = encryptor.TransformFinalBlock(bytes, 0, bytes.Length);
        
        return Convert.ToBase64String(aes.IV.Concat(encrypted).ToArray());
    }

    private Guid? ValidateTwoFactorToken(string token)
    {
        try
        {
            var bytes = Convert.FromBase64String(token);
            var iv = bytes[..16];
            var encrypted = bytes[16..];
            
            using var aes = Aes.Create();
            aes.Key = Encoding.ASCII.GetBytes(_configuration["JwtSettings:Key"]![..32]);
            aes.IV = iv;
            
            using var decryptor = aes.CreateDecryptor();
            var decrypted = decryptor.TransformFinalBlock(encrypted, 0, encrypted.Length);
            var data = Encoding.UTF8.GetString(decrypted);
            
            var parts = data.Split(':');
            var userId = Guid.Parse(parts[0]);
            var expiry = new DateTime(long.Parse(parts[1]));
            
            if (DateTime.UtcNow > expiry)
                return null;
                
            return userId;
        }
        catch
        {
            return null;
        }
    }

    // TOTP Implementation (RFC 6238)
    private static string GenerateTotpSecret()
    {
        var bytes = new byte[20];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(bytes);
        return Base32Encode(bytes);
    }

    private static bool ValidateTotpCode(string secret, string code)
    {
        if (string.IsNullOrEmpty(code) || code.Length != 6) return false;
        
        var secretBytes = Base32Decode(secret);
        var timeStep = DateTimeOffset.UtcNow.ToUnixTimeSeconds() / 30;
        
        // Check current and ±1 time steps for clock drift
        // Allow wider clock drift window (±2 steps = ±60s)
        for (var i = -1; i <= 1; i++)
        {
            var expectedCode = ComputeTotp(secretBytes, timeStep + i);
            if (expectedCode == code)
                return true;
        }
        
        return false;
    }

    private static string ComputeTotp(byte[] secret, long counter)
    {
        var counterBytes = BitConverter.GetBytes(counter);
        if (BitConverter.IsLittleEndian)
            Array.Reverse(counterBytes);
        
        using var hmac = new HMACSHA1(secret);
        var hash = hmac.ComputeHash(counterBytes);
        
        var offset = hash[^1] & 0x0f;
        var binary = ((hash[offset] & 0x7f) << 24) |
                     ((hash[offset + 1] & 0xff) << 16) |
                     ((hash[offset + 2] & 0xff) << 8) |
                     (hash[offset + 3] & 0xff);
        
        var otp = binary % 1_000_000;
        return otp.ToString("D6");
    }

    private static string Base32Encode(byte[] data)
    {
        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        var result = new StringBuilder();
        
        for (var i = 0; i < data.Length; i += 5)
        {
            var remaining = Math.Min(5, data.Length - i);
            var buffer = new byte[5];
            Array.Copy(data, i, buffer, 0, remaining);
            
            result.Append(alphabet[(buffer[0] & 0xf8) >> 3]);
            result.Append(alphabet[((buffer[0] & 0x07) << 2) | ((buffer[1] & 0xc0) >> 6)]);
            if (remaining > 1)
            {
                result.Append(alphabet[(buffer[1] & 0x3e) >> 1]);
                result.Append(alphabet[((buffer[1] & 0x01) << 4) | ((buffer[2] & 0xf0) >> 4)]);
            }
            if (remaining > 2)
            {
                result.Append(alphabet[((buffer[2] & 0x0f) << 1) | ((buffer[3] & 0x80) >> 7)]);
            }
            if (remaining > 3)
            {
                result.Append(alphabet[(buffer[3] & 0x7c) >> 2]);
                result.Append(alphabet[((buffer[3] & 0x03) << 3) | ((buffer[4] & 0xe0) >> 5)]);
            }
            if (remaining > 4)
            {
                result.Append(alphabet[buffer[4] & 0x1f]);
            }
        }
        
        return result.ToString();
    }

    private static byte[] Base32Decode(string input)
    {
        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        var output = new List<byte>();
        var buffer = 0;
        var bitsRemaining = 0;
        
        foreach (var c in input.ToUpperInvariant())
        {
            var index = alphabet.IndexOf(c);
            if (index < 0) continue;
            
            buffer = (buffer << 5) | index;
            bitsRemaining += 5;
            
            if (bitsRemaining >= 8)
            {
                bitsRemaining -= 8;
                output.Add((byte)(buffer >> bitsRemaining));
            }
        }
        
        return output.ToArray();
    }

    private string EncryptSecret(string secret)
    {
        var key = Encoding.ASCII.GetBytes(_configuration["JwtSettings:Key"]![..32]);
        using var aes = Aes.Create();
        aes.Key = key;
        aes.GenerateIV();
        
        using var encryptor = aes.CreateEncryptor();
        var plainBytes = Encoding.UTF8.GetBytes(secret);
        var encrypted = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
        
        return Convert.ToBase64String(aes.IV.Concat(encrypted).ToArray());
    }

    private string DecryptSecret(string encrypted)
    {
        var bytes = Convert.FromBase64String(encrypted);
        var iv = bytes[..16];
        var cipherText = bytes[16..];
        
        var key = Encoding.ASCII.GetBytes(_configuration["JwtSettings:Key"]![..32]);
        using var aes = Aes.Create();
        aes.Key = key;
        aes.IV = iv;
        
        using var decryptor = aes.CreateDecryptor();
        var decrypted = decryptor.TransformFinalBlock(cipherText, 0, cipherText.Length);
        
        return Encoding.UTF8.GetString(decrypted);
    }

    private static List<string> GenerateBackupCodes(int count)
    {
        var codes = new List<string>();
        using var rng = RandomNumberGenerator.Create();
        
        for (var i = 0; i < count; i++)
        {
            var bytes = new byte[4];
            rng.GetBytes(bytes);
            var code = (BitConverter.ToUInt32(bytes, 0) % 100_000_000).ToString("D8");
            codes.Add(code);
        }
        
        return codes;
    }

    private static string HashCode(string code)
    {
        using var sha256 = SHA256.Create();
        var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(code));
        return Convert.ToBase64String(bytes);
    }

    private async Task<bool> ValidateAndConsumeBackupCode(AppUser user, string code)
    {
        if (string.IsNullOrEmpty(user.BackupCodes)) return false;
        
        var hashedCodes = JsonSerializer.Deserialize<List<string>>(user.BackupCodes);
        if (hashedCodes == null) return false;
        
        var hashedInput = HashCode(code);
        var index = hashedCodes.IndexOf(hashedInput);
        
        if (index < 0) return false;
        
        // Remove used backup code
        hashedCodes.RemoveAt(index);
        user.BackupCodes = JsonSerializer.Serialize(hashedCodes);
        await _userManager.UpdateAsync(user);
        
        return true;
    }

    private static string GenerateOtp(int length)
    {
        using var rng = RandomNumberGenerator.Create();
        var bytes = new byte[4];
        rng.GetBytes(bytes);
        var number = BitConverter.ToUInt32(bytes, 0);
        var max = (uint)Math.Pow(10, length);
        return (number % max).ToString($"D{length}");
    }

    #endregion
}


