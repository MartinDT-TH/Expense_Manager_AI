using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace MoneyManager.Domain.Entities;

public partial class Budget : BaseSyncEntity
{
    public decimal AmountLimit { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }

    /// <summary>
    /// Nếu true = Budget mặc định áp dụng cho mọi tháng (khi tháng đó chưa có budget riêng)
    /// Nếu false = Budget cho tháng cụ thể (StartDate/EndDate)
    /// </summary>
    public bool IsRecurring { get; set; } = false;

    /// <summary>
    /// CategoryId - Nếu null thì là ngân sách tổng cho tháng (không theo danh mục cụ thể)
    /// </summary>
    public Guid? CategoryId { get; set; }
    [ForeignKey("CategoryId")]
    public virtual Category? Category { get; set; }

    public Guid OwnerId { get; set; }
    [ForeignKey("OwnerId")]
    public virtual AppUser? Owner { get; set; }
}
