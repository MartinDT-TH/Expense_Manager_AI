using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using MoneyManager.Application.DTOs.Budget;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;

namespace MoneyManager.Infrastructure.Services;

public class BudgetService : IBudgetService
{
    private readonly MoneyManagerDbContext _context;
    private readonly IMemoryCache _cache;
    private const double WARNING_THRESHOLD = 80.0;
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    public BudgetService(MoneyManagerDbContext context, IMemoryCache cache)
    {
        _context = context;
        _cache = cache;
    }

    /// <summary>
    /// Invalidate cache for a user when budget or transaction changes
    /// </summary>
    public void InvalidateBudgetCache(Guid userId)
    {
        _cache.Remove($"budget_spent_{userId}");
        _cache.Remove($"budget_current_{userId}");
        _cache.Remove($"budget_analytics_{userId}");
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

            // Lấy thêm các subcategories (cached)
            var subCategoriesCacheKey = $"sub_categories_{budget.CategoryId.Value}";
            if (!_cache.TryGetValue(subCategoriesCacheKey, out List<Guid>? subCategories) || subCategories == null)
            {
                subCategories = await _context.Categories
                    .AsNoTracking()
                    .Where(c => c.ParentId == budget.CategoryId.Value && !c.IsDeleted)
                    .Select(c => c.Id)
                    .ToListAsync();
                
                _cache.Set(subCategoriesCacheKey, subCategories, TimeSpan.FromMinutes(30));
            }
            
            categoryIds.AddRange(subCategories);

            var spent = await _context.Transactions
                .AsNoTracking()
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
            var expenseCategories = await GetExpenseCategoryIdsAsync();

            var spent = await _context.Transactions
                .AsNoTracking()
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
    /// Uses caching for better performance
    /// </summary>
    private async Task<decimal> CalculateSpentForMonthAsync(Guid userId, DateTime startDate, DateTime endDate)
    {
        var cacheKey = $"budget_spent_{userId}_{startDate:yyyyMM}";
        
        if (_cache.TryGetValue(cacheKey, out decimal cachedSpent))
        {
            return cachedSpent;
        }

        var expenseCategories = await GetExpenseCategoryIdsAsync();

        var spent = await _context.Transactions
            .AsNoTracking()
            .Where(t => t.Wallet!.OwnerId == userId
                       && expenseCategories.Contains(t.CategoryId)
                       && t.TransactionDate >= startDate
                       && t.TransactionDate <= endDate
                       && !t.IsDeleted)
            .SumAsync(t => t.Amount);

        // Cache for 5 minutes
        _cache.Set(cacheKey, spent, CacheDuration);

        return spent;
    }

    /// <summary>
    /// Get expense category IDs with caching
    /// </summary>
    private async Task<List<Guid>> GetExpenseCategoryIdsAsync()
    {
        const string cacheKey = "expense_category_ids";
        
        if (_cache.TryGetValue(cacheKey, out List<Guid>? cachedIds) && cachedIds != null)
        {
            return cachedIds;
        }

        var categoryIds = await _context.Categories
            .AsNoTracking()
            .Where(c => c.Type == CategoryType.Expense && !c.IsDeleted)
            .Select(c => c.Id)
            .ToListAsync();

        // Cache for 30 minutes since categories rarely change
        _cache.Set(cacheKey, categoryIds, TimeSpan.FromMinutes(30));

        return categoryIds;
    }

    // ===== ANALYTICS METHODS =====

    public async Task<BudgetHistoryResponse> GetBudgetHistoryAsync(Guid userId, int months = 6)
    {
        var history = new List<BudgetHistoryItem>();
        var now = DateTime.UtcNow;
        
        decimal totalSpent = 0;
        decimal totalBudget = 0;
        int monthsExceeded = 0;

        for (int i = 0; i < months; i++)
        {
            var targetDate = now.AddMonths(-i);
            var startOfMonth = new DateTime(targetDate.Year, targetDate.Month, 1);
            var endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);

            // Get budget for this month
            var budget = await GetBudgetForMonthAsync(userId, startOfMonth, endOfMonth);
            var budgetLimit = budget?.AmountLimit ?? 0;
            
            // Calculate spent for this month
            var spent = await CalculateSpentForMonthAsync(userId, startOfMonth, endOfMonth);
            var remaining = budgetLimit - spent;
            var percentUsed = budgetLimit > 0 ? (double)(spent / budgetLimit) * 100 : 0;
            var wasExceeded = percentUsed >= 100;

            if (wasExceeded) monthsExceeded++;
            totalSpent += spent;
            totalBudget += budgetLimit;

            history.Add(new BudgetHistoryItem
            {
                Year = targetDate.Year,
                Month = targetDate.Month,
                MonthName = targetDate.ToString("MMMM"),
                BudgetLimit = budgetLimit,
                AmountSpent = spent,
                AmountRemaining = remaining,
                PercentUsed = Math.Round(percentUsed, 2),
                WasExceeded = wasExceeded
            });
        }

        return new BudgetHistoryResponse
        {
            History = history,
            AverageMonthlySpending = months > 0 ? totalSpent / months : 0,
            AverageMonthlyBudget = months > 0 ? totalBudget / months : 0,
            MonthsExceeded = monthsExceeded,
            TotalMonths = months
        };
    }

