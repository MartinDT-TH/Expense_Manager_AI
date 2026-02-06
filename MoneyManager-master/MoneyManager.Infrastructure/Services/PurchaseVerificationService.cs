using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MoneyManager.Application.DTOs.Subscription;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;
using Microsoft.EntityFrameworkCore;

namespace MoneyManager.Infrastructure.Services;

public class PurchaseVerificationService : IPurchaseVerificationService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<PurchaseVerificationService> _logger;
    private readonly UserManager<AppUser> _userManager;
    private readonly MoneyManagerDbContext _context;
    private readonly IEmailService _emailService;
    private readonly HttpClient _httpClient;

    // Google Play API base URL
    private const string GooglePlayApiBaseUrl = "https://androidpublisher.googleapis.com/androidpublisher/v3";
    
    // Product IDs
    private const string PremiumMonthly = "premium_monthly";
    private const string PremiumYearly = "premium_yearly";
    private const string PremiumLifetime = "premium_lifetime";

    public PurchaseVerificationService(
        IConfiguration configuration,
        ILogger<PurchaseVerificationService> logger,
        UserManager<AppUser> userManager,
        MoneyManagerDbContext context,
        IEmailService emailService,
        IHttpClientFactory httpClientFactory)
    {
        _configuration = configuration;
        _logger = logger;
        _userManager = userManager;
        _context = context;
        _emailService = emailService;
        _httpClient = httpClientFactory.CreateClient("GooglePlayApi");
    }

    public async Task<PurchaseVerificationResult> VerifyGooglePlayPurchaseAsync(VerifyPurchaseRequest request, Guid userId)
    {
        try
        {
            _logger.LogInformation("Verifying Google Play purchase for user {UserId}, product {ProductId}", 
                userId, request.ProductId);

            var user = await _userManager.FindByIdAsync(userId.ToString());
            if (user == null)
            {
                return new PurchaseVerificationResult
                {
                    Success = false,
                    Message = "Không tìm th?y ngu?i dùng"
                };
            }

            // Get access token for Google Play API
            var accessToken = await GetGooglePlayAccessTokenAsync();
            if (string.IsNullOrEmpty(accessToken))
            {
                _logger.LogError("Không l?y du?c access token Google Play");
                return new PurchaseVerificationResult
                {
                    Success = false,
                    Message = "Không th? xác th?c v?i Google Play"
                };
            }

            // Determine if it's a subscription or one-time purchase
            var isSubscription = request.ProductId.Contains("monthly") || request.ProductId.Contains("yearly");
            
            PurchaseVerificationResult verificationResult;
            
            if (isSubscription)
            {
                verificationResult = await VerifySubscriptionAsync(request, accessToken);
            }
            else
            {
                verificationResult = await VerifyProductPurchaseAsync(request, accessToken);
            }

            if (verificationResult.IsValid)
            {
                // Update user's premium status
                await UpdateUserPremiumStatusAsync(user, verificationResult);
                verificationResult.PremiumUpdated = true;
                verificationResult.Success = true;
                verificationResult.Message = "Purchase verified successfully";

                // Log the subscription
                await LogSubscriptionAsync(userId, request, verificationResult);

                // Send confirmation email
                if (verificationResult.ExpiryDate.HasValue)
                {
                    await _emailService.SendPremiumConfirmationAsync(
                        user.Email!, 
                        user.FullName ?? "User", 
                        verificationResult.ExpiryDate.Value);
                }
            }

            return verificationResult;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying Google Play purchase for user {UserId}", userId);
            return new PurchaseVerificationResult
            {
                Success = false,
                Message = $"Xác th?c th?t b?i: {ex.Message}"
            };
        }
    }

    private async Task<PurchaseVerificationResult> VerifySubscriptionAsync(VerifyPurchaseRequest request, string accessToken)
    {
        var packageName = request.PackageName;
        var subscriptionId = request.ProductId;
        var token = request.PurchaseToken;

        var url = $"{GooglePlayApiBaseUrl}/applications/{packageName}/purchases/subscriptions/{subscriptionId}/tokens/{token}";

        _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        
        var response = await _httpClient.GetAsync(url);
        var content = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Google Play API returned {StatusCode}: {Content}", response.StatusCode, content);
            return new PurchaseVerificationResult
            {
                Success = false,
                IsValid = false,
                Message = "Không th? xác th?c gói dang ký v?i Google Play"
            };
        }

        var subscriptionData = JsonSerializer.Deserialize<GooglePlaySubscriptionResponse>(content);
        if (subscriptionData == null)
        {
            return new PurchaseVerificationResult
            {
                Success = false,
                IsValid = false,
                Message = "Ph?n h?i t? Google Play không h?p l?"
            };
        }

        // Check if subscription is active
        var expiryTimeMs = long.Parse(subscriptionData.ExpiryTimeMillis ?? "0");
        var expiryDate = DateTimeOffset.FromUnixTimeMilliseconds(expiryTimeMs).UtcDateTime;
        var isActive = expiryDate > DateTime.UtcNow;

        // Map payment state
        var state = subscriptionData.PaymentState switch
        {
            0 => "PENDING",
            1 => "ACTIVE",
            2 => "FREE_TRIAL",
            3 => "PENDING_DEFERRED",
            _ => "UNKNOWN"
        };

        return new PurchaseVerificationResult
        {
            Success = true,
            IsValid = isActive,
            IsSubscription = true,
            ProductId = request.ProductId,
            ExpiryDate = expiryDate,
            PurchaseTime = DateTimeOffset.FromUnixTimeMilliseconds(
                long.Parse(subscriptionData.StartTimeMillis ?? "0")).UtcDateTime,
            OrderId = subscriptionData.OrderId,
            SubscriptionState = state
        };
    }

    private async Task<PurchaseVerificationResult> VerifyProductPurchaseAsync(VerifyPurchaseRequest request, string accessToken)
    {
        var packageName = request.PackageName;
        var productId = request.ProductId;
        var token = request.PurchaseToken;

        var url = $"{GooglePlayApiBaseUrl}/applications/{packageName}/purchases/products/{productId}/tokens/{token}";

        _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        
        var response = await _httpClient.GetAsync(url);
        var content = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Google Play API returned {StatusCode}: {Content}", response.StatusCode, content);
            return new PurchaseVerificationResult
            {
                Success = false,
                IsValid = false,
                Message = "Không th? xác th?c giao d?ch v?i Google Play"
            };
        }

        var purchaseData = JsonSerializer.Deserialize<GooglePlayProductPurchaseResponse>(content);
        if (purchaseData == null)
        {
            return new PurchaseVerificationResult
            {
                Success = false,
                IsValid = false,
                Message = "Ph?n h?i t? Google Play không h?p l?"
            };
        }

        // For one-time purchases (e.g., lifetime), purchaseState 0 = Purchased
        var isValid = purchaseData.PurchaseState == 0;
        
        // Lifetime purchase = 100 years expiry
        DateTime? expiryDate = productId == PremiumLifetime 
            ? DateTime.UtcNow.AddYears(100) 
            : null;

        return new PurchaseVerificationResult
        {
            Success = true,
            IsValid = isValid,
            IsSubscription = false,
            ProductId = request.ProductId,
            ExpiryDate = expiryDate,
            PurchaseTime = DateTimeOffset.FromUnixTimeMilliseconds(
                long.Parse(purchaseData.PurchaseTimeMillis ?? "0")).UtcDateTime,
            OrderId = purchaseData.OrderId,
            SubscriptionState = isValid ? "PURCHASED" : "INVALID"
        };
    }

    private async Task<string?> GetGooglePlayAccessTokenAsync()
    {
        try
        {
            // Option 1: Use service account JSON file
            var serviceAccountPath = _configuration["GooglePlay:ServiceAccountKeyPath"];
            if (!string.IsNullOrEmpty(serviceAccountPath) && File.Exists(serviceAccountPath))
            {
                // Read service account JSON and get access token using Google Auth Library
                // This requires Google.Apis.Auth NuGet package
                var credential = Google.Apis.Auth.OAuth2.GoogleCredential
                    .FromFile(serviceAccountPath)
                    .CreateScoped("https://www.googleapis.com/auth/androidpublisher");
                
                var accessToken = await credential.UnderlyingCredential.GetAccessTokenForRequestAsync();
                return accessToken;
            }

            // Option 2: Use pre-configured access token (for testing)
            var staticToken = _configuration["GooglePlay:AccessToken"];
            if (!string.IsNullOrEmpty(staticToken))
            {
                return staticToken;
            }

            _logger.LogWarning("No Google Play credentials configured");
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Không l?y du?c access token Google Play");
            return null;
        }
    }

    private async Task UpdateUserPremiumStatusAsync(AppUser user, PurchaseVerificationResult verification)
    {
        user.IsPremium = verification.IsValid;
        user.PremiumExpiryDate = verification.ExpiryDate;
        user.UpdatedAt = DateTime.UtcNow;

        await _userManager.UpdateAsync(user);
        
        _logger.LogInformation("Updated premium status for user {UserId}: IsPremium={IsPremium}, ExpiryDate={ExpiryDate}", 
            user.Id, user.IsPremium, user.PremiumExpiryDate);
    }

    private async Task LogSubscriptionAsync(Guid userId, VerifyPurchaseRequest request, PurchaseVerificationResult result)
    {
        var platform = request.Platform.ToLower() == "ios" 
            ? SubscriptionPlatform.AppStore 
            : SubscriptionPlatform.GooglePlay;

        var status = result.SubscriptionState?.ToUpper() switch
        {
            "ACTIVE" or "PURCHASED" => SubscriptionStatus.Success,
            "CANCELED" or "CANCELLED" => SubscriptionStatus.Cancelled,
            "EXPIRED" => SubscriptionStatus.Expired,
            _ => SubscriptionStatus.Success
        };

        var log = new SubscriptionLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            ProductId = request.ProductId,
            Platform = platform,
            StoreTransactionId = result.OrderId,
            OriginalTransactionId = request.PurchaseToken,
            PurchaseDate = result.PurchaseTime ?? DateTime.UtcNow,
            ExpiryDate = result.ExpiryDate ?? DateTime.UtcNow.AddMonths(1),
            Status = status,
            Amount = 0, // Amount will be set by webhook or manual entry
            CreatedAt = DateTime.UtcNow
        };

        _context.SubscriptionLogs.Add(log);
        await _context.SaveChangesAsync();
    }

    public async Task<PurchaseVerificationResult> VerifyAppStorePurchaseAsync(VerifyPurchaseRequest request, Guid userId)
    {
        // TODO: Implement App Store receipt verification
        // This requires calling Apple's verifyReceipt endpoint
        _logger.LogWarning("Chua h? tr? xác th?c App Store");
        
        return new PurchaseVerificationResult
        {
            Success = false,
            Message = "Chua h? tr? xác th?c App Store"
        };
    }

    public async Task<SubscriptionStatusDto> GetSubscriptionStatusAsync(Guid userId)
    {
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user == null)
        {
            return new SubscriptionStatusDto { IsPremium = false, IsActive = false };
        }

        var latestLog = await _context.SubscriptionLogs
            .Where(s => s.UserId == userId)
            .OrderByDescending(s => s.CreatedAt)
            .FirstOrDefaultAsync();

        var daysUntilExpiry = user.PremiumExpiryDate.HasValue 
            ? (int)(user.PremiumExpiryDate.Value - DateTime.UtcNow).TotalDays 
            : (int?)null;

        return new SubscriptionStatusDto
        {
            IsPremium = user.IsPremium,
            IsActive = user.IsPremium && (user.PremiumExpiryDate == null || user.PremiumExpiryDate > DateTime.UtcNow),
            ProductId = latestLog?.ProductId,
            Platform = latestLog?.Platform.ToString(),
            ExpiryDate = user.PremiumExpiryDate,
            LastVerifiedAt = latestLog?.CreatedAt,
            State = latestLog?.Status.ToString(),
            DaysUntilExpiry = daysUntilExpiry
        };
    }

    public async Task<bool> HandleGooglePlayWebhookAsync(string notificationData)
    {
        try
        {
            // Parse the RTDN (Real-time developer notification) from Google Play
            var notification = JsonSerializer.Deserialize<GooglePlayRtdnNotification>(notificationData);
            if (notification == null) return false;

            _logger.LogInformation("Received Google Play webhook: {NotificationType}", 
                notification.SubscriptionNotification?.NotificationType);

            // Handle different notification types
            if (notification.SubscriptionNotification != null)
            {
                var subNotification = notification.SubscriptionNotification;
                
                // Find user by original transaction ID (which stores the purchase token)
                var subscriptionLog = await _context.SubscriptionLogs
                    .FirstOrDefaultAsync(s => s.OriginalTransactionId == subNotification.PurchaseToken);

                if (subscriptionLog != null)
                {
                    var user = await _userManager.FindByIdAsync(subscriptionLog.UserId.ToString());
                    if (user != null)
                    {
                        // Re-verify the subscription to get latest status
                        var verifyRequest = new VerifyPurchaseRequest
                        {
                            PurchaseToken = subNotification.PurchaseToken ?? "",
                            ProductId = subscriptionLog.ProductId,
                            PackageName = _configuration["GooglePlay:PackageName"] ?? "",
                            Platform = "android"
                        };

                        await VerifyGooglePlayPurchaseAsync(verifyRequest, user.Id);
                    }
                }
            }

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling Google Play webhook");
            return false;
        }
    }

    public Task<bool> HandleAppStoreWebhookAsync(string notificationData)
    {
        // TODO: Implement App Store Server Notifications handling
        _logger.LogWarning("Chua h? tr? webhook App Store");
        return Task.FromResult(false);
    }
}

