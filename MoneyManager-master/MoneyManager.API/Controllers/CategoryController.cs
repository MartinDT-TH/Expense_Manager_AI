using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Category;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class CategoryController : ControllerBase
{
    private readonly ICategoryService _categoryService;
    private readonly UserManager<AppUser> _userManager;

    public CategoryController(ICategoryService categoryService, UserManager<AppUser> userManager)
    {
        _categoryService = categoryService;
        _userManager = userManager;
    }

    private async Task<AppUser?> GetCurrentUserAsync()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userId)) return null;
        return await _userManager.FindByIdAsync(userId);
    }

    /// <summary>
    /// GET: api/Category/system
    /// Lấy tất cả danh mục hệ thống (Public - không cần login)
    /// </summary>
    [HttpGet("system")]
    [AllowAnonymous]
    public async Task<IActionResult> GetSystemCategories()
    {
        var categories = await _categoryService.GetSystemCategoriesAsync();
        return Ok(categories);
    }

    /// <summary>
    /// GET: api/Category/system/expense
    /// Lấy danh mục Chi tiêu hệ thống (Public)
    /// </summary>
    [HttpGet("system/expense")]
    [AllowAnonymous]
    public async Task<IActionResult> GetSystemExpenseCategories()
    {
        var categories = await _categoryService.GetSystemCategoriesByTypeAsync("Expense");
        return Ok(categories);
    }

    /// <summary>
    /// GET: api/Category/system/income
    /// Lấy danh mục Thu nhập hệ thống (Public)
    /// </summary>
    [HttpGet("system/income")]
    [AllowAnonymous]
    public async Task<IActionResult> GetSystemIncomeCategories()
    {
        var categories = await _categoryService.GetSystemCategoriesByTypeAsync("Income");
        return Ok(categories);
    }

    /// <summary>
    /// GET: api/Category
    /// Lấy tất cả danh mục (System + Custom)
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetCategories()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var categories = await _categoryService.GetAllCategoriesAsync(user.Id);
        return Ok(categories);
    }

    /// <summary>
    /// GET: api/Category/grouped
    /// Lấy danh mục đã group theo Thu/Chi
    /// </summary>
    [HttpGet("grouped")]
    public async Task<IActionResult> GetCategoriesGrouped()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var result = await _categoryService.GetCategoriesGroupedAsync(user.Id);
        return Ok(result);
    }

    /// <summary>
    /// GET: api/Category/expense
    /// Lấy danh mục Chi tiêu
    /// </summary>
    [HttpGet("expense")]
    public async Task<IActionResult> GetExpenseCategories()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var categories = await _categoryService.GetCategoriesByTypeAsync(user.Id, "Expense");
        return Ok(categories);
    }

    /// <summary>
    /// GET: api/Category/income
    /// Lấy danh mục Thu nhập
    /// </summary>
    [HttpGet("income")]
    public async Task<IActionResult> GetIncomeCategories()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var categories = await _categoryService.GetCategoriesByTypeAsync(user.Id, "Income");
        return Ok(categories);
    }

    /// <summary>
    /// GET: api/Category/{id}
    /// Lấy chi tiết danh mục
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetCategory(Guid id)
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var category = await _categoryService.GetCategoryByIdAsync(id, user.Id);
        if (category == null)
        {
            return NotFound(new { message = "Category not found." });
        }

        return Ok(category);
    }

    /// <summary>
    /// POST: api/Category
    /// Tạo danh mục mới (custom của user)
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateCategory([FromBody] CreateCategoryRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var category = await _categoryService.CreateCategoryAsync(request, user.Id);
            return CreatedAtAction(nameof(GetCategory), new { id = category.Id }, category);
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
    /// PUT: api/Category/{id}
    /// Cập nhật danh mục (chỉ custom, không sửa được system)
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCategory(Guid id, [FromBody] UpdateCategoryRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var category = await _categoryService.UpdateCategoryAsync(id, request, user.Id);
            return Ok(category);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
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
    /// DELETE: api/Category/{id}
    /// Xóa danh mục (chỉ custom, không xóa được system)
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCategory(Guid id)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var result = await _categoryService.DeleteCategoryAsync(id, user.Id);
            if (!result)
            {
                return NotFound(new { message = "Category not found." });
            }

            return Ok(new { message = "Category deleted successfully." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