    public async Task<BudgetAnalyticsResponse> GetBudgetAnalyticsAsync(Guid userId)
    {
        var now = DateTime.UtcNow;
        var startOfMonth = new DateTime(now.Year, now.Month, 1);
        var endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);
        var daysInMonth = (endOfMonth - startOfMonth).Days + 1;
        var daysPassed = (now - startOfMonth).Days + 1;
        var daysRemaining = daysInMonth - daysPassed + 1;

        // Get current month budget and spending
        var currentBudget = await GetCurrentMonthBudgetAsync(userId);
        var totalBudgetThisMonth = currentBudget?.AmountLimit ?? 0;
        var totalSpentThisMonth = await CalculateSpentForMonthAsync(userId, startOfMonth, endOfMonth);
        var remainingThisMonth = totalBudgetThisMonth - totalSpentThisMonth;
        var percentUsedThisMonth = totalBudgetThisMonth > 0 
            ? (double)(totalSpentThisMonth / totalBudgetThisMonth) * 100 
            : 0;

        // Calculate daily metrics
        var averageDailySpending = daysPassed > 0 ? totalSpentThisMonth / daysPassed : 0;
        var projectedMonthlySpending = averageDailySpending * daysInMonth;
        var willExceedBudget = projectedMonthlySpending > totalBudgetThisMonth;
        
        // Calculate days until budget exceeded
        var daysUntilExceeded = 0;
        if (averageDailySpending > 0 && remainingThisMonth > 0)
        {
            daysUntilExceeded = (int)(remainingThisMonth / averageDailySpending);
        }

        // Suggested daily limit
        var suggestedDailyLimit = daysRemaining > 0 ? remainingThisMonth / daysRemaining : 0;

        // Get monthly trend (last 6 months)
        var historyResponse = await GetBudgetHistoryAsync(userId, 6);

        // Get category breakdown
        var categoryBreakdown = await GetCategoryBreakdownAsync(userId, startOfMonth, endOfMonth);

        // Generate insight message
        string? insightMessage = null;
        if (percentUsedThisMonth >= 100)
        {
            insightMessage = "Bạn đã vượt ngân sách tháng này. Hãy cân nhắc điều chỉnh chi tiêu.";
        }
        else if (percentUsedThisMonth >= 80)
        {
            insightMessage = $"Bạn đã sử dụng {percentUsedThisMonth:F0}% ngân sách. Còn {daysRemaining} ngày nữa là hết tháng.";
        }
        else if (willExceedBudget)
        {
            insightMessage = $"Với tốc độ chi tiêu hiện tại, bạn có thể vượt ngân sách trong {daysUntilExceeded} ngày.";
        }
        else
        {
            insightMessage = $"Bạn đang chi tiêu hợp lý. Mỗi ngày bạn có thể chi tối đa {suggestedDailyLimit:N0} VND.";
        }

