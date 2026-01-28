using Microsoft.EntityFrameworkCore;
using MoneyManager.Application.DTOs.Budget;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;

namespace MoneyManager.Infrastructure.Services;

public class BudgetService : IBudgetService
{
    private readonly MoneyManagerDbContext _context;
    private const double WARNING_THRESHOLD = 80.0;

    public BudgetService(MoneyManagerDbContext context)
    {
        _context = context;
    }

    public async Task<List<BudgetResponse>> GetBudgetsAsync(Guid userId)
    {
        var budgets = await _context.Budgets
            .Include(b => b.Category)
            .Where(b => b.OwnerId == userId && !b.IsDeleted)
            .OrderByDescending(b => b.IsRecurring) // Recurring first
            .ThenByDescending(b => b.StartDate)
            .ToListAsync();

        var result = new List<BudgetResponse>();
        foreach (var budget in budgets)
        {
            var spent = await CalculateSpentAsync(budget);
            result.Add(MapToResponse(budget, spent));
        }

        return result;
    }

    public async Task<BudgetResponse?> GetBudgetByIdAsync(Guid budgetId, Guid userId)
    {
        var budget = await _context.Budgets
            .Include(b => b.Category)
            .FirstOrDefaultAsync(b => b.Id == budgetId && b.OwnerId == userId && !b.IsDeleted);

        if (budget == null) return null;

        var spent = await CalculateSpentAsync(budget);
        return MapToResponse(budget, spent);
    }

    /// <summary>
    /// Lấy budget áp dụng cho tháng hiện tại
    /// Ưu tiên: Budget cụ thể cho tháng này > Budget recurring (mặc định)
    /// </summary>
    public async Task<BudgetResponse?> GetCurrentMonthBudgetAsync(Guid userId)
    {
        var now = DateTime.UtcNow;
        var startOfMonth = new DateTime(now.Year, now.Month, 1);
        var endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);

        // 1. Tìm budget cụ thể cho tháng này (IsRecurring = false, CategoryId = null)
        var specificBudget = await _context.Budgets
            .Include(b => b.Category)
            .FirstOrDefaultAsync(b => b.OwnerId == userId 
                                     && !b.IsDeleted
                                     && !b.IsRecurring
                                     && b.CategoryId == null // Monthly total budget
                                     && b.StartDate <= endOfMonth
                                     && b.EndDate >= startOfMonth);

        if (specificBudget != null)
        {
            var spent = await CalculateSpentForMonthAsync(userId, startOfMonth, endOfMonth);
            return MapToResponseWithCustomSpent(specificBudget, spent, startOfMonth, endOfMonth);
        }

        // 2. Không có budget cụ thể -> Tìm budget recurring (mặc định cho mọi tháng)
        var recurringBudget = await _context.Budgets
            .Include(b => b.Category)
            .FirstOrDefaultAsync(b => b.OwnerId == userId 
                                     && !b.IsDeleted
                                     && b.IsRecurring
                                     && b.CategoryId == null); // Monthly total budget

        if (recurringBudget != null)
        {
            var spent = await CalculateSpentForMonthAsync(userId, startOfMonth, endOfMonth);
            return MapToResponseWithCustomSpent(recurringBudget, spent, startOfMonth, endOfMonth);
        }

