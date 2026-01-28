namespace MoneyManager.Application.DTOs.Group;

// ===== REQUEST DTOs =====

/// <summary>
/// Request tạo nhóm mới
/// </summary>
public class CreateGroupRequest
{
    /// <summary>
    /// ID do Client gen (GUID) - Hỗ trợ offline-first
    /// </summary>
    public Guid? Id { get; set; }
    
    /// <summary>
    /// Tên nhóm (VD: "Quỹ gia đình", "Nhóm đi du lịch")
    /// </summary>
    public string Name { get; set; } = string.Empty;
    
    /// <summary>
    /// Mô tả nhóm
    /// </summary>
    public string? Description { get; set; }
}

/// <summary>
/// Request cập nhật nhóm
/// </summary>
public class UpdateGroupRequest
{
    public string? Name { get; set; }
    public string? Description { get; set; }
}

/// <summary>
/// Request tham gia nhóm
/// </summary>
public class JoinGroupRequest
{
    /// <summary>
    /// Mã mời (VD: "FAMILY88")
    /// </summary>
    public string InviteCode { get; set; } = string.Empty;
}

// ===== RESPONSE DTOs =====

/// <summary>
/// Response trả về thông tin nhóm
/// </summary>
public class GroupResponse
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    
    /// <summary>
    /// Mã mời (chỉ Admin mới thấy)
    /// </summary>
    public string? InviteCode { get; set; }
    
    /// <summary>
    /// Số thành viên
    /// </summary>
    public int MemberCount { get; set; }
    
    /// <summary>
    /// Vai trò của user hiện tại trong nhóm
    /// </summary>
    public string CurrentUserRole { get; set; } = string.Empty;
    
    /// <summary>
    /// User tạo nhóm
    /// </summary>
    public Guid CreatedByUserId { get; set; }
    public string? CreatedByUserName { get; set; }
    
    /// <summary>
    /// Tổng chi tiêu nhóm
    /// </summary>
    public decimal TotalExpense { get; set; }
    
    /// <summary>
    /// Tổng thu nhập nhóm
    /// </summary>
    public decimal TotalIncome { get; set; }
    
    public DateTime CreatedAt { get; set; }
    public DateTime LastUpdatedAt { get; set; }
}

/// <summary>
/// Response thông tin thành viên nhóm
/// </summary>
public class GroupMemberResponse
{
    public Guid UserId { get; set; }
    public string? FullName { get; set; }
    public string? Email { get; set; }
    public string? AvatarUrl { get; set; }
    public string Role { get; set; } = string.Empty; // ADMIN, MEMBER
    public DateTime JoinedAt { get; set; }
    
    /// <summary>
    /// Tổng đóng góp của thành viên này
    /// </summary>
    public decimal TotalContribution { get; set; }
}

/// <summary>
/// Response chi tiết nhóm
/// </summary>
public class GroupDetailResponse : GroupResponse
{
    public List<GroupMemberResponse> Members { get; set; } = new();
}
