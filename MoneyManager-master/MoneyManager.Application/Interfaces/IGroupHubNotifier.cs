namespace MoneyManager.Application.Interfaces;

/// <summary>
/// Interface for SignalR Group Hub notifications.
/// Allows services to send real-time updates to group members.
/// </summary>
public interface IGroupHubNotifier
{
    /// <summary>
    /// Notify group members about a new transaction.
    /// </summary>
    Task NotifyNewTransactionAsync(string groupId, string transactionId, decimal amount, string description);
    
    /// <summary>
    /// Notify group members that the group has been updated.
    /// </summary>
    Task NotifyGroupUpdatedAsync(string groupId, string groupName);
    
    /// <summary>
    /// Notify group members that a new member has joined.
    /// </summary>
    Task NotifyMemberJoinedAsync(string groupId, string userId, string userName);
    
    /// <summary>
    /// Notify group members that a member has left.
    /// </summary>
    Task NotifyMemberLeftAsync(string groupId, string userId);
    
    /// <summary>
    /// Notify group members that a member has been kicked.
    /// </summary>
    Task NotifyMemberKickedAsync(string groupId, string userId);
}
