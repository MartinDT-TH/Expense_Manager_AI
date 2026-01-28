using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace MoneyManager.Domain.Entities;

public partial class Transaction : BaseSyncEntity
{
    [Column(TypeName = "decimal(18, 2)")]
    public decimal Amount { get; set; }
    public string? Note { get; set; }
    public DateTime TransactionDate { get; set; }

    // Liên kết Ví
    public Guid WalletId { get; set; }
    [ForeignKey("WalletId")]
    public virtual Wallet? Wallet { get; set; }

    // Liên kết Danh mục
    public Guid CategoryId { get; set; }
    [ForeignKey("CategoryId")]
    public virtual Category? Category { get; set; }

    // Liên kết Quỹ nhóm (Nullable)
    public Guid? GroupId { get; set; }
    [ForeignKey("GroupId")]
    public virtual Group? Group { get; set; }

    // Feature Premium
    public string? BillImageUrl { get; set; }
    public string? OcrRawData { get; set; }
}
