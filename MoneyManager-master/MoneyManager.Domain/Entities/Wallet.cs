using MoneyManager.Domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace MoneyManager.Domain.Entities;

public partial class Wallet : BaseSyncEntity
{
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Số dư ban đầu khi tạo ví
    /// </summary>
    [Column(TypeName = "decimal(18, 2)")]
    public decimal InitialBalance { get; set; } = 0;

    /// <summary>
    /// Số dư hiện tại = InitialBalance + Tổng Thu (Income) - Tổng Chi (Expense)
    /// </summary>
    [Column(TypeName = "decimal(18, 2)")]
    public decimal? Balance { get; set; }
    
    public CurrencyCode Currency { get; set; } = CurrencyCode.VND;

    public string Type { get; set; } = null!;

    public Guid OwnerId { get; set; }
    [ForeignKey("OwnerId")]
    public virtual AppUser Owner { get; set; } = null!;

    public virtual ICollection<Transaction> Transactions { get; set; } = new List<Transaction>();
}
