using MoneyManager.Application.DTOs.Group;

namespace MoneyManager.Application.Interfaces;

public interface IGroupService
{
    /// <summary>
    /// Lấy danh sách nhóm mà user tham gia
    /// </summary>
    Task<List<GroupResponse>> GetGroupsAsync(Guid userId);
    
    /// <summary>
    /// Lấy chi tiết nhóm (kèm thành viên)
    /// </summary>
    Task<GroupDetailResponse?> GetGroupByIdAsync(Guid groupId, Guid userId);
    
    /// <summary>
    /// Tạo nhóm mới (Premium only)
    /// </summary>
    Task<GroupResponse> CreateGroupAsync(CreateGroupRequest request, Guid userId, bool isPremium);
    
    /// <summary>
    /// Cập nhật nhóm (chỉ Admin)
    /// </summary>
    Task<GroupResponse> UpdateGroupAsync(Guid groupId, UpdateGroupRequest request, Guid userId);
    
    /// <summary>
    /// Xóa nhóm (chỉ Admin/Creator)
    /// </summary>
    Task<bool> DeleteGroupAsync(Guid groupId, Guid userId);
    
    /// <summary>
    /// Tham gia nhóm bằng InviteCode
    /// </summary>
    Task<GroupResponse> JoinGroupAsync(JoinGroupRequest request, Guid userId);
    
    /// <summary>
    /// Rời nhóm
    /// </summary>
    Task<bool> LeaveGroupAsync(Guid groupId, Guid userId);
    
    /// <summary>
    /// Lấy danh sách thành viên
    /// </summary>
    Task<List<GroupMemberResponse>> GetGroupMembersAsync(Guid groupId, Guid userId);
    
    /// <summary>
    /// Kick thành viên (chỉ Admin)
    /// </summary>
    Task<bool> KickMemberAsync(Guid groupId, Guid memberUserId, Guid adminUserId);
    
    /// <summary>
    /// Thay đổi vai trò thành viên (chỉ Admin)
    /// </summary>
    Task<bool> ChangeRoleAsync(Guid groupId, Guid memberUserId, string newRole, Guid adminUserId);
    
    /// <summary>
    /// Tạo mã mời mới (chỉ Admin)
    /// </summary>
    Task<string> RegenerateInviteCodeAsync(Guid groupId, Guid userId);
}
