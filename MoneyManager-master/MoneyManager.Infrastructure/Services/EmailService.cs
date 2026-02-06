using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MoneyManager.Application.Interfaces;

namespace MoneyManager.Infrastructure.Services;

public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;
    private readonly string _smtpHost;
    private readonly int _smtpPort;
    private readonly string _smtpUsername;
    private readonly string _smtpPassword;
    private readonly string _fromEmail;
    private readonly string _fromName;
    private readonly bool _enableSsl;

    public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
        
        _smtpHost = _configuration["Email:SmtpHost"] ?? "smtp.gmail.com";
        _smtpPort = int.Parse(_configuration["Email:SmtpPort"] ?? "587");
        _smtpUsername = _configuration["Email:Username"] ?? "";
        _smtpPassword = _configuration["Email:Password"] ?? "";
        _fromEmail = _configuration["Email:FromEmail"] ?? _smtpUsername;
        _fromName = _configuration["Email:FromName"] ?? "Smart Money";
        _enableSsl = bool.Parse(_configuration["Email:EnableSsl"] ?? "true");
    }

    public async Task<bool> SendEmailVerificationAsync(string email, string fullName, string verificationLink)
    {
        var subject = "Xác thực tài khoản Smart Money";
        var body = GetEmailVerificationTemplate(fullName, verificationLink);
        
        return await SendEmailAsync(email, subject, body);
    }

    public async Task<bool> SendPasswordResetAsync(string email, string fullName, string resetLink)
    {
        var subject = "Đặt lại mật khẩu Smart Money";
        var body = GetPasswordResetTemplate(fullName, resetLink);
        
        return await SendEmailAsync(email, subject, body);
    }

    public async Task<bool> SendOtpAsync(string email, string otpCode, int expiryMinutes = 10)
    {
        var subject = $"Mã OTP của bạn: {otpCode}";
        var body = GetOtpTemplate(otpCode, expiryMinutes);
        
        return await SendEmailAsync(email, subject, body);
    }

    public async Task<bool> SendWelcomeEmailAsync(string email, string fullName)
    {
        var subject = "Chào mừng đến với Smart Money!";
        var body = GetWelcomeTemplate(fullName);
        
        return await SendEmailAsync(email, subject, body);
    }

    public async Task<bool> SendPremiumConfirmationAsync(string email, string fullName, DateTime expiryDate)
    {
        var subject = "Xác nhận Premium - Smart Money";
        var body = GetPremiumConfirmationTemplate(fullName, expiryDate);
        
        return await SendEmailAsync(email, subject, body);
    }

    private async Task<bool> SendEmailAsync(string toEmail, string subject, string htmlBody)
    {
        try
        {
            using var client = new SmtpClient(_smtpHost, _smtpPort)
            {
                Credentials = new NetworkCredential(_smtpUsername, _smtpPassword),
                EnableSsl = _enableSsl
            };

            var mailMessage = new MailMessage
            {
                From = new MailAddress(_fromEmail, _fromName),
                Subject = subject,
                Body = htmlBody,
                IsBodyHtml = true
            };
            mailMessage.To.Add(toEmail);

            await client.SendMailAsync(mailMessage);
            _logger.LogInformation("Email sent successfully to {Email}", toEmail);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send email to {Email}", toEmail);
            return false;
        }
    }

    #region Email Templates

    private static string GetEmailVerificationTemplate(string fullName, string verificationLink)
    {
        return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #6C5CE7, #8E7CF3); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .button {{ display: inline-block; background: #6C5CE7; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; margin: 20px 0; font-weight: bold; }}
        .button:hover {{ background: #5B4BC7; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
        .code {{ background: #e9ecef; padding: 15px; border-radius: 8px; font-family: monospace; font-size: 12px; text-align: center; margin: 15px 0; word-break: break-all; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>💰 Smart Money</h1>
            <p>Xác thực tài khoản của bạn</p>
        </div>
        <div class='content'>
            <p>Xin chào <strong>{fullName}</strong>,</p>
            <p>Vui lòng xác thực email để hoàn tất đăng ký tài khoản Smart Money.</p>
            <div style='text-align: center;'>
                <a href='{verificationLink}' class='button'>✅ Xác thực Email</a>
            </div>
            <p>Hoặc copy và dán link sau vào trình duyệt:</p>
            <div class='code'>{verificationLink}</div>
            <p><strong>⚠️ Lưu ý:</strong> Link xác thực sẽ hết hạn sau 24 giờ.</p>
            <p>Nếu bạn không đăng ký tài khoản này, vui lòng bỏ qua email.</p>
        </div>
        <div class='footer'>
            <p>© 2026 Smart Money. All rights reserved.</p>
            <p>Email này được gửi tự động, vui lòng không trả lời.</p>
        </div>
    </div>
</body>
</html>";
    }

    private static string GetPasswordResetTemplate(string fullName, string resetLink)
    {
        return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #E74C3C, #C0392B); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .button {{ display: inline-block; background: #E74C3C; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; margin: 20px 0; font-weight: bold; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>🔐 Đặt lại mật khẩu</h1>
        </div>
        <div class='content'>
            <p>Xin chào <strong>{fullName}</strong>,</p>
            <p>Nhấn nút bên dưới để tạo mật khẩu mới:</p>
            <div style='text-align: center;'>
                <a href='{resetLink}' class='button'>🔑 Đặt lại mật khẩu</a>
            </div>
            <p><strong>⚠️ Lưu ý:</strong> Link này sẽ hết hạn sau 1 giờ.</p>
            <p>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email.</p>
        </div>
        <div class='footer'>
            <p>© 2026 Smart Money. All rights reserved.</p>
        </div>
    </div>
</body>
</html>";
    }

    private static string GetOtpTemplate(string otpCode, int expiryMinutes)
    {
        return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #6C5CE7, #8E7CF3); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .code {{ background: #6C5CE7; color: white; padding: 20px 40px; border-radius: 10px; font-family: 'Courier New', monospace; font-size: 32px; text-align: center; margin: 20px 0; letter-spacing: 6px; font-weight: bold; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>🔢 Mã OTP của bạn</h1>
        </div>
        <div class='content'>
            <p>Mã xác thực một lần (OTP):</p>
            <div class='code'>{otpCode}</div>
            <p><strong>⏰ Mã này sẽ hết hạn sau {expiryMinutes} phút.</strong></p>
            <p>Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email.</p>
        </div>
        <div class='footer'>
            <p>© 2026 Smart Money. All rights reserved.</p>
        </div>
    </div>
</body>
</html>";
    }

    private static string GetWelcomeTemplate(string fullName)
    {
        return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #00B894, #55EFC4); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .feature {{ background: white; padding: 15px; margin: 10px 0; border-radius: 8px; border-left: 4px solid #00B894; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>🎉 Chào mừng đến với Smart Money!</h1>
        </div>
        <div class='content'>
            <p>Xin chào <strong>{fullName}</strong>,</p>
            <p>Email của bạn đã được xác thực. Bắt đầu quản lý tài chính cá nhân ngay hôm nay!</p>
            <h3>✨ Bạn có thể:</h3>
            <div class='feature'>📊 Theo dõi thu chi hằng ngày</div>
            <div class='feature'>💰 Thiết lập ngân sách hằng tháng</div>
            <div class='feature'>📈 Xem báo cáo và phân tích chi tiêu</div>
            <div class='feature'>👥 Quản lý chi tiêu nhóm</div>
            <p>Nâng cấp <strong>Premium</strong> để mở khóa thêm nhiều tính năng.</p>
        </div>
        <div class='footer'>
            <p>© 2026 Smart Money. All rights reserved.</p>
        </div>
    </div>
</body>
</html>";
    }

    private static string GetPremiumConfirmationTemplate(string fullName, DateTime expiryDate)
    {
        return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #F39C12, #F1C40F); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }}
        .content {{ background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }}
        .premium-badge {{ background: linear-gradient(135deg, #F39C12, #F1C40F); color: white; padding: 15px 30px; border-radius: 30px; display: inline-block; font-weight: bold; font-size: 18px; margin: 20px 0; }}
        .feature {{ background: white; padding: 15px; margin: 10px 0; border-radius: 8px; border-left: 4px solid #F39C12; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class='container'>
        <div class='header'>
            <h1>🏆 Chúc mừng bạn đã trở thành Premium!</h1>
        </div>
        <div class='content'>
            <p>Xin chào <strong>{fullName}</strong>,</p>
            <div style='text-align: center;'>
                <span class='premium-badge'>⭐ PREMIUM MEMBER ⭐</span>
            </div>
            <p>Tài khoản của bạn đã được kích hoạt đầy đủ tính năng cao cấp.</p>
            <h3>🎁 Quyền lợi Premium:</h3>
            <div class='feature'>♾️ Không giới hạn ví và danh mục</div>
            <div class='feature'>📊 Báo cáo và phân tích nâng cao</div>
            <div class='feature'>☁️ Đồng bộ đa thiết bị</div>
            <div class='feature'>🔔 Thông báo và nhắc nhở thông minh</div>
            <div class='feature'>👥 Quản lý nhóm không giới hạn</div>
            <div class='feature'>🚫 Không quảng cáo</div>
            <p><strong>📅 Thời hạn Premium:</strong> đến ngày {expiryDate:dd/MM/yyyy}</p>
        </div>
        <div class='footer'>
            <p>© 2026 Smart Money. All rights reserved.</p>
        </div>
    </div>
</body>
</html>";
    }

    #endregion
}

