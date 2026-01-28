using MoneyManager.Domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;

namespace MoneyManager.Domain.Entities;

public class GroupMember : BaseSyncEntity
{
    public Guid GroupId { get; set; }
    [ForeignKey("GroupId")]
    public virtual Group? Group { get; set; }

    public Guid UserId { get; set; }
    [ForeignKey("UserId")]
    public virtual AppUser? User { get; set; }

    public GroupRole Role { get; set; } = GroupRole.Member;
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
}