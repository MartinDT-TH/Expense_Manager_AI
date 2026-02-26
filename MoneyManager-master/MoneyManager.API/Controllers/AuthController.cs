using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Auth;
using MoneyManager.Application.DTOs.Subscription;
using MoneyManager.Application.Interfaces;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    #region Basic Auth

    /// <summary>
    /// Đăng ký tài khoản mới bằng email/password
    /// Sau khi đăng ký, user cần xác thực email trước khi đăng nhập
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            var result = await _authService.RegisterAsync(request);
            return result.Success ? Ok(result) : BadRequest(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new { success = false, message = ex.Message });
        }
    }

    /// <summary>
    /// Đăng nhập bằng email/password
    /// Yêu cầu email đã được xác thực
    /// </summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        try
        {
            var result = await _authService.LoginAsync(request);
            
            // If email not verified, return 403
            if (!result.Success && result.RequiresEmailVerification)
            {
                return StatusCode(403, result);
            }
            
            return result.Success ? Ok(result) : BadRequest(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new { success = false, message = ex.Message });
        }
    }

    #endregion

    #region Email Verification

    /// <summary>
    /// Xác thực email - được gọi khi user click link trong email
    /// </summary>
    [HttpGet("confirm-email")]
    public async Task<IActionResult> ConfirmEmail([FromQuery] string token, [FromQuery] string email)
    {
        if (string.IsNullOrEmpty(token) || string.IsNullOrEmpty(email))
        {
            return Redirect("/EmailConfirmed?success=false&message=Thiếu%20token%20hoặc%20email");
        }

        // URL decode the token
        var decodedToken = System.Web.HttpUtility.UrlDecode(token);
        var decodedEmail = System.Web.HttpUtility.UrlDecode(email);

        var result = await _authService.ConfirmEmailAsync(decodedToken, decodedEmail);
        
        if (result.Success)
        {
            // Redirect to Razor page for any device/browser
            var message = System.Web.HttpUtility.UrlEncode(result.Message ?? "Email đã được xác thực. Bạn có thể đăng nhập.");
            return Redirect($"/EmailConfirmed?success=true&message={message}");
        }

        // If token invalid/expired, auto-resend verification email
        var resendSent = await _authService.ResendVerificationEmailAsync(decodedEmail);
        var resendMessage = resendSent
            ? "Link xác thực đã hết hạn hoặc không hợp lệ. Chúng tôi đã gửi email mới, vui lòng kiểm tra hộp thư."
            : "Link xác thực đã hết hạn hoặc không hợp lệ. Vui lòng yêu cầu gửi lại email.";

        var error = System.Web.HttpUtility.UrlEncode(resendMessage);
        return Redirect($"/EmailConfirmed?success=false&message={error}");
    }

    /// <summary>
    /// Gửi lại email xác thực
    /// </summary>
    [HttpPost("resend-verification")]
    public async Task<IActionResult> ResendVerificationEmail([FromBody] ResendVerificationRequest request)
    {
        if (string.IsNullOrEmpty(request.Email))
        {
            return BadRequest(new { success = false, message = "Email là bắt buộc." });
        }

        var sent = await _authService.ResendVerificationEmailAsync(request.Email);
        
        return sent 
            ? Ok(new { success = true, message = "Email xác thực đã được gửi. Vui lòng kiểm tra hộp thư." })
            : BadRequest(new { success = false, message = "Không thể gửi email. Vui lòng thử lại sau." });
    }

    private static string GetEmailConfirmedHtml(string message)
    {
        return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Email Confirmed - Smart Money</title>
    <style>
        body {{ font-family: 'Segoe UI', sans-serif; background: linear-gradient(135deg, #6C5CE7, #8E7CF3); min-height: 100vh; display: flex; align-items: center; justify-content: center; margin: 0; }}
        .container {{ background: white; padding: 40px; border-radius: 20px; text-align: center; max-width: 400px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); }}
        .icon {{ font-size: 64px; margin-bottom: 20px; }}
        h1 {{ color: #00B894; margin-bottom: 10px; }}
        p {{ color: #666; line-height: 1.6; }}
        .button {{ display: inline-block; background: #6C5CE7; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; margin-top: 20px; font-weight: bold; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='icon'>✅</div>
        <h1>Xác thực thành công!</h1>
        <p>{message}</p>
        <p>Bạn có thể đóng trang này và mở ứng dụng Smart Money để đăng nhập.</p>
        <a href='moneymanager://login' class='button'>Mở ứng dụng</a>
    </div>
</body>
</html>";
    }

    /// <summary>
    /// Đăng xuất - revoke refresh token
    /// </summary>
    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _authService.RevokeTokenAsync(userId.Value);
        return result 
            ? Ok(new { success = true, message = "Đăng xuất thành công." })
            : BadRequest(new { success = false, message = "Không thể đăng xuất." });
    }

    #endregion

    #region Google OAuth

    /// <summary>
    /// Đăng nhập bằng Google
    /// Flutter gửi idToken từ GoogleSignIn
    /// </summary>
    [HttpPost("google-login")]
    public async Task<IActionResult> GoogleLogin([FromBody] GoogleAuthRequest request)
    {
        try
        {
            var result = await _authService.GoogleLoginAsync(request);
            return result.Success ? Ok(result) : BadRequest(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new { success = false, message = ex.Message });
        }
    }

    /// <summary>
    /// Liên kết tài khoản Google với tài khoản hiện tại
    /// </summary>
    [HttpPost("link-google")]
    [Authorize]
    public async Task<IActionResult> LinkGoogle([FromBody] LinkGoogleRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _authService.LinkGoogleAccountAsync(userId.Value, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Hủy liên kết tài khoản Google
    /// </summary>
    [HttpPost("unlink-google")]
    [Authorize]
    public async Task<IActionResult> UnlinkGoogle()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _authService.UnlinkGoogleAccountAsync(userId.Value);
        return result 
            ? Ok(new { success = true, message = "Đã hủy liên kết Google." })
            : BadRequest(new { success = false, message = "Không thể hủy liên kết. Đảm bảo đã đặt mật khẩu." });
    }

    #endregion

    #region Two-Factor Authentication

    /// <summary>
    /// Setup 2FA - Trả về QR code và backup codes
    /// </summary>
    [HttpPost("2fa/setup")]
    [Authorize]
    public async Task<IActionResult> SetupTwoFactor()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _authService.SetupTwoFactorAsync(userId.Value);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Verify OTP code (during login hoặc confirm setup)
    /// </summary>
    [HttpPost("2fa/verify")]
    public async Task<IActionResult> VerifyTwoFactor([FromBody] VerifyOtpRequest request, [FromHeader(Name = "X-TwoFactor-Token")] string twoFactorToken)
    {
        if (string.IsNullOrEmpty(twoFactorToken))
            return BadRequest(new { success = false, message = "Thi?u header token 2FA." });

        var result = await _authService.VerifyTwoFactorAsync(twoFactorToken, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Confirm 2FA setup với OTP code đầu tiên
    /// </summary>
    [HttpPost("2fa/confirm")]
    [Authorize]
    public async Task<IActionResult> ConfirmTwoFactor([FromBody] VerifyOtpRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        // Generate temp token for current user
        request.IsSetupConfirmation = true;
        var tempToken = GenerateTempTokenForUser(userId.Value);
        
        var result = await _authService.VerifyTwoFactorAsync(tempToken, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Tắt 2FA
    /// </summary>
    [HttpPost("2fa/disable")]
    [Authorize]
    public async Task<IActionResult> DisableTwoFactor([FromBody] VerifyOtpRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _authService.DisableTwoFactorAsync(userId.Value, request.Code);
        return result 
            ? Ok(new { success = true, message = "2FA đã được tắt." })
            : BadRequest(new { success = false, message = "Mã OTP không đúng." });
    }

    /// <summary>
    /// Kiểm tra trạng thái 2FA
    /// </summary>
    [HttpGet("2fa/status")]
    [Authorize]
    public async Task<IActionResult> GetTwoFactorStatus()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var enabled = await _authService.IsTwoFactorEnabledAsync(userId.Value);
        return Ok(new { enabled });
    }

    #endregion

    #region Email OTP

    /// <summary>
    /// Gửi OTP qua email
    /// </summary>
    [HttpPost("otp/send")]
    public async Task<IActionResult> SendEmailOtp([FromBody] SendEmailOtpRequest request)
    {
        var result = await _authService.SendEmailOtpAsync(request.Email);
        return result 
            ? Ok(new { success = true, message = "OTP đã được gửi qua email." })
            : BadRequest(new { success = false, message = "Không thể gửi OTP." });
    }

    /// <summary>
    /// Verify OTP từ email
    /// </summary>
    [HttpPost("otp/verify")]
    public async Task<IActionResult> VerifyEmailOtp([FromBody] VerifyEmailOtpRequest request)
    {
        var result = await _authService.VerifyEmailOtpAsync(request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    #endregion

    #region Token Management

    /// <summary>
    /// Refresh access token
    /// </summary>
    [HttpPost("refresh-token")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        var result = await _authService.RefreshTokenAsync(request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Validate token và trả về user info
    /// </summary>
    [HttpGet("validate")]
    [Authorize]
    public async Task<IActionResult> ValidateToken()
    {
        var token = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");
        var user = await _authService.GetUserFromTokenAsync(token);
        
        return user != null 
            ? Ok(new { success = true, user })
            : Unauthorized(new { success = false, message = "Token không hợp lệ." });
    }

    #endregion

    #region Helpers

    private Guid? GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    private string GenerateTempTokenForUser(Guid userId)
    {
        // Simple temp token for confirm 2FA setup (valid for current request only)
        var data = $"{userId}:{DateTime.UtcNow.AddMinutes(5).Ticks}";
        return Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(data));
    }

    #endregion
}

