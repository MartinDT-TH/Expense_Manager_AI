using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Sync;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class SyncController : ControllerBase
{
    private readonly ISyncService _syncService;
    private readonly UserManager<AppUser> _userManager;

    public SyncController(ISyncService syncService, UserManager<AppUser> userManager)
    {
        _syncService = syncService;
        _userManager = userManager;
    }

    private async Task<AppUser?> GetCurrentUserAsync()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userId)) return null;
        return await _userManager.FindByIdAsync(userId);
    }

    /// <summary>
    /// POST: api/Sync/pull
    /// Kéo dữ liệu mới từ server về client
    /// </summary>
    [HttpPost("pull")]
    public async Task<IActionResult> Pull([FromBody] SyncPullRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var response = await _syncService.PullAsync(request, user.Id);
            return Ok(response);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// POST: api/Sync/push
    /// Đẩy dữ liệu từ client lên server
    /// </summary>
    [HttpPost("push")]
    public async Task<IActionResult> Push([FromBody] SyncPushRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var response = await _syncService.PushAsync(request, user.Id, user.IsPremium);
            return Ok(response);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// GET: api/Sync/last-sync
    /// Lấy thời điểm sync lần cuối
    /// </summary>
    [HttpGet("last-sync")]
    public async Task<IActionResult> GetLastSyncTime()
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var lastSync = await _syncService.GetLastSyncTimeAsync(user.Id);
            return Ok(new { lastSyncedAt = lastSync });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
