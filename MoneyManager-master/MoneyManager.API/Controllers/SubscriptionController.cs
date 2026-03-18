using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Subscription;
using MoneyManager.Application.Interfaces;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
public class SubscriptionController : ControllerBase
{
    private readonly IPurchaseVerificationService _purchaseService;
    private readonly ILogger<SubscriptionController> _logger;

    public SubscriptionController(
        IPurchaseVerificationService purchaseService,
        ILogger<SubscriptionController> logger)
    {
        _purchaseService = purchaseService;
        _logger = logger;
    }

    /// <summary>
    /// Verify a Google Play purchase and update premium status
    /// </summary>
    [HttpPost("verify/google-play")]
    [Authorize]
    public async Task<IActionResult> VerifyGooglePlayPurchase([FromBody] VerifyPurchaseRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        try
        {
            var result = await _purchaseService.VerifyGooglePlayPurchaseAsync(request, userId.Value);
            return result.Success ? Ok(result) : BadRequest(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying Google Play purchase for user {UserId}", userId);
            return BadRequest(new { success = false, message = "Xác th?c th?t b?i" });
        }
    }

    /// <summary>
    /// Verify an App Store purchase and update premium status
    /// </summary>
    [HttpPost("verify/app-store")]
    [Authorize]
    public async Task<IActionResult> VerifyAppStorePurchase([FromBody] VerifyPurchaseRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        try
        {
            var result = await _purchaseService.VerifyAppStorePurchaseAsync(request, userId.Value);
            return result.Success ? Ok(result) : BadRequest(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying App Store purchase for user {UserId}", userId);
            return BadRequest(new { success = false, message = "Xác th?c th?t b?i" });
        }
    }

    /// <summary>
    /// Get current subscription status
    /// </summary>
    [HttpGet("status")]
    [Authorize]
    public async Task<IActionResult> GetSubscriptionStatus()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var status = await _purchaseService.GetSubscriptionStatusAsync(userId.Value);
        return Ok(status);
    }

    /// <summary>
    /// Webhook endpoint for Google Play Real-time Developer Notifications
    /// </summary>
    [HttpPost("webhook/google-play")]
    public async Task<IActionResult> GooglePlayWebhook()
    {
        try
        {
            using var reader = new StreamReader(Request.Body);
            var body = await reader.ReadToEndAsync();
            
            _logger.LogInformation("Received Google Play webhook");
            
            var success = await _purchaseService.HandleGooglePlayWebhookAsync(body);
            return success ? Ok() : BadRequest();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling Google Play webhook");
            return BadRequest();
        }
    }

    /// <summary>
    /// Webhook endpoint for Apple App Store Server Notifications
    /// </summary>
    [HttpPost("webhook/app-store")]
    public async Task<IActionResult> AppStoreWebhook()
    {
        try
        {
            using var reader = new StreamReader(Request.Body);
            var body = await reader.ReadToEndAsync();
            
            _logger.LogInformation("Received App Store webhook");
            
            var success = await _purchaseService.HandleAppStoreWebhookAsync(body);
            return success ? Ok() : BadRequest();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling App Store webhook");
            return BadRequest();
        }
    }

    private Guid? GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }
}

