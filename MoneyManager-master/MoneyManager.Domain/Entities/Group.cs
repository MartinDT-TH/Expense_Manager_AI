using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace MoneyManager.Domain.Entities;

public class Group : BaseSyncEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string InviteCode { get; set; } = string.Empty;

    public Guid CreatedByUserId { get; set; }
    [ForeignKey("CreatedByUserId")]
    public virtual AppUser? CreatedByUser { get; set; }

    public virtual ICollection<GroupMember> GroupMembers { get; set; } = new List<GroupMember>();
    public virtual ICollection<Transaction> Transactions { get; set; } = new List<Transaction>();
}