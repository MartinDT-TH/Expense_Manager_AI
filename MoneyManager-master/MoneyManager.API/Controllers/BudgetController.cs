using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Budget;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class BudgetController : ControllerBase
{
    private readonly IBudgetService _budgetService;
    private readonly UserManager<AppUser> _userManager;

    public BudgetController(IBudgetService budgetService, UserManager<AppUser> userManager)
    {
        _budgetService = budgetService;
        _userManager = userManager;
    }

    private async Task<AppUser?> GetCurrentUserAsync()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userId)) return null;
        return await _userManager.FindByIdAsync(userId);
    }

    /// <summary>
    /// GET: api/Budget
    /// Lấy danh sách ngân sách
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetBudgets()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var budgets = await _budgetService.GetBudgetsAsync(user.Id);
        return Ok(budgets);
    }

    /// <summary>
    /// GET: api/Budget/active
    /// Lấy ngân sách đang hoạt động
    /// </summary>
    [HttpGet("active")]
    public async Task<IActionResult> GetActiveBudgets()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var budgets = await _budgetService.GetActiveBudgetsAsync(user.Id);
        return Ok(budgets);
    }

    /// <summary>
    /// GET: api/Budget/current-month
    /// Lấy ngân sách áp dụng cho tháng hiện tại (ưu tiên budget cụ thể > recurring)
    /// </summary>
    [HttpGet("current-month")]
    public async Task<IActionResult> GetCurrentMonthBudget()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var budget = await _budgetService.GetCurrentMonthBudgetAsync(user.Id);
        if (budget == null)
        {
            return Ok(new { hasbudget = false, message = "Chưa thiết lập ngân sách cho tháng này." });
        }

        return Ok(budget);
    }

    /// <summary>
    /// GET: api/Budget/warnings
    /// Lấy cảnh báo ngân sách (> 80% hoặc vượt quá)
    /// </summary>
    [HttpGet("warnings")]
    public async Task<IActionResult> GetBudgetWarnings()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var warnings = await _budgetService.GetBudgetWarningsAsync(user.Id);
        return Ok(warnings);
    }

    /// <summary>
    /// GET: api/Budget/{id}
    /// Lấy chi tiết ngân sách
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetBudget(Guid id)
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var budget = await _budgetService.GetBudgetByIdAsync(id, user.Id);
        if (budget == null)
        {
            return NotFound(new { message = "Không tìm thấy ngân sách." });
        }

        return Ok(budget);
    }

    /// <summary>
    /// POST: api/Budget
    /// Tạo ngân sách mới
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateBudget([FromBody] CreateBudgetRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var budget = await _budgetService.CreateBudgetAsync(request, user.Id);
            return CreatedAtAction(nameof(GetBudget), new { id = budget.Id }, budget);
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
    /// PUT: api/Budget/{id}
    /// Cập nhật ngân sách
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateBudget(Guid id, [FromBody] UpdateBudgetRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var budget = await _budgetService.UpdateBudgetAsync(id, request, user.Id);
            return Ok(budget);
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
    /// DELETE: api/Budget/{id}
    /// Xóa ngân sách
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteBudget(Guid id)
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var result = await _budgetService.DeleteBudgetAsync(id, user.Id);
        if (!result)
        {
            return NotFound(new { message = "Không tìm thấy ngân sách." });
        }

        return Ok(new { message = "Đã xóa ngân sách thành công." });
    }
}
