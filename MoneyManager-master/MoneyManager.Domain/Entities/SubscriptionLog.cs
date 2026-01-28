using MoneyManager.Domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace MoneyManager.Domain.Entities;

public class SubscriptionLog : BaseSystemEntity
{
    public Guid UserId { get; set; }
    [ForeignKey("UserId")]
    public virtual AppUser? User { get; set; }

    public string ProductId { get; set; } = string.Empty;
    public string? StoreTransactionId { get; set; }
    public string? OriginalTransactionId { get; set; }
    public SubscriptionPlatform Platform { get; set; } = SubscriptionPlatform.GooglePlay;
    public decimal Amount { get; set; }
    public CurrencyCode Currency { get; set; } = CurrencyCode.VND;
    public SubscriptionStatus Status { get; set; } = SubscriptionStatus.Success;
    public DateTime PurchaseDate { get; set; }
    public DateTime ExpiryDate { get; set; }
}