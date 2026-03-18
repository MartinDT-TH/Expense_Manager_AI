using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.User;
using MoneyManager.Application.Interfaces;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class UserController : ControllerBase
{
    private readonly IUserService _userService;

    public UserController(IUserService userService)
    {
        _userService = userService;
    }

    /// <summary>
    /// Lấy thông tin profile của user hiện tại
    /// </summary>
    [HttpGet("profile")]
    public async Task<IActionResult> GetProfile()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _userService.GetProfileAsync(userId.Value);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Cập nhật thông tin profile
    /// </summary>
    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _userService.UpdateProfileAsync(userId.Value, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Đổi mật khẩu
    /// </summary>
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _userService.ChangePasswordAsync(userId.Value, request);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Cập nhật avatar
    /// Upload từ client (Cloudinary) và gửi URL
    /// </summary>
    [HttpPost("avatar")]
    public async Task<IActionResult> UpdateAvatar([FromBody] UploadAvatarRequest request)
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        if (string.IsNullOrEmpty(request.AvatarUrl))
            return BadRequest(new { success = false, message = "Avatar URL is required." });

        var result = await _userService.UpdateAvatarAsync(userId.Value, request.AvatarUrl);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>
    /// Xóa avatar
    /// </summary>
    [HttpDelete("avatar")]
    public async Task<IActionResult> DeleteAvatar()
    {
        var userId = GetUserId();
        if (userId == null)
            return Unauthorized();

        var result = await _userService.DeleteAvatarAsync(userId.Value);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    private Guid? GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }
}
