using Microsoft.EntityFrameworkCore;
using MoneyManager.Application.DTOs.Group;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;

namespace MoneyManager.Infrastructure.Services;

public class GroupService : IGroupService
{
    private readonly MoneyManagerDbContext _context;
    private readonly IGroupHubNotifier? _groupHubNotifier;

    public GroupService(MoneyManagerDbContext context, IGroupHubNotifier? groupHubNotifier = null)
    {
        _context = context;
        _groupHubNotifier = groupHubNotifier;
    }

    public async Task<List<GroupResponse>> GetGroupsAsync(Guid userId)
    {
        var groups = await _context.GroupMembers
            .Include(gm => gm.Group)
            .ThenInclude(g => g!.CreatedByUser)
            .Include(gm => gm.Group)
            .ThenInclude(g => g!.GroupMembers)
            .Where(gm => gm.UserId == userId && !gm.IsDeleted && !gm.Group!.IsDeleted)
            .Select(gm => new { gm.Group, gm.Role })
            .ToListAsync();

        var result = new List<GroupResponse>();

        foreach (var item in groups)
        {
            var group = item.Group!;
            var (totalIncome, totalExpense) = await CalculateGroupTotalsAsync(group.Id);

            result.Add(new GroupResponse
            {
                Id = group.Id,
                Name = group.Name,
                Description = group.Description,
                InviteCode = item.Role == GroupRole.Admin ? group.InviteCode : null,
                MemberCount = group.GroupMembers.Count(m => !m.IsDeleted),
                CurrentUserRole = item.Role.ToString(),
                CreatedByUserId = group.CreatedByUserId,
                CreatedByUserName = group.CreatedByUser?.FullName,
                TotalExpense = totalExpense,
                TotalIncome = totalIncome,
                CreatedAt = group.CreatedAt,
                LastUpdatedAt = group.LastUpdatedAt
            });
        }

        return result;
    }

    public async Task<GroupDetailResponse?> GetGroupByIdAsync(Guid groupId, Guid userId)
    {
        // Check user là thành viên
        var membership = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == groupId && gm.UserId == userId && !gm.IsDeleted);

        if (membership == null) return null;

        var group = await _context.Groups
            .Include(g => g.CreatedByUser)
            .Include(g => g.GroupMembers.Where(m => !m.IsDeleted))
            .ThenInclude(m => m.User)
            .FirstOrDefaultAsync(g => g.Id == groupId && !g.IsDeleted);

        if (group == null) return null;

        var (totalIncome, totalExpense) = await CalculateGroupTotalsAsync(groupId);
        var members = await GetGroupMembersAsync(groupId, userId);

