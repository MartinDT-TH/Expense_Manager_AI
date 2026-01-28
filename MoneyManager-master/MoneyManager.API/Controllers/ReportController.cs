using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Report;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class ReportController : ControllerBase
{
    private readonly IReportService _reportService;
    private readonly UserManager<AppUser> _userManager;

    public ReportController(IReportService reportService, UserManager<AppUser> userManager)
    {
        _reportService = reportService;
        _userManager = userManager;
    }

    private async Task<AppUser?> GetCurrentUserAsync()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userId)) return null;
        return await _userManager.FindByIdAsync(userId);
    }

    /// <summary>
    /// POST: api/Report/summary
    /// Lấy báo cáo tổng quan
    /// </summary>
    [HttpPost("summary")]
    public async Task<IActionResult> GetSummary([FromBody] ReportFilterRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var report = await _reportService.GetSummaryAsync(request, user.Id);
            return Ok(report);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// POST: api/Report/by-category
    /// Lấy báo cáo theo danh mục
    /// </summary>
    [HttpPost("by-category")]
    public async Task<IActionResult> GetByCategory([FromBody] ReportFilterRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var report = await _reportService.GetByCategoryAsync(request, user.Id);
            return Ok(report);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// POST: api/Report/by-time
    /// Lấy báo cáo theo thời gian
    /// </summary>
    /// <param name="groupBy">daily, weekly, monthly</param>
    [HttpPost("by-time")]
    public async Task<IActionResult> GetByTime(
        [FromBody] ReportFilterRequest request,
        [FromQuery] string groupBy = "daily")
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var report = await _reportService.GetByTimeAsync(request, user.Id, groupBy);
            return Ok(report);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// GET: api/Report/trend
    /// Lấy xu hướng chi tiêu (Premium only)
    /// </summary>
    [HttpGet("trend")]
    public async Task<IActionResult> GetTrend()
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            if (!user.IsPremium)
            {
                return BadRequest(new { message = "Tính năng phân tích xu hướng chỉ dành cho Premium.", code = "PREMIUM_REQUIRED" });
            }

            var report = await _reportService.GetTrendAsync(user.Id);
            return Ok(report);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// POST: api/Report/export
    /// Xuất báo cáo (Premium only)
    /// </summary>
    [HttpPost("export")]
    public async Task<IActionResult> Export([FromBody] ExportReportRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var report = await _reportService.ExportAsync(request, user.Id, user.IsPremium);
            return Ok(report);
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
    /// GET: api/Report/quick-summary
    /// Lấy tổng quan nhanh (tuần này)
    /// </summary>
    [HttpGet("quick-summary")]
    public async Task<IActionResult> GetQuickSummary()
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var today = DateTime.UtcNow.Date;
            var startOfWeek = today.AddDays(-(int)today.DayOfWeek + 1); // Monday
            var endOfWeek = startOfWeek.AddDays(6); // Sunday

            var request = new ReportFilterRequest
            {
                StartDate = startOfWeek,
                EndDate = endOfWeek
            };

            var report = await _reportService.GetSummaryAsync(request, user.Id);
            return Ok(report);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// GET: api/Report/monthly-summary
    /// Lấy tổng quan tháng này
    /// </summary>
    [HttpGet("monthly-summary")]
    public async Task<IActionResult> GetMonthlySummary()
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var today = DateTime.UtcNow;
            var startOfMonth = new DateTime(today.Year, today.Month, 1);
            var endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);

            var request = new ReportFilterRequest
            {
                StartDate = startOfMonth,
                EndDate = endOfMonth
            };

            var report = await _reportService.GetSummaryAsync(request, user.Id);
            return Ok(report);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