        return new BudgetAnalyticsResponse
        {
            TotalBudgetThisMonth = totalBudgetThisMonth,
            TotalSpentThisMonth = totalSpentThisMonth,
            RemainingThisMonth = remainingThisMonth,
            PercentUsedThisMonth = Math.Round(percentUsedThisMonth, 2),
            MonthlyTrend = historyResponse.History,
            CategoryBreakdown = categoryBreakdown,
            AverageDailySpending = averageDailySpending,
            ProjectedMonthlySpending = projectedMonthlySpending,
            WillExceedBudget = willExceedBudget,
            DaysUntilBudgetExceeded = daysUntilExceeded,
            SuggestedDailyLimit = suggestedDailyLimit > 0 ? suggestedDailyLimit : 0,
            InsightMessage = insightMessage
        };
    }

    public async Task<List<BudgetSuggestion>> GetBudgetSuggestionsAsync(Guid userId)
    {
        var suggestions = new List<BudgetSuggestion>();
        var now = DateTime.UtcNow;

        // Analyze last 3 months spending
        var threeMonthsAgo = now.AddMonths(-3);
        
        // Get expense categories
        var expenseCategories = await _context.Categories
            .Where(c => c.Type == CategoryType.Expense && !c.IsDeleted && c.ParentId == null)
            .ToListAsync();

        foreach (var category in expenseCategories)
        {
            // Get spending for this category over last 3 months
            var categoryIds = new List<Guid> { category.Id };
            var subCategories = await _context.Categories
                .Where(c => c.ParentId == category.Id && !c.IsDeleted)
                .Select(c => c.Id)
                .ToListAsync();
            categoryIds.AddRange(subCategories);

            var monthlySpending = new List<decimal>();
            
            for (int i = 0; i < 3; i++)
            {
                var targetDate = now.AddMonths(-i);
                var startOfMonth = new DateTime(targetDate.Year, targetDate.Month, 1);
                var endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);

                var spent = await _context.Transactions
                    .Include(t => t.Wallet)
                    .Where(t => t.Wallet!.OwnerId == userId
                               && categoryIds.Contains(t.CategoryId)
                               && t.TransactionDate >= startOfMonth
                               && t.TransactionDate <= endOfMonth
                               && !t.IsDeleted)
                    .SumAsync(t => t.Amount);
                    
                monthlySpending.Add(spent);
            }

            if (monthlySpending.Any(s => s > 0))
            {
                var average = monthlySpending.Average();
                var min = monthlySpending.Min();
                var max = monthlySpending.Max();
                
                // Suggest 10% above average for comfort
                var suggested = average * 1.1m;
                
                string reason;
                if (max > average * 1.5m)
                {
                    reason = "Chi tiêu dao động lớn, nên đặt ngân sách cao hơn trung bình.";
                    suggested = average * 1.2m; // Add more buffer
                }
                else if (average < 500000) // Low spending category
                {
                    reason = "Đây là danh mục chi tiêu nhỏ, có thể đặt ngân sách vừa phải.";
                }
                else
                {
                    reason = "Dựa trên chi tiêu trung bình 3 tháng gần nhất.";
                }

                suggestions.Add(new BudgetSuggestion
                {
                    CategoryId = category.Id,
                    CategoryName = category.Name,
                    SuggestedAmount = Math.Round(suggested, 0),
                    AverageSpent = Math.Round(average, 0),
                    MinSpent = Math.Round(min, 0),
                    MaxSpent = Math.Round(max, 0),
                    Reason = reason
                });
            }
        }

        // Also suggest total monthly budget
        var totalMonthlySpending = new List<decimal>();
        for (int i = 0; i < 3; i++)
        {
            var targetDate = now.AddMonths(-i);
            var startOfMonth = new DateTime(targetDate.Year, targetDate.Month, 1);
            var endOfMonth = startOfMonth.AddMonths(1).AddDays(-1);
            var spent = await CalculateSpentForMonthAsync(userId, startOfMonth, endOfMonth);
            totalMonthlySpending.Add(spent);
        }

        if (totalMonthlySpending.Any(s => s > 0))
        {
            var avgTotal = totalMonthlySpending.Average();
            suggestions.Insert(0, new BudgetSuggestion
            {
                CategoryId = null,
                CategoryName = "Tổng ngân sách tháng",
                SuggestedAmount = Math.Round(avgTotal * 1.05m, 0), // 5% buffer for total
                AverageSpent = Math.Round(avgTotal, 0),
                MinSpent = Math.Round(totalMonthlySpending.Min(), 0),
                MaxSpent = Math.Round(totalMonthlySpending.Max(), 0),
                Reason = "Tổng chi tiêu trung bình 3 tháng, cộng thêm 5% dự phòng."
            });
        }

        return suggestions.OrderByDescending(s => s.AverageSpent).ToList();
    }

    private async Task<Budget?> GetBudgetForMonthAsync(Guid userId, DateTime startOfMonth, DateTime endOfMonth)
    {
        // First try specific budget for this month
        var specificBudget = await _context.Budgets
            .FirstOrDefaultAsync(b => b.OwnerId == userId 
                                     && !b.IsDeleted
                                     && !b.IsRecurring
                                     && b.CategoryId == null
                                     && b.StartDate <= endOfMonth
                                     && b.EndDate >= startOfMonth);

        if (specificBudget != null) return specificBudget;

        // Fallback to recurring budget
        return await _context.Budgets
            .FirstOrDefaultAsync(b => b.OwnerId == userId 
                                     && !b.IsDeleted
                                     && b.IsRecurring
                                     && b.CategoryId == null);
    }

    private async Task<List<CategoryBudgetAnalytics>> GetCategoryBreakdownAsync(
        Guid userId, DateTime startOfMonth, DateTime endOfMonth)
    {
        var breakdown = new List<CategoryBudgetAnalytics>();

        // Get all expense categories with their spending
        var expenseCategories = await _context.Categories
            .Where(c => c.Type == CategoryType.Expense && !c.IsDeleted && c.ParentId == null)
            .ToListAsync();

        foreach (var category in expenseCategories)
        {
            // Get category budgets
            var categoryBudget = await _context.Budgets
                .FirstOrDefaultAsync(b => b.OwnerId == userId 
                                         && !b.IsDeleted
                                         && b.CategoryId == category.Id
                                         && (b.IsRecurring 
                                             || (b.StartDate <= endOfMonth && b.EndDate >= startOfMonth)));

            // Get category IDs including subcategories
            var categoryIds = new List<Guid> { category.Id };
            var subCategories = await _context.Categories
                .Where(c => c.ParentId == category.Id && !c.IsDeleted)
                .Select(c => c.Id)
                .ToListAsync();
            categoryIds.AddRange(subCategories);

            // Calculate spent
            var spent = await _context.Transactions
                .Include(t => t.Wallet)
                .Where(t => t.Wallet!.OwnerId == userId
                           && categoryIds.Contains(t.CategoryId)
                           && t.TransactionDate >= startOfMonth
                           && t.TransactionDate <= endOfMonth
                           && !t.IsDeleted)
                .SumAsync(t => t.Amount);

            if (spent > 0 || categoryBudget != null)
            {
                var budgetAmount = categoryBudget?.AmountLimit ?? 0;
                var percentUsed = budgetAmount > 0 ? (double)(spent / budgetAmount) * 100 : 0;

                breakdown.Add(new CategoryBudgetAnalytics
                {
                    CategoryId = category.Id,
                    CategoryName = category.Name,
                    CategoryIcon = category.IconCode,
                    TotalBudget = budgetAmount,
                    TotalSpent = spent,
                    PercentUsed = Math.Round(percentUsed, 2),
                    AverageMonthlySpent = spent // This month's spending
                });
            }
        }

        return breakdown.OrderByDescending(b => b.TotalSpent).ToList();
    }
}
