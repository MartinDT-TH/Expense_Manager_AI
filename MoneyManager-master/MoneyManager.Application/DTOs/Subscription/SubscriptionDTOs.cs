namespace MoneyManager.Application.DTOs.Subscription;

/// <summary>
/// Request to verify a purchase from app stores
/// </summary>
public class VerifyPurchaseRequest
{
    /// <summary>
    /// The purchase token from Google Play or receipt from App Store
    /// </summary>
    public string PurchaseToken { get; set; } = string.Empty;
    
    /// <summary>
    /// Product ID (e.g., "premium_monthly", "premium_yearly")
    /// </summary>
    public string ProductId { get; set; } = string.Empty;
    
    /// <summary>
    /// Package name (Android) or Bundle ID (iOS)
    /// </summary>
    public string PackageName { get; set; } = string.Empty;
    
    /// <summary>
    /// Platform: "android" or "ios"
    /// </summary>
    public string Platform { get; set; } = "android";
    
    /// <summary>
    /// Order ID from the store
    /// </summary>
    public string? OrderId { get; set; }
}

/// <summary>
/// Result of purchase verification
/// </summary>
public class PurchaseVerificationResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    
    /// <summary>
    /// True if the purchase is valid and active
    /// </summary>
    public bool IsValid { get; set; }
    
    /// <summary>
    /// True if this is a subscription (vs one-time purchase)
    /// </summary>
    public bool IsSubscription { get; set; }
    
    /// <summary>
    /// Product ID
    /// </summary>
    public string? ProductId { get; set; }
    
    /// <summary>
    /// When the subscription expires (null for one-time purchases)
    /// </summary>
    public DateTime? ExpiryDate { get; set; }
    
    /// <summary>
    /// Purchase time
    /// </summary>
    public DateTime? PurchaseTime { get; set; }
    
    /// <summary>
    /// Order ID from store
    /// </summary>
    public string? OrderId { get; set; }
    
    /// <summary>
    /// Subscription state (e.g., "ACTIVE", "CANCELED", "PAUSED")
    /// </summary>
    public string? SubscriptionState { get; set; }
    
    /// <summary>
    /// Whether user's premium status was updated
    /// </summary>
    public bool PremiumUpdated { get; set; }
}

/// <summary>
/// Current subscription status for a user (DTO)
/// </summary>
public class SubscriptionStatusDto
{
    public bool IsPremium { get; set; }
    public bool IsActive { get; set; }
    public string? ProductId { get; set; }
    public string? Platform { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public DateTime? LastVerifiedAt { get; set; }
    public string? State { get; set; }
    
    /// <summary>
    /// Auto-renew status
    /// </summary>
    public bool AutoRenewing { get; set; }
    
    /// <summary>
    /// Days until expiry (negative if expired)
    /// </summary>
    public int? DaysUntilExpiry { get; set; }
}

/// <summary>
/// Email verification request
/// </summary>
public class EmailVerificationRequest
{
    public string Token { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
}

/// <summary>
/// Resend verification email request
/// </summary>
public class ResendVerificationRequest
{
    public string Email { get; set; } = string.Empty;
}
