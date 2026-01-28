using MoneyManager.Domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace MoneyManager.Domain.Entities;

public partial class Category : BaseSyncEntity
{
    public string Name { get; set; } = string.Empty;
    public string? IconCode { get; set; }
    public CategoryType Type { get; set; } = CategoryType.Expense;

    public Guid? ParentId { get; set; }// Danh mục cha con
    [ForeignKey("ParentId")]
    public virtual Category? Parent { get; set; }

    // Null = Danh mục hệ thống, Có ID = Danh mục riêng của User
    public Guid? OwnerId { get; set; }
    [ForeignKey("OwnerId")]
    public virtual AppUser? Owner { get; set; }

    public virtual ICollection<Budget> Budgets { get; set; } = new List<Budget>();
    public virtual ICollection<Category> InverseParent { get; set; } = new List<Category>();
    public virtual ICollection<Transaction> Transactions { get; set; } = new List<Transaction>();
}
