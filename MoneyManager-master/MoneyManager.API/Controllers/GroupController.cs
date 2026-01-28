using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Group;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class GroupController : ControllerBase
{
    private readonly IGroupService _groupService;
    private readonly UserManager<AppUser> _userManager;

    public GroupController(IGroupService groupService, UserManager<AppUser> userManager)
    {
        _groupService = groupService;
        _userManager = userManager;
    }

    private async Task<AppUser?> GetCurrentUserAsync()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userId)) return null;
        return await _userManager.FindByIdAsync(userId);
    }

    /// <summary>
    /// GET: api/Group
    /// Lấy danh sách nhóm mà user tham gia
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetGroups()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var groups = await _groupService.GetGroupsAsync(user.Id);
        return Ok(groups);
    }

    /// <summary>
    /// GET: api/Group/{id}
    /// Lấy chi tiết nhóm
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetGroup(Guid id)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var group = await _groupService.GetGroupByIdAsync(id, user.Id);
            if (group == null)
            {
                return NotFound(new { message = "Không tìm thấy nhóm hoặc bạn không phải thành viên." });
            }

            return Ok(group);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
    }

    /// <summary>
    /// POST: api/Group
    /// Tạo nhóm mới (Premium only)
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateGroup([FromBody] CreateGroupRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var group = await _groupService.CreateGroupAsync(request, user.Id, user.IsPremium);
            return CreatedAtAction(nameof(GetGroup), new { id = group.Id }, group);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message, code = "PREMIUM_REQUIRED" });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// PUT: api/Group/{id}
    /// Cập nhật nhóm (chỉ Admin)
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateGroup(Guid id, [FromBody] UpdateGroupRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var group = await _groupService.UpdateGroupAsync(id, request, user.Id);
            return Ok(group);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// DELETE: api/Group/{id}
    /// Xóa nhóm (chỉ người tạo)
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteGroup(Guid id)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var result = await _groupService.DeleteGroupAsync(id, user.Id);
            if (!result)
            {
                return NotFound(new { message = "Không tìm thấy nhóm." });
            }

            return Ok(new { message = "Đã xóa nhóm thành công." });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// POST: api/Group/join
    /// Tham gia nhóm bằng InviteCode
    /// </summary>
    [HttpPost("join")]
    public async Task<IActionResult> JoinGroup([FromBody] JoinGroupRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var group = await _groupService.JoinGroupAsync(request, user.Id);
            return Ok(group);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// DELETE: api/Group/{id}/leave
    /// Rời nhóm
    /// </summary>
    [HttpDelete("{id}/leave")]
    public async Task<IActionResult> LeaveGroup(Guid id)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var result = await _groupService.LeaveGroupAsync(id, user.Id);
            if (!result)
            {
                return NotFound(new { message = "Không tìm thấy nhóm hoặc bạn không phải thành viên." });
            }

            return Ok(new { message = "Đã rời nhóm thành công." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// GET: api/Group/{id}/members
    /// Lấy danh sách thành viên
    /// </summary>
    [HttpGet("{id}/members")]
    public async Task<IActionResult> GetGroupMembers(Guid id)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var members = await _groupService.GetGroupMembersAsync(id, user.Id);
            return Ok(members);
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// DELETE: api/Group/{id}/members/{userId}
    /// Kick thành viên (chỉ Admin)
    /// </summary>
    [HttpDelete("{id}/members/{userId}")]
    public async Task<IActionResult> KickMember(Guid id, Guid userId)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var result = await _groupService.KickMemberAsync(id, userId, user.Id);
            if (!result)
            {
                return NotFound(new { message = "Không tìm thấy thành viên." });
            }

            return Ok(new { message = "Đã xóa thành viên khỏi nhóm." });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// PUT: api/Group/{id}/members/{userId}/role
    /// Thay đổi vai trò thành viên
    /// </summary>
    [HttpPut("{id}/members/{userId}/role")]
    public async Task<IActionResult> ChangeRole(Guid id, Guid userId, [FromBody] ChangeRoleRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var result = await _groupService.ChangeRoleAsync(id, userId, request.Role, user.Id);
            if (!result)
            {
                return NotFound(new { message = "Không tìm thấy thành viên." });
            }

            return Ok(new { message = "Đã cập nhật vai trò thành công." });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// POST: api/Group/{id}/regenerate-invite
    /// Tạo mã mời mới (chỉ Admin)
    /// </summary>
    [HttpPost("{id}/regenerate-invite")]
    public async Task<IActionResult> RegenerateInviteCode(Guid id)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var newCode = await _groupService.RegenerateInviteCodeAsync(id, user.Id);
            return Ok(new { inviteCode = newCode });
        }
        catch (UnauthorizedAccessException ex)
        {
            return Forbid(ex.Message);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}

public class ChangeRoleRequest
{
    public string Role { get; set; } = string.Empty;
}
