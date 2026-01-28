using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Transaction;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class TransactionController : ControllerBase
{
    private readonly ITransactionService _transactionService;
    private readonly UserManager<AppUser> _userManager;
    private readonly IOcrService _ocrService;

    public TransactionController(
        ITransactionService transactionService, 
        UserManager<AppUser> userManager,
        IOcrService ocrService)
    {
        _transactionService = transactionService;
        _userManager = userManager;
        _ocrService = ocrService;
    }

    private async Task<AppUser?> GetCurrentUserAsync()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userId)) return null;
        return await _userManager.FindByIdAsync(userId);
    }

    /// <summary>
    /// POST: api/Transaction/ocr-test
    /// Test OCR không cần đăng nhập (chỉ dùng cho development)
    /// </summary>
    [HttpPost("ocr-test")]
    [AllowAnonymous]
    public async Task<IActionResult> TestOcr([FromBody] OcrRequest request)
    {
        try
        {
            var result = await _ocrService.ExtractReceiptDataAsync(request.ImageUrl);
            return Ok(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    /// <summary>
    /// POST: api/Transaction/ocr-base64
    /// Test OCR với base64 image (không cần đăng nhập - chỉ dùng cho development)
    /// </summary>
    [HttpPost("ocr-base64")]
    [AllowAnonymous]
    public async Task<IActionResult> TestOcrBase64([FromBody] OcrBase64Request request)
    {
        try
        {
            var result = await _ocrService.ExtractReceiptDataFromBase64Async(request.Base64Image, request.MimeType ?? "image/png");
            return Ok(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    /// <summary>
    /// POST: api/Transaction/ocr-groq-test
    /// Test Groq OCR trực tiếp (bypass Gemini) - Development only
    /// </summary>
    [HttpPost("ocr-groq-test")]
    [AllowAnonymous]
    public async Task<IActionResult> TestGroqOcr([FromBody] OcrBase64Request request)
    {
        try
        {
            // Inject GroqOcrService directly for testing
            var groqService = HttpContext.RequestServices.GetRequiredService<MoneyManager.Infrastructure.Services.GroqOcrService>();
            var result = await groqService.ExtractReceiptDataFromBase64Async(request.Base64Image, request.MimeType ?? "image/jpeg");
            return Ok(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    /// <summary>
    /// GET: api/Transaction
    /// Lấy danh sách giao dịch có filter và phân trang
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetTransactions([FromQuery] TransactionFilterRequest filter)
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var result = await _transactionService.GetTransactionsAsync(user.Id, filter);
        return Ok(result);
    }

    /// <summary>
    /// GET: api/Transaction/recent
    /// Lấy giao dịch gần đây (cho Dashboard)
    /// </summary>
    [HttpGet("recent")]
    public async Task<IActionResult> GetRecentTransactions([FromQuery] int count = 5)
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var transactions = await _transactionService.GetRecentTransactionsAsync(user.Id, count);
        return Ok(transactions);
    }

    /// <summary>
    /// GET: api/Transaction/{id}
    /// Lấy chi tiết giao dịch
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetTransaction(Guid id)
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var transaction = await _transactionService.GetTransactionByIdAsync(id, user.Id);
        if (transaction == null)
        {
            return NotFound(new { message = "Không tìm thấy giao dịch." });
        }

        return Ok(transaction);
    }

    /// <summary>
    /// POST: api/Transaction
    /// Tạo giao dịch mới
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateTransaction([FromBody] CreateTransactionRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var transaction = await _transactionService.CreateTransactionAsync(request, user.Id);
            return CreatedAtAction(nameof(GetTransaction), new { id = transaction.Id }, transaction);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// PUT: api/Transaction/{id}
    /// Cập nhật giao dịch
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateTransaction(Guid id, [FromBody] UpdateTransactionRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var transaction = await _transactionService.UpdateTransactionAsync(id, request, user.Id);
            return Ok(transaction);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// DELETE: api/Transaction/{id}
    /// Xóa mềm giao dịch
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteTransaction(Guid id)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var result = await _transactionService.DeleteTransactionAsync(id, user.Id);
            if (!result)
            {
                return NotFound(new { message = "Không tìm thấy giao dịch." });
            }

            return Ok(new { message = "Đã xóa giao dịch thành công." });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// POST: api/Transaction/ocr
    /// Xử lý OCR hóa đơn (Premium feature)
    /// </summary>
    [HttpPost("ocr")]
    public async Task<IActionResult> ProcessOcr([FromBody] OcrRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            // Check Premium
            if (!user.IsPremium)
            {
                return BadRequest(new { 
                    message = "Tính năng OCR chỉ dành cho tài khoản Premium.", 
                    code = "PREMIUM_REQUIRED" 
                });
            }

            var result = await _transactionService.ProcessOcrAsync(request.ImageUrl, user.Id);
            return Ok(result);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// GET: api/Transaction/group/{groupId}
    /// Lấy giao dịch của nhóm
    /// </summary>
    [HttpGet("group/{groupId}")]
    public async Task<IActionResult> GetGroupTransactions(Guid groupId, [FromQuery] TransactionFilterRequest filter)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var result = await _transactionService.GetGroupTransactionsAsync(groupId, user.Id, filter);
            return Ok(result);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}

/// <summary>
/// Request cho OCR với URL
/// </summary>
public class OcrRequest
{
    public string ImageUrl { get; set; } = string.Empty;
}

/// <summary>
/// Request cho OCR với Base64 image
/// </summary>
public class OcrBase64Request
{
    public string Base64Image { get; set; } = string.Empty;
    public string? MimeType { get; set; } = "image/png";
}
