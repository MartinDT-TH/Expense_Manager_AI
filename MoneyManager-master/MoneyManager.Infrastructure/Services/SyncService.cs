using Microsoft.EntityFrameworkCore;
using MoneyManager.Application.DTOs.Sync;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;

namespace MoneyManager.Infrastructure.Services;

public class SyncService : ISyncService
{
    private readonly MoneyManagerDbContext _context;
    private const int MAX_FREE_WALLETS = 2;

    public SyncService(MoneyManagerDbContext context)
    {
        _context = context;
    }

    public async Task<SyncPullResponse> PullAsync(SyncPullRequest request, Guid userId)
    {
        var serverTimestamp = DateTime.UtcNow;
        var lastSyncedAt = request.LastSyncedAt ?? DateTime.MinValue;

        var response = new SyncPullResponse
        {
            ServerTimestamp = serverTimestamp,
            HasChanges = false,
            Data = new SyncData()
        };

        if (request.EntityTypes == null || request.EntityTypes.Contains("Wallet", StringComparer.OrdinalIgnoreCase))
        {
            var wallets = await _context.Wallets
                .Where(w => w.OwnerId == userId && w.LastUpdatedAt > lastSyncedAt)
                .ToListAsync();

            response.Data.Wallets = wallets.Select(w => new SyncWalletItem
            {
                Id = w.Id,
                Name = w.Name,
                Balance = w.Balance ?? 0,
                Currency = w.Currency.ToString(),
                Type = w.Type,
                IsDeleted = w.IsDeleted,
                LastUpdatedAt = w.LastUpdatedAt
            }).ToList();

            if (response.Data.Wallets.Any()) response.HasChanges = true;
        }

        if (request.EntityTypes == null || request.EntityTypes.Contains("Category", StringComparer.OrdinalIgnoreCase))
        {
            var categories = await _context.Categories
                .Where(c => (c.OwnerId == userId || c.OwnerId == null) && c.LastUpdatedAt > lastSyncedAt)
                .ToListAsync();

            response.Data.Categories = categories.Select(c => new SyncCategoryItem
            {
                Id = c.Id,
                Name = c.Name,
                Type = c.Type.ToString(),
                IconCode = c.IconCode,
                ParentId = c.ParentId,
                IsDeleted = c.IsDeleted,
                LastUpdatedAt = c.LastUpdatedAt
            }).ToList();

            if (response.Data.Categories.Any()) response.HasChanges = true;
        }

        if (request.EntityTypes == null || request.EntityTypes.Contains("Transaction", StringComparer.OrdinalIgnoreCase))
        {
            var walletIds = await _context.Wallets
                .Where(w => w.OwnerId == userId)
                .Select(w => w.Id)
                .ToListAsync();

            var transactions = await _context.Transactions
                .Where(t => walletIds.Contains(t.WalletId) && t.LastUpdatedAt > lastSyncedAt)
                .ToListAsync();

            response.Data.Transactions = transactions.Select(t => new SyncTransactionItem
            {
                Id = t.Id,
                Amount = t.Amount,
                Note = t.Note,
                TransactionDate = t.TransactionDate,
                WalletId = t.WalletId,
                CategoryId = t.CategoryId,
                GroupId = t.GroupId,
                BillImageUrl = t.BillImageUrl,
                IsDeleted = t.IsDeleted,
                LastUpdatedAt = t.LastUpdatedAt
            }).ToList();

            if (response.Data.Transactions.Any()) response.HasChanges = true;
        }

        if (request.EntityTypes == null || request.EntityTypes.Contains("Budget", StringComparer.OrdinalIgnoreCase))
        {
            var budgets = await _context.Budgets
                .Where(b => b.OwnerId == userId && b.LastUpdatedAt > lastSyncedAt)
                .ToListAsync();

            response.Data.Budgets = budgets.Select(b => new SyncBudgetItem
            {
                Id = b.Id,
                CategoryId = b.CategoryId,
                AmountLimit = b.AmountLimit,
                StartDate = b.StartDate,
                EndDate = b.EndDate,
                IsRecurring = b.IsRecurring,
                IsDeleted = b.IsDeleted,
                LastUpdatedAt = b.LastUpdatedAt
            }).ToList();

            if (response.Data.Budgets.Any()) response.HasChanges = true;
        }

        return response;
    }

