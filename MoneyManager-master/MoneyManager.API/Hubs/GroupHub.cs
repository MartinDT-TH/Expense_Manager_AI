using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using MoneyManager.Application.Interfaces;
using System.Security.Claims;

namespace MoneyManager.API.Hubs;

/// <summary>
/// SignalR Hub cho real-time updates trong Group
/// Khi một member thêm transaction, các members khác sẽ được notify
/// </summary>
[Authorize]
public class GroupHub : Hub
{
    private readonly ILogger<GroupHub> _logger;

    public GroupHub(ILogger<GroupHub> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Khi client connect, lấy userId từ JWT token
    /// </summary>
    public override async Task OnConnectedAsync()
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        _logger.LogInformation("User {UserId} connected to GroupHub with ConnectionId {ConnectionId}", 
            userId, Context.ConnectionId);
        
        await base.OnConnectedAsync();
    }

    /// <summary>
    /// Khi client disconnect
    /// </summary>
    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        _logger.LogInformation("User {UserId} disconnected from GroupHub", userId);
        
        await base.OnDisconnectedAsync(exception);
    }

    /// <summary>
    /// Client gọi để join vào group room (subscribe notifications)
    /// </summary>
    public async Task JoinGroup(string groupId)
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        
        await Groups.AddToGroupAsync(Context.ConnectionId, groupId);
        _logger.LogInformation("User {UserId} joined group {GroupId}", userId, groupId);
        
        // Notify other members that someone joined
        await Clients.OthersInGroup(groupId).SendAsync("MemberJoined", new
        {
            GroupId = groupId,
            UserId = userId,
            JoinedAt = DateTime.UtcNow
        });
    }

    /// <summary>
    /// Client gọi để leave group room (unsubscribe notifications)
    /// </summary>
    public async Task LeaveGroup(string groupId)
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupId);
        _logger.LogInformation("User {UserId} left group {GroupId}", userId, groupId);
        
        // Notify other members that someone left
        await Clients.OthersInGroup(groupId).SendAsync("MemberLeft", new
        {
            GroupId = groupId,
            UserId = userId,
            LeftAt = DateTime.UtcNow
        });
    }

    /// <summary>
    /// Server gọi để notify tất cả members trong group có transaction mới
    /// (Được gọi từ TransactionService hoặc Controller)
    /// </summary>
    public async Task NotifyNewTransaction(string groupId, object transaction)
    {
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        _logger.LogInformation("Broadcasting new transaction to group {GroupId} from user {UserId}", 
            groupId, userId);
        
        // Send to all clients in the group except sender
        await Clients.OthersInGroup(groupId).SendAsync("NewTransaction", transaction);
    }

    /// <summary>
    /// Notify khi group được cập nhật (tên, mô tả, etc.)
    /// </summary>
    public async Task NotifyGroupUpdated(string groupId, object groupData)
    {
        _logger.LogInformation("Broadcasting group update to group {GroupId}", groupId);
        await Clients.Group(groupId).SendAsync("GroupUpdated", groupData);
    }

    /// <summary>
    /// Notify khi có member bị kick khỏi group
    /// </summary>
    public async Task NotifyMemberKicked(string groupId, string kickedUserId)
    {
        _logger.LogInformation("Broadcasting member kicked from group {GroupId}: {UserId}", 
            groupId, kickedUserId);
        await Clients.Group(groupId).SendAsync("MemberKicked", new
        {
            GroupId = groupId,
            KickedUserId = kickedUserId,
            KickedAt = DateTime.UtcNow
        });
    }
}

/// <summary>
/// Service để gửi notifications từ bất kỳ đâu trong code
/// Implements interface từ Application layer
/// </summary>
public class GroupHubNotifier : IGroupHubNotifier
{
    private readonly IHubContext<GroupHub> _hubContext;
    private readonly ILogger<GroupHubNotifier> _logger;

    public GroupHubNotifier(IHubContext<GroupHub> hubContext, ILogger<GroupHubNotifier> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    public async Task NotifyNewTransactionAsync(string groupId, string transactionId, decimal amount, string description)
    {
        _logger.LogInformation("Sending NewTransaction notification to group {GroupId}", groupId);
        await _hubContext.Clients.Group(groupId).SendAsync("NewTransaction", new
        {
            GroupId = groupId,
            TransactionId = transactionId,
            Amount = amount,
            Description = description,
            CreatedAt = DateTime.UtcNow
        });
    }

    public async Task NotifyGroupUpdatedAsync(string groupId, string groupName)
    {
        _logger.LogInformation("Sending GroupUpdated notification to group {GroupId}", groupId);
        await _hubContext.Clients.Group(groupId).SendAsync("GroupUpdated", new
        {
            GroupId = groupId,
            GroupName = groupName,
            UpdatedAt = DateTime.UtcNow
        });
    }

    public async Task NotifyMemberKickedAsync(string groupId, string userId)
    {
        _logger.LogInformation("Sending MemberKicked notification to group {GroupId}", groupId);
        await _hubContext.Clients.Group(groupId).SendAsync("MemberKicked", new
        {
            GroupId = groupId,
            KickedUserId = userId,
            KickedAt = DateTime.UtcNow
        });
    }

    public async Task NotifyMemberJoinedAsync(string groupId, string userId, string userName)
    {
        _logger.LogInformation("Sending MemberJoined notification to group {GroupId}", groupId);
        await _hubContext.Clients.Group(groupId).SendAsync("MemberJoined", new
        {
            GroupId = groupId,
            UserId = userId,
            UserName = userName,
            JoinedAt = DateTime.UtcNow
        });
    }
    
    public async Task NotifyMemberLeftAsync(string groupId, string userId)
    {
        _logger.LogInformation("Sending MemberLeft notification to group {GroupId}", groupId);
        await _hubContext.Clients.Group(groupId).SendAsync("MemberLeft", new
        {
            GroupId = groupId,
            UserId = userId,
            LeftAt = DateTime.UtcNow
        });
    }
}
