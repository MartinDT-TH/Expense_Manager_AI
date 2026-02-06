using MoneyManager.Application.DTOs.Subscription;

namespace MoneyManager.Application.Interfaces;

public interface IPurchaseVerificationService
{
    /// <summary>
    /// Verify Google Play purchase/subscription
    /// </summary>
    Task<PurchaseVerificationResult> VerifyGooglePlayPurchaseAsync(VerifyPurchaseRequest request, Guid userId);
    
    /// <summary>
    /// Verify Apple App Store purchase/subscription
    /// </summary>
    Task<PurchaseVerificationResult> VerifyAppStorePurchaseAsync(VerifyPurchaseRequest request, Guid userId);
    
    /// <summary>
    /// Check subscription status for a user
    /// </summary>
    Task<SubscriptionStatusDto> GetSubscriptionStatusAsync(Guid userId);
    
    /// <summary>
    /// Handle subscription webhook from Google Play
    /// </summary>
    Task<bool> HandleGooglePlayWebhookAsync(string notificationData);
    
    /// <summary>
    /// Handle subscription webhook from Apple App Store
    /// </summary>
    Task<bool> HandleAppStoreWebhookAsync(string notificationData);
}