    public async Task<SyncPushResponse> PushAsync(SyncPushRequest request, Guid userId, bool isPremium)
    {
        var serverTimestamp = DateTime.UtcNow;
        var response = new SyncPushResponse
        {
            Success = true,
            ServerTimestamp = serverTimestamp
        };

        using var transaction = await _context.Database.BeginTransactionAsync();

        try
        {
            if (request.Wallets?.Any() == true)
                response.WalletsSynced = await SyncWalletsAsync(request.Wallets, userId, isPremium, response.Conflicts);

            if (request.Categories?.Any() == true)
                response.CategoriesSynced = await SyncCategoriesAsync(request.Categories, userId);

            if (request.Transactions?.Any() == true)
                response.TransactionsSynced = await SyncTransactionsAsync(request.Transactions, userId);

            if (request.Budgets?.Any() == true)
                response.BudgetsSynced = await SyncBudgetsAsync(request.Budgets, userId);

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync();
            response.Success = false;
            response.Conflicts.Add(new SyncConflict { EntityType = "General", Message = ex.Message, Resolution = "RETRY" });
        }

        return response;
    }

    public async Task<DateTime?> GetLastSyncTimeAsync(Guid userId)
    {
        var walletMax = await _context.Wallets.Where(w => w.OwnerId == userId).MaxAsync(w => (DateTime?)w.LastUpdatedAt);
        var transactionMax = await _context.Transactions.Include(t => t.Wallet).Where(t => t.Wallet!.OwnerId == userId).MaxAsync(t => (DateTime?)t.LastUpdatedAt);
        var budgetMax = await _context.Budgets.Where(b => b.OwnerId == userId).MaxAsync(b => (DateTime?)b.LastUpdatedAt);
        var categoryMax = await _context.Categories.Where(c => c.OwnerId == userId).MaxAsync(c => (DateTime?)c.LastUpdatedAt);
        return new List<DateTime?> { walletMax, transactionMax, budgetMax, categoryMax }.Where(d => d.HasValue).Max();
    }

    private async Task<int> SyncWalletsAsync(List<SyncWalletItem> items, Guid userId, bool isPremium, List<SyncConflict> conflicts)
    {
        int synced = 0;
        foreach (var item in items)
        {
            var existing = await _context.Wallets.FirstOrDefaultAsync(w => w.Id == item.Id);
            if (existing == null)
            {
                if (!isPremium)
                {
                    var activeCount = await _context.Wallets.CountAsync(w => w.OwnerId == userId && !w.IsDeleted);
                    if (activeCount >= MAX_FREE_WALLETS && !item.IsDeleted)
                    {
                        conflicts.Add(new SyncConflict { EntityType = "Wallet", EntityId = item.Id, Message = "Tài khoản miễn phí chỉ được tạo tối đa 2 ví.", Resolution = "SERVER_WIN" });
                        continue;
                    }
                }
                if (!Enum.TryParse<CurrencyCode>(item.Currency, out var currencyCode)) currencyCode = CurrencyCode.VND;
                _context.Wallets.Add(new Wallet { Id = item.Id, Name = item.Name, Balance = item.Balance, Currency = currencyCode, Type = item.Type ?? "CASH", OwnerId = userId, IsDeleted = item.IsDeleted, CreatedAt = DateTime.UtcNow, LastUpdatedAt = DateTime.UtcNow });
                synced++;
            }
            else
            {
                if (existing.OwnerId != userId) { conflicts.Add(new SyncConflict { EntityType = "Wallet", EntityId = item.Id, Message = "Không có quyền truy cập ví này.", Resolution = "SERVER_WIN" }); continue; }
                if (existing.LastUpdatedAt > item.LastUpdatedAt) { conflicts.Add(new SyncConflict { EntityType = "Wallet", EntityId = item.Id, Message = "Server có phiên bản mới hơn.", Resolution = "SERVER_WIN" }); continue; }
                if (!Enum.TryParse<CurrencyCode>(item.Currency, out var currencyCode)) currencyCode = CurrencyCode.VND;
                existing.Name = item.Name; existing.Balance = item.Balance; existing.Currency = currencyCode; existing.Type = item.Type ?? existing.Type; existing.IsDeleted = item.IsDeleted; existing.LastUpdatedAt = DateTime.UtcNow;
                synced++;
            }
        }
        return synced;
    }