        return null;
    }

    public async Task<BudgetResponse> CreateBudgetAsync(CreateBudgetRequest request, Guid userId)
    {
        // Nếu có CategoryId, validate Category
        if (request.CategoryId.HasValue)
        {
            var category = await _context.Categories
                .FirstOrDefaultAsync(c => c.Id == request.CategoryId.Value && !c.IsDeleted);

            if (category == null)
            {
                throw new KeyNotFoundException("Không tìm thấy danh mục.");
            }

            if (category.Type != CategoryType.Expense)
            {
                throw new InvalidOperationException("Chỉ có thể tạo ngân sách cho danh mục Chi tiêu.");
            }
        }

        DateTime startDate, endDate;
        
        if (request.IsRecurring)
        {
            // Budget recurring: dùng ngày giả (1/1/2000 - 31/12/9999) để đánh dấu
            startDate = new DateTime(2000, 1, 1);
            endDate = new DateTime(9999, 12, 31);
            
            // Check đã có recurring budget cho category này chưa
            var existingRecurring = await _context.Budgets
                .AnyAsync(b => b.OwnerId == userId 
                              && b.CategoryId == request.CategoryId
                              && b.IsRecurring
                              && !b.IsDeleted);

            if (existingRecurring)
            {
                throw new InvalidOperationException("Đã có ngân sách mặc định cho loại này. Vui lòng cập nhật thay vì tạo mới.");
            }
        }
        else
        {
            // Budget cụ thể cho tháng
            if (!request.StartDate.HasValue || !request.EndDate.HasValue)
            {
                // Nếu không có ngày, mặc định là tháng hiện tại
                var now = DateTime.UtcNow;
                startDate = new DateTime(now.Year, now.Month, 1);
                endDate = startDate.AddMonths(1).AddDays(-1);
            }
            else
            {
                startDate = request.StartDate.Value;
                endDate = request.EndDate.Value;
            }

            if (startDate >= endDate)
            {
                throw new InvalidOperationException("Ngày bắt đầu phải trước ngày kết thúc.");
            }

            // Check trùng budget cho cùng category trong cùng khoảng thời gian
            var existingBudget = await _context.Budgets
                .AnyAsync(b => b.OwnerId == userId 
                              && b.CategoryId == request.CategoryId
                              && !b.IsRecurring
                              && !b.IsDeleted
                              && ((b.StartDate <= startDate && b.EndDate >= startDate)
                                  || (b.StartDate <= endDate && b.EndDate >= endDate)));

            if (existingBudget)
            {
                var message = request.CategoryId.HasValue 
                    ? "Đã có ngân sách cho danh mục này trong khoảng thời gian trùng."
                    : "Đã có ngân sách cho tháng này.";
                throw new InvalidOperationException(message);
            }
        }

        var budget = new Budget
        {
            Id = request.Id ?? Guid.NewGuid(),
            AmountLimit = request.AmountLimit,
            CategoryId = request.CategoryId,
            StartDate = startDate,
            EndDate = endDate,
            IsRecurring = request.IsRecurring,
            OwnerId = userId,
            CreatedAt = DateTime.UtcNow,
            LastUpdatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.Budgets.Add(budget);
        await _context.SaveChangesAsync();

        if (budget.CategoryId.HasValue)
        {
            await _context.Entry(budget).Reference(b => b.Category).LoadAsync();
        }
        var spent = await CalculateSpentAsync(budget);

        return MapToResponse(budget, spent);
    }

    public async Task<BudgetResponse> UpdateBudgetAsync(Guid budgetId, UpdateBudgetRequest request, Guid userId)
    {
        var budget = await _context.Budgets
            .Include(b => b.Category)
            .FirstOrDefaultAsync(b => b.Id == budgetId && b.OwnerId == userId && !b.IsDeleted);

        if (budget == null)
        {
            throw new KeyNotFoundException("Không tìm thấy ngân sách.");
        }

        // Update fields
        if (request.AmountLimit.HasValue)
            budget.AmountLimit = request.AmountLimit.Value;

        if (request.CategoryId.HasValue)
        {
            var category = await _context.Categories
                .FirstOrDefaultAsync(c => c.Id == request.CategoryId.Value && !c.IsDeleted);
            
            if (category == null)
                throw new KeyNotFoundException("Không tìm thấy danh mục.");
            
            if (category.Type != CategoryType.Expense)
                throw new InvalidOperationException("Chỉ có thể tạo ngân sách cho danh mục Chi tiêu.");
            
            budget.CategoryId = request.CategoryId.Value;
            budget.Category = category;
        }

        if (request.IsRecurring.HasValue)
        {
            budget.IsRecurring = request.IsRecurring.Value;
            
            if (request.IsRecurring.Value)
            {
                // Chuyển sang recurring: set ngày giả
                budget.StartDate = new DateTime(2000, 1, 1);
                budget.EndDate = new DateTime(9999, 12, 31);
            }
        }

        if (!budget.IsRecurring)
        {
            if (request.StartDate.HasValue)
                budget.StartDate = request.StartDate.Value;

            if (request.EndDate.HasValue)
                budget.EndDate = request.EndDate.Value;

            // Validate dates for non-recurring
            if (budget.StartDate >= budget.EndDate)
            {
                throw new InvalidOperationException("Ngày bắt đầu phải trước ngày kết thúc.");
            }
        }

        budget.LastUpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        var spent = await CalculateSpentAsync(budget);
        return MapToResponse(budget, spent);
    }

    public async Task<bool> DeleteBudgetAsync(Guid budgetId, Guid userId)
    {
        var budget = await _context.Budgets
            .FirstOrDefaultAsync(b => b.Id == budgetId && b.OwnerId == userId && !b.IsDeleted);

        if (budget == null)
        {
            return false;
        }

        budget.IsDeleted = true;
        budget.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<BudgetWarningResponse> GetBudgetWarningsAsync(Guid userId)
    {
        var today = DateTime.Today;
        
        // Lấy các budget đang trong thời gian hiệu lực
        var budgets = await _context.Budgets
            .Include(b => b.Category)
            .Where(b => b.OwnerId == userId 
                       && !b.IsDeleted
                       && b.StartDate <= today 
                       && b.EndDate >= today)
            .ToListAsync();

        var warningBudgets = new List<BudgetResponse>();
        var exceededBudgets = new List<BudgetResponse>();

        foreach (var budget in budgets)
        {
            var spent = await CalculateSpentAsync(budget);
            var response = MapToResponse(budget, spent);

            if (response.IsExceeded)
            {
                exceededBudgets.Add(response);
            }
            else if (response.IsWarning)
            {
                warningBudgets.Add(response);
            }
        }

        return new BudgetWarningResponse
        {
            WarningBudgets = warningBudgets,
            ExceededBudgets = exceededBudgets,
            TotalWarnings = warningBudgets.Count,
            TotalExceeded = exceededBudgets.Count
        };
    }

    public async Task<List<BudgetResponse>> GetActiveBudgetsAsync(Guid userId)
    {
        var today = DateTime.Today;

        var budgets = await _context.Budgets
            .Include(b => b.Category)
            .Where(b => b.OwnerId == userId 
                       && !b.IsDeleted
                       && b.StartDate <= today 
                       && b.EndDate >= today)
            .ToListAsync();

        var result = new List<BudgetResponse>();
        foreach (var budget in budgets)
        {
            var spent = await CalculateSpentAsync(budget);
            result.Add(MapToResponse(budget, spent));
        }

        return result;
    }

    // ===== HELPER METHODS =====

    /// <summary>
    /// Tính tổng chi tiêu cho budget
    /// Nếu CategoryId null -> tính tổng tất cả chi tiêu (Expense)
    /// Nếu CategoryId có giá trị -> tính chi tiêu theo category đó (bao gồm subcategories)
    /// </summary>
    private async Task<decimal> CalculateSpentAsync(Budget budget)
    {
        if (budget.CategoryId.HasValue)
        {
            // Lấy tổng chi tiêu cho category cụ thể (bao gồm subcategories)
            var categoryIds = new List<Guid> { budget.CategoryId.Value };

            // Lấy thêm các subcategories
            var subCategories = await _context.Categories
                .Where(c => c.ParentId == budget.CategoryId.Value && !c.IsDeleted)
                .Select(c => c.Id)
                .ToListAsync();
            
            categoryIds.AddRange(subCategories);

            var spent = await _context.Transactions
                .Include(t => t.Wallet)
                .Where(t => t.Wallet!.OwnerId == budget.OwnerId
                           && categoryIds.Contains(t.CategoryId)
                           && t.TransactionDate >= budget.StartDate
                           && t.TransactionDate <= budget.EndDate
                           && !t.IsDeleted)
                .SumAsync(t => t.Amount);

            return spent;
        }
        else
        {
            // Tính tổng TẤT CẢ chi tiêu (các category loại Expense)
            var expenseCategories = await _context.Categories
                .Where(c => c.Type == CategoryType.Expense && !c.IsDeleted)
                .Select(c => c.Id)
                .ToListAsync();

            var spent = await _context.Transactions
                .Include(t => t.Wallet)
                .Where(t => t.Wallet!.OwnerId == budget.OwnerId
                           && expenseCategories.Contains(t.CategoryId)
                           && t.TransactionDate >= budget.StartDate
                           && t.TransactionDate <= budget.EndDate
                           && !t.IsDeleted)
                .SumAsync(t => t.Amount);

            return spent;
        }
    }

    private BudgetResponse MapToResponse(Budget budget, decimal spent)
    {
        var remaining = budget.AmountLimit - spent;
        var percentUsed = budget.AmountLimit > 0 
            ? (double)(spent / budget.AmountLimit) * 100 
            : 0;

        return new BudgetResponse
        {
            Id = budget.Id,
            AmountLimit = budget.AmountLimit,
            AmountSpent = spent,
            AmountRemaining = remaining,
            PercentUsed = Math.Round(percentUsed, 2),
            IsWarning = percentUsed >= WARNING_THRESHOLD && percentUsed < 100,
            IsExceeded = percentUsed >= 100,
            IsRecurring = budget.IsRecurring,
            CategoryId = budget.CategoryId,
            CategoryName = budget.CategoryId.HasValue 
                ? (budget.Category?.Name ?? "") 
                : (budget.IsRecurring ? "Ngân sách mặc định" : "Ngân sách tháng"),
            CategoryIcon = budget.Category?.IconCode,
            StartDate = budget.StartDate,
            EndDate = budget.EndDate,
            CreatedAt = budget.CreatedAt,
            LastUpdatedAt = budget.LastUpdatedAt
        };
    }
    
    private BudgetResponse MapToResponseWithCustomSpent(Budget budget, decimal spent, DateTime startDate, DateTime endDate)
    {
        var remaining = budget.AmountLimit - spent;
        var percentUsed = budget.AmountLimit > 0 
            ? (double)(spent / budget.AmountLimit) * 100 
            : 0;

        return new BudgetResponse
        {
            Id = budget.Id,
            AmountLimit = budget.AmountLimit,
            AmountSpent = spent,
            AmountRemaining = remaining,
            PercentUsed = Math.Round(percentUsed, 2),
            IsWarning = percentUsed >= WARNING_THRESHOLD && percentUsed < 100,
            IsExceeded = percentUsed >= 100,
            IsRecurring = budget.IsRecurring,
            CategoryId = budget.CategoryId,
            CategoryName = budget.CategoryId.HasValue 
                ? (budget.Category?.Name ?? "") 
                : (budget.IsRecurring ? "Ngân sách mặc định" : "Ngân sách tháng"),
            CategoryIcon = budget.Category?.IconCode,
            StartDate = startDate, // Use actual month dates
            EndDate = endDate,
            CreatedAt = budget.CreatedAt,
            LastUpdatedAt = budget.LastUpdatedAt
        };
    }
    
    /// <summary>
    /// Tính tổng chi tiêu cho một tháng cụ thể (tất cả expense categories)
    /// </summary>
    private async Task<decimal> CalculateSpentForMonthAsync(Guid userId, DateTime startDate, DateTime endDate)
    {
        var expenseCategories = await _context.Categories
            .Where(c => c.Type == CategoryType.Expense && !c.IsDeleted)
            .Select(c => c.Id)
            .ToListAsync();

        var spent = await _context.Transactions
            .Include(t => t.Wallet)
            .Where(t => t.Wallet!.OwnerId == userId
                       && expenseCategories.Contains(t.CategoryId)
                       && t.TransactionDate >= startDate
                       && t.TransactionDate <= endDate
                       && !t.IsDeleted)
            .SumAsync(t => t.Amount);

        return spent;
    }
}
