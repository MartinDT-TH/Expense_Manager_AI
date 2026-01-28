using Microsoft.EntityFrameworkCore;
using MoneyManager.Application.DTOs.Category;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;

namespace MoneyManager.Infrastructure.Services;

public class CategoryService : ICategoryService
{
    private readonly MoneyManagerDbContext _context;

    public CategoryService(MoneyManagerDbContext context)
    {
        _context = context;
    }

    public async Task<List<CategoryResponse>> GetAllCategoriesAsync(Guid userId)
    {
        // Lấy danh mục hệ thống (OwnerId = null) + danh mục của user
        var categories = await _context.Categories
            .Where(c => (c.OwnerId == null || c.OwnerId == userId) && !c.IsDeleted)
            .Include(c => c.Parent)
            .OrderBy(c => c.Type)
            .ThenBy(c => c.Name)
            .ToListAsync();

        return categories.Select(c => MapToResponse(c)).ToList();
    }

    public async Task<List<CategoryResponse>> GetCategoriesByTypeAsync(Guid userId, string type)
    {
        if (!Enum.TryParse<CategoryType>(type, true, out var categoryType))
        {
            throw new ArgumentException("Invalid category type. Use EXPENSE or INCOME.");
        }

        var categories = await _context.Categories
            .Where(c => (c.OwnerId == null || c.OwnerId == userId) 
                        && c.Type == categoryType 
                        && !c.IsDeleted
                        && c.ParentId == null) // Chỉ lấy danh mục cha
            .Include(c => c.InverseParent.Where(child => !child.IsDeleted)) // Include children
            .OrderBy(c => c.Name)
            .ToListAsync();

        return categories.Select(c => MapToResponseWithChildren(c)).ToList();
    }

    public async Task<CategoriesGroupedResponse> GetCategoriesGroupedAsync(Guid userId)
    {
        var allCategories = await GetAllCategoriesAsync(userId);

        return new CategoriesGroupedResponse
        {
            ExpenseCategories = allCategories.Where(c => c.Type == "Expense").ToList(),
            IncomeCategories = allCategories.Where(c => c.Type == "Income").ToList()
        };
    }

    public async Task<CategoryResponse?> GetCategoryByIdAsync(Guid categoryId, Guid userId)
    {
        var category = await _context.Categories
            .Include(c => c.Parent)
            .FirstOrDefaultAsync(c => c.Id == categoryId 
                                      && (c.OwnerId == null || c.OwnerId == userId) 
                                      && !c.IsDeleted);

        return category == null ? null : MapToResponse(category);
    }