    private async Task<int> SyncCategoriesAsync(List<SyncCategoryItem> items, Guid userId)
    {
        int synced = 0;
        foreach (var item in items)
        {
            var existing = await _context.Categories.FirstOrDefaultAsync(c => c.Id == item.Id);
            if (existing == null)
            {
                if (!Enum.TryParse<CategoryType>(item.Type, true, out var type)) type = CategoryType.Expense;
                _context.Categories.Add(new Category { Id = item.Id, Name = item.Name, Type = type, IconCode = item.IconCode, ParentId = item.ParentId, OwnerId = userId, IsDeleted = item.IsDeleted, CreatedAt = DateTime.UtcNow, LastUpdatedAt = DateTime.UtcNow });
                synced++;
            }
            else if (existing.OwnerId == userId && existing.LastUpdatedAt <= item.LastUpdatedAt)
            {
                existing.Name = item.Name; existing.IconCode = item.IconCode; existing.IsDeleted = item.IsDeleted; existing.LastUpdatedAt = DateTime.UtcNow;
                synced++;
            }
        }
        return synced;
    }

    private async Task<int> SyncTransactionsAsync(List<SyncTransactionItem> items, Guid userId)
    {
        int synced = 0;
        var userWalletIds = await _context.Wallets.Where(w => w.OwnerId == userId).Select(w => w.Id).ToListAsync();
        foreach (var item in items)
        {
            if (!userWalletIds.Contains(item.WalletId)) continue;
            var existing = await _context.Transactions.FirstOrDefaultAsync(t => t.Id == item.Id);
            if (existing == null)
            {
                _context.Transactions.Add(new Transaction { Id = item.Id, Amount = item.Amount, Note = item.Note, TransactionDate = item.TransactionDate, WalletId = item.WalletId, CategoryId = item.CategoryId, GroupId = item.GroupId, BillImageUrl = item.BillImageUrl, IsDeleted = item.IsDeleted, CreatedAt = DateTime.UtcNow, LastUpdatedAt = DateTime.UtcNow });
                synced++;
                await UpdateWalletBalanceAsync(item, userId);
            }
            else if (existing.LastUpdatedAt <= item.LastUpdatedAt)
            {
                existing.Amount = item.Amount; existing.Note = item.Note; existing.TransactionDate = item.TransactionDate; existing.CategoryId = item.CategoryId; existing.BillImageUrl = item.BillImageUrl; existing.IsDeleted = item.IsDeleted; existing.LastUpdatedAt = DateTime.UtcNow;
                synced++;
            }
        }
        return synced;
    }

    private async Task<int> SyncBudgetsAsync(List<SyncBudgetItem> items, Guid userId)
    {
        int synced = 0;
        foreach (var item in items)
        {
            var existing = await _context.Budgets.FirstOrDefaultAsync(b => b.Id == item.Id);
            if (existing == null)
            {
                _context.Budgets.Add(new Budget { Id = item.Id, CategoryId = item.CategoryId, OwnerId = userId, AmountLimit = item.AmountLimit, StartDate = item.StartDate, EndDate = item.EndDate, IsDeleted = item.IsDeleted, CreatedAt = DateTime.UtcNow, LastUpdatedAt = DateTime.UtcNow });
                synced++;
            }
            else if (existing.OwnerId == userId && existing.LastUpdatedAt <= item.LastUpdatedAt)
            {
                existing.AmountLimit = item.AmountLimit; existing.StartDate = item.StartDate; existing.EndDate = item.EndDate; existing.IsDeleted = item.IsDeleted; existing.LastUpdatedAt = DateTime.UtcNow;
                synced++;
            }
        }
        return synced;
    }

    private async Task UpdateWalletBalanceAsync(SyncTransactionItem item, Guid userId)
    {
        if (item.IsDeleted) return;
        var wallet = await _context.Wallets.FirstOrDefaultAsync(w => w.Id == item.WalletId && w.OwnerId == userId);
        if (wallet == null) return;
        var category = await _context.Categories.FirstOrDefaultAsync(c => c.Id == item.CategoryId);
        if (category == null) return;
        wallet.Balance = (wallet.Balance ?? 0) + (category.Type == CategoryType.Income ? item.Amount : -item.Amount);
        wallet.LastUpdatedAt = DateTime.UtcNow;
    }
}
