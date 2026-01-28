using System;
using System.Collections.Generic;

namespace MoneyManager.Domain.Entities;

public class SystemAuditLog : BaseSystemEntity
{
    public string? ActorId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string? IpAddress { get; set; }
    public string? Details { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}