    public async Task<CategoryResponse> CreateCategoryAsync(CreateCategoryRequest request, Guid userId)
    {
        // Parse Type
        if (!Enum.TryParse<CategoryType>(request.Type, true, out var categoryType))
        {
            categoryType = CategoryType.Expense;
        }

        // Validate ParentId nếu có
        if (request.ParentId.HasValue)
        {
            var parent = await _context.Categories
                .FirstOrDefaultAsync(c => c.Id == request.ParentId.Value && !c.IsDeleted);
            
            if (parent == null)
            {
                throw new KeyNotFoundException("Parent category not found.");
            }

            // Child category must have same type as parent
            if (parent.Type != categoryType)
            {
                throw new InvalidOperationException("Child category must have the same type (Income/Expense) as parent.");
            }
        }

        var category = new Category
        {
            Id = request.Id ?? Guid.NewGuid(),
            Name = request.Name,
            IconCode = request.IconCode,
            Type = categoryType,
            ParentId = request.ParentId,
            OwnerId = userId, // Danh mục của user
            CreatedAt = DateTime.UtcNow,
            LastUpdatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.Categories.Add(category);
        await _context.SaveChangesAsync();

        return MapToResponse(category);
    }

    public async Task<CategoryResponse> UpdateCategoryAsync(Guid categoryId, UpdateCategoryRequest request, Guid userId)
    {
        var category = await _context.Categories
            .FirstOrDefaultAsync(c => c.Id == categoryId && !c.IsDeleted);

        if (category == null)
        {
            throw new KeyNotFoundException("Category not found.");
        }

        // Cannot edit system categories
        if (category.OwnerId == null)
        {
            throw new InvalidOperationException("Cannot edit system categories.");
        }

        // Only owner can edit
        if (category.OwnerId != userId)
        {
            throw new UnauthorizedAccessException("You don't have permission to edit this category.");
        }

        // Update fields
        if (!string.IsNullOrEmpty(request.Name))
            category.Name = request.Name;

        if (request.IconCode != null)
            category.IconCode = request.IconCode;

        if (request.ParentId.HasValue)
        {
            // Validate parent
            var parent = await _context.Categories
                .FirstOrDefaultAsync(c => c.Id == request.ParentId.Value && !c.IsDeleted);
            
            if (parent == null)
            {
                throw new KeyNotFoundException("Parent category not found.");
            }

            if (parent.Type != category.Type)
            {
                throw new InvalidOperationException("Child category must have the same type as parent.");
            }

            category.ParentId = request.ParentId;
        }

        category.LastUpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return MapToResponse(category);
    }

    public async Task<bool> DeleteCategoryAsync(Guid categoryId, Guid userId)
    {
        var category = await _context.Categories
            .FirstOrDefaultAsync(c => c.Id == categoryId && !c.IsDeleted);

        if (category == null)
        {
            return false;
        }

        // Cannot delete system categories
        if (category.OwnerId == null)
        {
            throw new InvalidOperationException("Cannot delete system categories.");
        }

        // Only owner can delete
        if (category.OwnerId != userId)
        {
            throw new UnauthorizedAccessException("You don't have permission to delete this category.");
        }

        // Check if category has transactions
        var hasTransactions = await _context.Transactions
            .AnyAsync(t => t.CategoryId == categoryId && !t.IsDeleted);

        if (hasTransactions)
        {
            throw new InvalidOperationException(
                "Cannot delete category with existing transactions. Please move transactions to another category first.");
        }

        // Soft delete
        category.IsDeleted = true;
        category.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<List<CategoryResponse>> GetSystemCategoriesAsync()
    {
        // Chỉ lấy danh mục hệ thống (OwnerId = null)
        var categories = await _context.Categories
            .Where(c => c.OwnerId == null && !c.IsDeleted)
            .OrderBy(c => c.Type)
            .ThenBy(c => c.Name)
            .ToListAsync();

        return categories.Select(c => MapToResponse(c)).ToList();
    }

    public async Task<List<CategoryResponse>> GetSystemCategoriesByTypeAsync(string type)
    {
        if (!Enum.TryParse<CategoryType>(type, true, out var categoryType))
        {
            throw new ArgumentException("Invalid category type. Use Expense or Income.");
        }

        var categories = await _context.Categories
            .Where(c => c.OwnerId == null && c.Type == categoryType && !c.IsDeleted)
            .OrderBy(c => c.Name)
            .ToListAsync();

        return categories.Select(c => MapToResponse(c)).ToList();
    }

    // ===== HELPER METHODS =====

    private CategoryResponse MapToResponse(Category category)
    {
        return new CategoryResponse
        {
            Id = category.Id,
            Name = category.Name,
            IconCode = category.IconCode,
            Type = category.Type.ToString(),
            ParentId = category.ParentId,
            ParentName = category.Parent?.Name,
            IsSystemCategory = category.OwnerId == null,
            CreatedAt = category.CreatedAt,
            LastUpdatedAt = category.LastUpdatedAt
        };
    }

    private CategoryResponse MapToResponseWithChildren(Category category)
    {
        var response = MapToResponse(category);
        
        if (category.InverseParent != null && category.InverseParent.Any())
        {
            response.Children = category.InverseParent
                .Where(c => !c.IsDeleted)
                .Select(c => MapToResponse(c))
                .ToList();
        }

        return response;
    }
}
