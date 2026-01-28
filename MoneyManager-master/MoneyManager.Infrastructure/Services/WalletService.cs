using Microsoft.EntityFrameworkCore;
using MoneyManager.Application.DTOs.Wallet;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;

namespace MoneyManager.Infrastructure.Services;

public class WalletService : IWalletService
{
    private readonly MoneyManagerDbContext _context;
    private const int MAX_FREE_WALLETS = 2;

    public WalletService(MoneyManagerDbContext context)
    {
        _context = context;
    }

    public async Task<List<WalletResponse>> GetWalletsAsync(Guid userId)
    {
        var wallets = await _context.Wallets
            .Where(w => w.OwnerId == userId && !w.IsDeleted)
            .OrderByDescending(w => w.CreatedAt)
            .Select(w => new WalletResponse
            {
                Id = w.Id,
                Name = w.Name,
                Type = w.Type,
                InitialBalance = w.InitialBalance,
                Balance = w.Balance ?? 0,
                Currency = w.Currency.ToString(),
                CreatedAt = w.CreatedAt,
                LastUpdatedAt = w.LastUpdatedAt,
                IsDeleted = w.IsDeleted
            })
            .ToListAsync();

        return wallets;
    }

    public async Task<WalletResponse?> GetWalletByIdAsync(Guid walletId, Guid userId)
    {
        var wallet = await _context.Wallets
            .Where(w => w.Id == walletId && w.OwnerId == userId && !w.IsDeleted)
            .FirstOrDefaultAsync();

        if (wallet == null) return null;

        return new WalletResponse
        {
            Id = wallet.Id,
            Name = wallet.Name,
            Type = wallet.Type,
            InitialBalance = wallet.InitialBalance,
            Balance = wallet.Balance ?? 0,
            Currency = wallet.Currency.ToString(),
            CreatedAt = wallet.CreatedAt,
            LastUpdatedAt = wallet.LastUpdatedAt,
            IsDeleted = wallet.IsDeleted
        };
    }

    public async Task<WalletResponse> CreateWalletAsync(CreateWalletRequest request, Guid userId, bool isPremium)
    {
        // NOTE: Premium check disabled - all users can create unlimited wallets
        // Original check was: max 2 wallets for free users

        // Parse Currency enum
        if (!Enum.TryParse<CurrencyCode>(request.Currency, out var currencyCode))
        {
            currencyCode = CurrencyCode.VND;
        }

        var wallet = new Wallet
        {
            Id = request.Id ?? Guid.NewGuid(),
            Name = request.Name,
            Type = request.Type,
            InitialBalance = request.InitialBalance,
            Balance = request.InitialBalance, // Khi tạo mới, Balance = InitialBalance
            Currency = currencyCode,
            OwnerId = userId,
            CreatedAt = DateTime.UtcNow,
            LastUpdatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        _context.Wallets.Add(wallet);
        await _context.SaveChangesAsync();

        return new WalletResponse
        {
            Id = wallet.Id,
            Name = wallet.Name,
            Type = wallet.Type,
            InitialBalance = wallet.InitialBalance,
            Balance = wallet.Balance ?? 0,
            Currency = wallet.Currency.ToString(),
            CreatedAt = wallet.CreatedAt,
            LastUpdatedAt = wallet.LastUpdatedAt,
            IsDeleted = wallet.IsDeleted
        };
    }

    public async Task<WalletResponse> UpdateWalletAsync(Guid walletId, UpdateWalletRequest request, Guid userId)
    {
        var wallet = await _context.Wallets
            .FirstOrDefaultAsync(w => w.Id == walletId && w.OwnerId == userId && !w.IsDeleted);

        if (wallet == null)
        {
            throw new KeyNotFoundException("Không tìm thấy ví hoặc bạn không có quyền chỉnh sửa.");
        }

        // Update fields
        if (!string.IsNullOrEmpty(request.Name))
            wallet.Name = request.Name;

        if (!string.IsNullOrEmpty(request.Type))
            wallet.Type = request.Type;

        if (!string.IsNullOrEmpty(request.Currency) && Enum.TryParse<CurrencyCode>(request.Currency, out var currencyCode))
            wallet.Currency = currencyCode;

        if (request.AdjustedBalance.HasValue)
            wallet.Balance = request.AdjustedBalance.Value;

        wallet.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return new WalletResponse
        {
            Id = wallet.Id,
            Name = wallet.Name,
            Type = wallet.Type,
            InitialBalance = wallet.InitialBalance,
            Balance = wallet.Balance ?? 0,
            Currency = wallet.Currency.ToString(),
            CreatedAt = wallet.CreatedAt,
            LastUpdatedAt = wallet.LastUpdatedAt,
            IsDeleted = wallet.IsDeleted
        };
    }

    public async Task<bool> DeleteWalletAsync(Guid walletId, Guid userId)
    {
        var wallet = await _context.Wallets
            .FirstOrDefaultAsync(w => w.Id == walletId && w.OwnerId == userId && !w.IsDeleted);

        if (wallet == null)
        {
            return false;
        }

        // Soft delete
        wallet.IsDeleted = true;
        wallet.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<TotalBalanceResponse> GetTotalBalanceAsync(Guid userId)
    {
        var wallets = await _context.Wallets
            .Where(w => w.OwnerId == userId && !w.IsDeleted)
            .ToListAsync();

        var balancesByCurrency = wallets
            .GroupBy(w => w.Currency.ToString())
            .Select(g => new CurrencyBalance
            {
                Currency = g.Key,
                TotalBalance = g.Sum(w => w.Balance ?? 0)
            })
            .ToList();

        return new TotalBalanceResponse
        {
            Balances = balancesByCurrency,
            WalletCount = wallets.Count
        };
    }

    public async Task<int> CountActiveWalletsAsync(Guid userId)
    {
        return await _context.Wallets
            .CountAsync(w => w.OwnerId == userId && !w.IsDeleted);
    }
}