#region Google Play API Response Models

internal class GooglePlaySubscriptionResponse
{
    public string? StartTimeMillis { get; set; }
    public string? ExpiryTimeMillis { get; set; }
    public int? PaymentState { get; set; }
    public int? CancelReason { get; set; }
    public string? OrderId { get; set; }
    public bool? AutoRenewing { get; set; }
    public string? PriceAmountMicros { get; set; }
    public string? PriceCurrencyCode { get; set; }
    public string? CountryCode { get; set; }
}

internal class GooglePlayProductPurchaseResponse
{
    public int PurchaseState { get; set; }
    public int ConsumptionState { get; set; }
    public string? PurchaseTimeMillis { get; set; }
    public string? OrderId { get; set; }
    public int? AcknowledgementState { get; set; }
}

internal class GooglePlayRtdnNotification
{
    public string? Version { get; set; }
    public string? PackageName { get; set; }
    public long? EventTimeMillis { get; set; }
    public SubscriptionNotification? SubscriptionNotification { get; set; }
    public OneTimeProductNotification? OneTimeProductNotification { get; set; }
}

internal class SubscriptionNotification
{
    public string? Version { get; set; }
    public int NotificationType { get; set; }
    public string? PurchaseToken { get; set; }
    public string? SubscriptionId { get; set; }
}

internal class OneTimeProductNotification
{
    public string? Version { get; set; }
    public int NotificationType { get; set; }
    public string? PurchaseToken { get; set; }
    public string? Sku { get; set; }
}

#endregion