        return new GroupDetailResponse
        {
            Id = group.Id,
            Name = group.Name,
            Description = group.Description,
            InviteCode = membership.Role == GroupRole.Admin ? group.InviteCode : null,
            MemberCount = group.GroupMembers.Count,
            CurrentUserRole = membership.Role.ToString(),
            CreatedByUserId = group.CreatedByUserId,
            CreatedByUserName = group.CreatedByUser?.FullName,
            TotalExpense = totalExpense,
            TotalIncome = totalIncome,
            CreatedAt = group.CreatedAt,
            LastUpdatedAt = group.LastUpdatedAt,
            Members = members
        };
    }

    public async Task<GroupResponse> CreateGroupAsync(CreateGroupRequest request, Guid userId, bool isPremium)
    {
        // Check Premium
        if (!isPremium)
        {
            throw new InvalidOperationException(
                "Chỉ tài khoản Premium mới có thể tạo nhóm. Vui lòng nâng cấp để sử dụng tính năng này.");
        }

        var group = new Group
        {
            Id = request.Id ?? Guid.NewGuid(),
            Name = request.Name,
            Description = request.Description,
            InviteCode = GenerateInviteCode(),
            CreatedByUserId = userId,
            CreatedAt = DateTime.UtcNow,
            LastUpdatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        // Thêm người tạo làm Admin
        var membership = new GroupMember
        {
            Id = Guid.NewGuid(),
            GroupId = group.Id,
            UserId = userId,
            Role = GroupRole.Admin,
            JoinedAt = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow,
            LastUpdatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.Groups.Add(group);
        _context.GroupMembers.Add(membership);
        await _context.SaveChangesAsync();

        return new GroupResponse
        {
            Id = group.Id,
            Name = group.Name,
            Description = group.Description,
            InviteCode = group.InviteCode,
            MemberCount = 1,
            CurrentUserRole = "Admin",
            CreatedByUserId = userId,
            TotalExpense = 0,
            TotalIncome = 0,
            CreatedAt = group.CreatedAt,
            LastUpdatedAt = group.LastUpdatedAt
        };
    }

    public async Task<GroupResponse> UpdateGroupAsync(Guid groupId, UpdateGroupRequest request, Guid userId)
    {
        var membership = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == groupId && gm.UserId == userId && !gm.IsDeleted);

        if (membership == null)
        {
            throw new KeyNotFoundException("Bạn không phải thành viên của nhóm này.");
        }

        if (membership.Role != GroupRole.Admin)
        {
            throw new UnauthorizedAccessException("Chỉ Admin mới có thể sửa thông tin nhóm.");
        }

        var group = await _context.Groups.FirstOrDefaultAsync(g => g.Id == groupId && !g.IsDeleted);
        if (group == null)
        {
            throw new KeyNotFoundException("Không tìm thấy nhóm.");
        }

        if (!string.IsNullOrEmpty(request.Name))
            group.Name = request.Name;

        if (request.Description != null)
            group.Description = request.Description;

        group.LastUpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        
        // Notify group members about update
        if (_groupHubNotifier != null)
        {
            await _groupHubNotifier.NotifyGroupUpdatedAsync(groupId.ToString(), group.Name);
        }

        var (totalIncome, totalExpense) = await CalculateGroupTotalsAsync(groupId);
        var memberCount = await _context.GroupMembers.CountAsync(m => m.GroupId == groupId && !m.IsDeleted);

        return new GroupResponse
        {
            Id = group.Id,
            Name = group.Name,
            Description = group.Description,
            InviteCode = group.InviteCode,
            MemberCount = memberCount,
            CurrentUserRole = "Admin",
            CreatedByUserId = group.CreatedByUserId,
            TotalExpense = totalExpense,
            TotalIncome = totalIncome,
            CreatedAt = group.CreatedAt,
            LastUpdatedAt = group.LastUpdatedAt
        };
    }

    public async Task<bool> DeleteGroupAsync(Guid groupId, Guid userId)
    {
        var group = await _context.Groups.FirstOrDefaultAsync(g => g.Id == groupId && !g.IsDeleted);
        if (group == null) return false;

        // Chỉ người tạo mới xóa được
        if (group.CreatedByUserId != userId)
        {
            throw new UnauthorizedAccessException("Chỉ người tạo nhóm mới có thể xóa nhóm.");
        }

        // Soft delete nhóm và tất cả thành viên
        group.IsDeleted = true;
        group.LastUpdatedAt = DateTime.UtcNow;

        var members = await _context.GroupMembers.Where(m => m.GroupId == groupId).ToListAsync();
        foreach (var member in members)
        {
            member.IsDeleted = true;
            member.LastUpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<GroupResponse> JoinGroupAsync(JoinGroupRequest request, Guid userId)
    {
        var group = await _context.Groups
            .Include(g => g.CreatedByUser)
            .FirstOrDefaultAsync(g => g.InviteCode == request.InviteCode.ToUpper() && !g.IsDeleted);

        if (group == null)
        {
            throw new KeyNotFoundException("Mã mời không hợp lệ hoặc nhóm không tồn tại.");
        }

        // Check đã là thành viên chưa
        var existingMember = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == group.Id && gm.UserId == userId);

        if (existingMember != null)
        {
            if (!existingMember.IsDeleted)
            {
                throw new InvalidOperationException("Bạn đã là thành viên của nhóm này.");
            }
            else
            {
                // Rejoin
                existingMember.IsDeleted = false;
                existingMember.JoinedAt = DateTime.UtcNow;
                existingMember.LastUpdatedAt = DateTime.UtcNow;
            }
        }
        else
        {
            var membership = new GroupMember
            {
                Id = Guid.NewGuid(),
                GroupId = group.Id,
                UserId = userId,
                Role = GroupRole.Member,
                JoinedAt = DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow,
                LastUpdatedAt = DateTime.UtcNow,
                IsDeleted = false
            };
            _context.GroupMembers.Add(membership);
        }

        await _context.SaveChangesAsync();

        var memberCount = await _context.GroupMembers.CountAsync(m => m.GroupId == group.Id && !m.IsDeleted);
        var (totalIncome, totalExpense) = await CalculateGroupTotalsAsync(group.Id);
        
        // Get user info for notification
        var user = await _context.Users.FindAsync(userId);
        
        // Notify group members about new member
        if (_groupHubNotifier != null)
        {
            await _groupHubNotifier.NotifyMemberJoinedAsync(
                group.Id.ToString(), 
                userId.ToString(), 
                user?.FullName ?? "Thành viên mới"
            );
        }

        return new GroupResponse
        {
            Id = group.Id,
            Name = group.Name,
            Description = group.Description,
            InviteCode = null, // Member không thấy invite code
            MemberCount = memberCount,
            CurrentUserRole = "Member",
            CreatedByUserId = group.CreatedByUserId,
            CreatedByUserName = group.CreatedByUser?.FullName,
            TotalExpense = totalExpense,
            TotalIncome = totalIncome,
            CreatedAt = group.CreatedAt,
            LastUpdatedAt = group.LastUpdatedAt
        };
    }

    public async Task<bool> LeaveGroupAsync(Guid groupId, Guid userId)
    {
        var membership = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == groupId && gm.UserId == userId && !gm.IsDeleted);

        if (membership == null) return false;

        // Check nếu là Admin duy nhất
        if (membership.Role == GroupRole.Admin)
        {
            var otherAdmins = await _context.GroupMembers
                .CountAsync(m => m.GroupId == groupId 
                               && m.UserId != userId 
                               && m.Role == GroupRole.Admin 
                               && !m.IsDeleted);

            if (otherAdmins == 0)
            {
                throw new InvalidOperationException(
                    "Bạn là Admin duy nhất. Hãy chỉ định Admin mới trước khi rời nhóm.");
            }
        }

        membership.IsDeleted = true;
        membership.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        
        // Notify group members about member leaving
        if (_groupHubNotifier != null)
        {
            await _groupHubNotifier.NotifyMemberLeftAsync(groupId.ToString(), userId.ToString());
        }
        
        return true;
    }

    public async Task<List<GroupMemberResponse>> GetGroupMembersAsync(Guid groupId, Guid userId)
    {
        // Check user là thành viên
        var isMember = await _context.GroupMembers
            .AnyAsync(gm => gm.GroupId == groupId && gm.UserId == userId && !gm.IsDeleted);

        if (!isMember)
        {
            throw new UnauthorizedAccessException("Bạn không phải thành viên của nhóm này.");
        }

        var members = await _context.GroupMembers
            .Include(gm => gm.User)
            .Where(gm => gm.GroupId == groupId && !gm.IsDeleted)
            .ToListAsync();

        var result = new List<GroupMemberResponse>();

        foreach (var member in members)
        {
            var contribution = await _context.Transactions
                .Where(t => t.GroupId == groupId 
                           && t.Wallet!.OwnerId == member.UserId 
                           && !t.IsDeleted)
                .SumAsync(t => t.Amount);

            result.Add(new GroupMemberResponse
            {
                UserId = member.UserId,
                FullName = member.User?.FullName,
                Email = member.User?.Email,
                AvatarUrl = member.User?.AvatarUrl,
                Role = member.Role.ToString(),
                JoinedAt = member.JoinedAt,
                TotalContribution = contribution
            });
        }

        return result.OrderByDescending(m => m.Role == "Admin").ThenBy(m => m.JoinedAt).ToList();
    }

    public async Task<bool> KickMemberAsync(Guid groupId, Guid memberUserId, Guid adminUserId)
    {
        // Check admin quyền
        var adminMembership = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == groupId && gm.UserId == adminUserId && !gm.IsDeleted);

        if (adminMembership == null || adminMembership.Role != GroupRole.Admin)
        {
            throw new UnauthorizedAccessException("Chỉ Admin mới có thể kick thành viên.");
        }

        // Không kick được chính mình
        if (memberUserId == adminUserId)
        {
            throw new InvalidOperationException("Không thể kick chính mình.");
        }

        var memberToKick = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == groupId && gm.UserId == memberUserId && !gm.IsDeleted);

        if (memberToKick == null) return false;

        memberToKick.IsDeleted = true;
        memberToKick.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        
        // Notify group members about kicked member
        if (_groupHubNotifier != null)
        {
            await _groupHubNotifier.NotifyMemberKickedAsync(groupId.ToString(), memberUserId.ToString());
        }
        
        return true;
    }

    public async Task<bool> ChangeRoleAsync(Guid groupId, Guid memberUserId, string newRole, Guid adminUserId)
    {
        // Check admin quyền
        var adminMembership = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == groupId && gm.UserId == adminUserId && !gm.IsDeleted);

        if (adminMembership == null || adminMembership.Role != GroupRole.Admin)
        {
            throw new UnauthorizedAccessException("Chỉ Admin mới có thể thay đổi vai trò.");
        }

        if (!Enum.TryParse<GroupRole>(newRole, true, out var role))
        {
            throw new ArgumentException("Vai trò không hợp lệ. Sử dụng Admin hoặc Member.");
        }

        var member = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == groupId && gm.UserId == memberUserId && !gm.IsDeleted);

        if (member == null) return false;

        member.Role = role;
        member.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<string> RegenerateInviteCodeAsync(Guid groupId, Guid userId)
    {
        var membership = await _context.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == groupId && gm.UserId == userId && !gm.IsDeleted);

        if (membership == null || membership.Role != GroupRole.Admin)
        {
            throw new UnauthorizedAccessException("Chỉ Admin mới có thể tạo mã mời mới.");
        }

        var group = await _context.Groups.FirstOrDefaultAsync(g => g.Id == groupId && !g.IsDeleted);
        if (group == null)
        {
            throw new KeyNotFoundException("Không tìm thấy nhóm.");
        }

        group.InviteCode = GenerateInviteCode();
        group.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return group.InviteCode;
    }

    // ===== HELPER METHODS =====

    private static string GenerateInviteCode()
    {
        const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var random = new Random();
        return new string(Enumerable.Repeat(chars, 8).Select(s => s[random.Next(s.Length)]).ToArray());
    }

    private async Task<(decimal TotalIncome, decimal TotalExpense)> CalculateGroupTotalsAsync(Guid groupId)
    {
        var transactions = await _context.Transactions
            .Include(t => t.Category)
            .Where(t => t.GroupId == groupId && !t.IsDeleted)
            .ToListAsync();

        var totalIncome = transactions.Where(t => t.Category?.Type == CategoryType.Income).Sum(t => t.Amount);
        var totalExpense = transactions.Where(t => t.Category?.Type == CategoryType.Expense).Sum(t => t.Amount);

        return (totalIncome, totalExpense);
    }
}
