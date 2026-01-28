using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using MoneyManager.Application.DTOs.Transaction;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;

namespace MoneyManager.Infrastructure.Services;

public class TransactionService : ITransactionService
{
    private readonly MoneyManagerDbContext _context;
    private readonly IOcrService _ocrService;
    private readonly ILogger<TransactionService> _logger;
    private readonly IGroupHubNotifier? _groupHubNotifier;

    public TransactionService(
        MoneyManagerDbContext context, 
        IOcrService ocrService,
        ILogger<TransactionService> logger,
        IGroupHubNotifier? groupHubNotifier = null)
    {
        _context = context;
        _ocrService = ocrService;
        _logger = logger;
        _groupHubNotifier = groupHubNotifier;
    }

    public async Task<TransactionListResponse> GetTransactionsAsync(Guid userId, TransactionFilterRequest filter)
    {
        IQueryable<Transaction> query;
        
        // If filtering by GroupId, get ALL transactions in the group (from all members)
        if (filter.GroupId.HasValue)
        {
            // First, check if user is member of this group
            var isMember = await _context.GroupMembers
                .AnyAsync(gm => gm.GroupId == filter.GroupId.Value 
                               && gm.UserId == userId 
                               && !gm.IsDeleted);
            
            if (!isMember)
            {
                // User is not a member, return empty result
                return new TransactionListResponse
                {
                    Items = new List<TransactionResponse>(),
                    TotalCount = 0,
                    Page = filter.Page,
                    PageSize = filter.PageSize,
                    TotalPages = 0,
                    TotalIncome = 0,
                    TotalExpense = 0
                };
            }
            
            // Get all transactions in this group (from all members)
            query = _context.Transactions
                .Include(t => t.Category)
                .Include(t => t.Wallet)
                .Include(t => t.Group)
                .Where(t => t.GroupId == filter.GroupId.Value && !t.IsDeleted);
        }
        else
        {
            // Normal case: get user's own transactions
            query = _context.Transactions
                .Include(t => t.Category)
                .Include(t => t.Wallet)
                .Include(t => t.Group)
                .Where(t => t.Wallet!.OwnerId == userId && !t.IsDeleted);
        }

        // Apply filters
        if (filter.StartDate.HasValue)
        {
            query = query.Where(t => t.TransactionDate >= filter.StartDate.Value);
        }

        if (filter.EndDate.HasValue)
        {
            query = query.Where(t => t.TransactionDate <= filter.EndDate.Value);
        }

        if (filter.WalletId.HasValue)
        {
            query = query.Where(t => t.WalletId == filter.WalletId.Value);
        }

        if (filter.CategoryId.HasValue)
        {
            query = query.Where(t => t.CategoryId == filter.CategoryId.Value);
        }

        if (!string.IsNullOrEmpty(filter.Type) && Enum.TryParse<CategoryType>(filter.Type, true, out var categoryType))
        {
            query = query.Where(t => t.Category!.Type == categoryType);
        }

        // NOTE: GroupId filter already applied above

        // Tính tổng thu/chi
        var incomeQuery = query.Where(t => t.Category!.Type == CategoryType.Income);
        var expenseQuery = query.Where(t => t.Category!.Type == CategoryType.Expense);

        var totalIncome = await incomeQuery.SumAsync(t => t.Amount);
        var totalExpense = await expenseQuery.SumAsync(t => t.Amount);

        // Đếm tổng
        var totalCount = await query.CountAsync();

        // Phân trang
        var items = await query
            .OrderByDescending(t => t.TransactionDate)
            .ThenByDescending(t => t.CreatedAt)
            .Skip((filter.Page - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .Select(t => MapToResponse(t))
            .ToListAsync();

        return new TransactionListResponse
        {
            Items = items,
            TotalCount = totalCount,
            Page = filter.Page,
            PageSize = filter.PageSize,
            TotalPages = (int)Math.Ceiling((double)totalCount / filter.PageSize),
            TotalIncome = totalIncome,
            TotalExpense = totalExpense
        };
    }

    public async Task<TransactionResponse?> GetTransactionByIdAsync(Guid transactionId, Guid userId)
    {
        var transaction = await _context.Transactions
            .Include(t => t.Category)
            .Include(t => t.Wallet)
            .Include(t => t.Group)
            .FirstOrDefaultAsync(t => t.Id == transactionId 
                                      && t.Wallet!.OwnerId == userId 
                                      && !t.IsDeleted);

        return transaction == null ? null : MapToResponse(transaction);
    }

    public async Task<TransactionResponse> CreateTransactionAsync(CreateTransactionRequest request, Guid userId)
    {
        // Validate Wallet
        var wallet = await _context.Wallets
            .FirstOrDefaultAsync(w => w.Id == request.WalletId && w.OwnerId == userId && !w.IsDeleted);

        if (wallet == null)
        {
            throw new KeyNotFoundException("Không tìm thấy ví hoặc bạn không có quyền sử dụng ví này.");
        }

        // Validate Category
        var category = await _context.Categories
            .FirstOrDefaultAsync(c => c.Id == request.CategoryId && !c.IsDeleted);

        if (category == null)
        {
            throw new KeyNotFoundException("Không tìm thấy danh mục.");
        }

        // Validate Group (nếu có)
        if (request.GroupId.HasValue)
        {
            var isMember = await _context.GroupMembers
                .AnyAsync(gm => gm.GroupId == request.GroupId.Value 
                               && gm.UserId == userId 
                               && !gm.IsDeleted);

            if (!isMember)
            {
                throw new UnauthorizedAccessException("Bạn không phải thành viên của nhóm này.");
            }
        }

        var transaction = new Transaction
        {
            Id = request.Id ?? Guid.NewGuid(),
            Amount = request.Amount,
            CategoryId = request.CategoryId,
            WalletId = request.WalletId,
            Note = request.Note,
            TransactionDate = request.TransactionDate,
            GroupId = request.GroupId,
            BillImageUrl = request.BillImageUrl,
            OcrRawData = request.OcrRawData,
            CreatedAt = DateTime.UtcNow,
            LastUpdatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        // Cập nhật số dư ví
        if (category.Type == CategoryType.Income)
        {
            wallet.Balance = (wallet.Balance ?? 0) + request.Amount;
        }
        else // Expense
        {
            wallet.Balance = (wallet.Balance ?? 0) - request.Amount;
        }
        wallet.LastUpdatedAt = DateTime.UtcNow;

        _context.Transactions.Add(transaction);
        await _context.SaveChangesAsync();
        
        // Notify group members if this is a group transaction
        if (transaction.GroupId.HasValue && _groupHubNotifier != null)
        {
            await _groupHubNotifier.NotifyNewTransactionAsync(
                transaction.GroupId.Value.ToString(),
                transaction.Id.ToString(),
                transaction.Amount,
                transaction.Note ?? "Giao dịch mới"
            );
        }

        // Load relationships để trả về response đầy đủ
        await _context.Entry(transaction).Reference(t => t.Category).LoadAsync();
        await _context.Entry(transaction).Reference(t => t.Wallet).LoadAsync();
        if (transaction.GroupId.HasValue)
        {
            await _context.Entry(transaction).Reference(t => t.Group).LoadAsync();
        }

        return MapToResponse(transaction);
    }

    public async Task<TransactionResponse> UpdateTransactionAsync(Guid transactionId, UpdateTransactionRequest request, Guid userId)
    {
        var transaction = await _context.Transactions
            .Include(t => t.Category)
            .Include(t => t.Wallet)
            .FirstOrDefaultAsync(t => t.Id == transactionId && !t.IsDeleted);

        if (transaction == null)
        {
            throw new KeyNotFoundException("Không tìm thấy giao dịch.");
        }

        // Check quyền
        if (transaction.Wallet!.OwnerId != userId)
        {
            throw new UnauthorizedAccessException("Bạn không có quyền sửa giao dịch này.");
        }

        var oldAmount = transaction.Amount;
        var oldCategoryType = transaction.Category!.Type;
        var oldWallet = transaction.Wallet;

        // Hoàn lại số dư cũ
        if (oldCategoryType == CategoryType.Income)
        {
            oldWallet.Balance = (oldWallet.Balance ?? 0) - oldAmount;
        }
        else
        {
            oldWallet.Balance = (oldWallet.Balance ?? 0) + oldAmount;
        }

        // Update fields
        if (request.Amount.HasValue)
            transaction.Amount = request.Amount.Value;

        if (request.CategoryId.HasValue)
        {
            var newCategory = await _context.Categories
                .FirstOrDefaultAsync(c => c.Id == request.CategoryId.Value && !c.IsDeleted);
            if (newCategory == null)
                throw new KeyNotFoundException("Không tìm thấy danh mục.");
            transaction.CategoryId = request.CategoryId.Value;
            transaction.Category = newCategory;
        }

        if (request.WalletId.HasValue)
        {
            var newWallet = await _context.Wallets
                .FirstOrDefaultAsync(w => w.Id == request.WalletId.Value && w.OwnerId == userId && !w.IsDeleted);
            if (newWallet == null)
                throw new KeyNotFoundException("Không tìm thấy ví.");
            transaction.WalletId = request.WalletId.Value;
            transaction.Wallet = newWallet;
        }

        if (request.Note != null)
            transaction.Note = request.Note;

        if (request.TransactionDate.HasValue)
            transaction.TransactionDate = request.TransactionDate.Value;

        if (request.GroupId.HasValue)
            transaction.GroupId = request.GroupId.Value;

        if (request.BillImageUrl != null)
            transaction.BillImageUrl = request.BillImageUrl;

        // Áp dụng số dư mới
        var newCategoryType = transaction.Category.Type;
        if (newCategoryType == CategoryType.Income)
        {
            transaction.Wallet.Balance = (transaction.Wallet.Balance ?? 0) + transaction.Amount;
        }
        else
        {
            transaction.Wallet.Balance = (transaction.Wallet.Balance ?? 0) - transaction.Amount;
        }

        transaction.LastUpdatedAt = DateTime.UtcNow;
        transaction.Wallet.LastUpdatedAt = DateTime.UtcNow;
        if (oldWallet.Id != transaction.Wallet.Id)
        {
            oldWallet.LastUpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();

        return MapToResponse(transaction);
    }

    public async Task<bool> DeleteTransactionAsync(Guid transactionId, Guid userId)
    {
        var transaction = await _context.Transactions
            .Include(t => t.Category)
            .Include(t => t.Wallet)
            .FirstOrDefaultAsync(t => t.Id == transactionId && !t.IsDeleted);

        if (transaction == null)
        {
            return false;
        }

        // Check quyền
        if (transaction.Wallet!.OwnerId != userId)
        {
            throw new UnauthorizedAccessException("Bạn không có quyền xóa giao dịch này.");
        }

        // Hoàn lại số dư
        if (transaction.Category!.Type == CategoryType.Income)
        {
            transaction.Wallet.Balance = (transaction.Wallet.Balance ?? 0) - transaction.Amount;
        }
        else
        {
            transaction.Wallet.Balance = (transaction.Wallet.Balance ?? 0) + transaction.Amount;
        }

        // Soft delete
        transaction.IsDeleted = true;
        transaction.LastUpdatedAt = DateTime.UtcNow;
        transaction.Wallet.LastUpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<OcrResultResponse> ProcessOcrAsync(string imageUrl, Guid userId)
    {
        try
        {
            _logger.LogInformation("Processing OCR for user {UserId}, image: {ImageUrl}", userId, imageUrl);
            
            // Call OCR service to extract data
            var ocrResult = await _ocrService.ExtractReceiptDataAsync(imageUrl);
            
            if (!ocrResult.Success)
            {
                return ocrResult;
            }
            
            // Get user's expense categories for suggestion
            var expenseCategories = await _context.Categories
                .Where(c => !c.IsDeleted && 
                           c.Type == CategoryType.Expense &&
                           (c.OwnerId == null || c.OwnerId == userId))
                .Select(c => new CategorySuggestion
                {
                    Id = c.Id,
                    Name = c.Name,
                    Type = "EXPENSE",
                    Keywords = new List<string> { c.Name.ToLower() }
                })
                .ToListAsync();
            
            // Try to suggest category based on merchant name and description
            var (suggestedCategoryId, suggestedCategoryName) = await _ocrService.SuggestCategoryAsync(
                ocrResult.MerchantName,
                ocrResult.Description,
                expenseCategories
            );
            
            ocrResult.SuggestedCategoryId = suggestedCategoryId;
            ocrResult.SuggestedCategoryName = suggestedCategoryName;
            
            _logger.LogInformation("OCR completed - Amount: {Amount}, Suggested Category: {Category}", 
                ocrResult.Amount, suggestedCategoryName);
            
            return ocrResult;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing OCR for user {UserId}", userId);
            return new OcrResultResponse
            {
                Success = false,
                ErrorMessage = $"OCR processing failed: {ex.Message}"
            };
        }
    }

    public async Task<TransactionListResponse> GetGroupTransactionsAsync(Guid groupId, Guid userId, TransactionFilterRequest filter)
    {
        // Check user là thành viên nhóm
        var isMember = await _context.GroupMembers
            .AnyAsync(gm => gm.GroupId == groupId && gm.UserId == userId && !gm.IsDeleted);

        if (!isMember)
        {
            throw new UnauthorizedAccessException("Bạn không phải thành viên của nhóm này.");
        }

        filter.GroupId = groupId;

        var query = _context.Transactions
            .Include(t => t.Category)
            .Include(t => t.Wallet)
            .ThenInclude(w => w!.Owner)
            .Include(t => t.Group)
            .Where(t => t.GroupId == groupId && !t.IsDeleted);

        // Apply other filters
        if (filter.StartDate.HasValue)
            query = query.Where(t => t.TransactionDate >= filter.StartDate.Value);

        if (filter.EndDate.HasValue)
            query = query.Where(t => t.TransactionDate <= filter.EndDate.Value);

        if (filter.CategoryId.HasValue)
            query = query.Where(t => t.CategoryId == filter.CategoryId.Value);

        var totalCount = await query.CountAsync();
        var totalIncome = await query.Where(t => t.Category!.Type == CategoryType.Income).SumAsync(t => t.Amount);
        var totalExpense = await query.Where(t => t.Category!.Type == CategoryType.Expense).SumAsync(t => t.Amount);

        var items = await query
            .OrderByDescending(t => t.TransactionDate)
            .Skip((filter.Page - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .Select(t => new TransactionResponse
            {
                Id = t.Id,
                Amount = t.Amount,
                CategoryId = t.CategoryId,
                CategoryName = t.Category!.Name,
                CategoryIcon = t.Category.IconCode,
                CategoryType = t.Category.Type.ToString(),
                WalletId = t.WalletId,
                WalletName = t.Wallet!.Name,
                Note = t.Note,
                TransactionDate = t.TransactionDate,
                GroupId = t.GroupId,
                GroupName = t.Group!.Name,
                BillImageUrl = t.BillImageUrl,
                CreatedByUserId = t.Wallet.OwnerId,
                CreatedByUserName = t.Wallet.Owner.FullName,
                CreatedAt = t.CreatedAt,
                LastUpdatedAt = t.LastUpdatedAt,
                IsDeleted = t.IsDeleted
            })
            .ToListAsync();

        return new TransactionListResponse
        {
            Items = items,
            TotalCount = totalCount,
            Page = filter.Page,
            PageSize = filter.PageSize,
            TotalPages = (int)Math.Ceiling((double)totalCount / filter.PageSize),
            TotalIncome = totalIncome,
            TotalExpense = totalExpense
        };
    }

    public async Task<List<TransactionResponse>> GetRecentTransactionsAsync(Guid userId, int count = 5)
    {
        var transactions = await _context.Transactions
            .Include(t => t.Category)
            .Include(t => t.Wallet)
            .Include(t => t.Group)
            .Where(t => t.Wallet!.OwnerId == userId && !t.IsDeleted)
            .OrderByDescending(t => t.TransactionDate)
            .ThenByDescending(t => t.CreatedAt)
            .Take(count)
            .ToListAsync();

        return transactions.Select(t => MapToResponse(t)).ToList();
    }

    // ===== HELPER =====
    private static TransactionResponse MapToResponse(Transaction t)
    {
        return new TransactionResponse
        {
            Id = t.Id,
            Amount = t.Amount,
            CategoryId = t.CategoryId,
            CategoryName = t.Category?.Name ?? "",
            CategoryIcon = t.Category?.IconCode,
            CategoryType = t.Category?.Type.ToString() ?? "",
            WalletId = t.WalletId,
            WalletName = t.Wallet?.IsDeleted == true ? "Deleted" : (t.Wallet?.Name ?? ""),
            Note = t.Note,
            TransactionDate = t.TransactionDate,
            GroupId = t.GroupId,
            GroupName = t.Group?.Name,
            BillImageUrl = t.BillImageUrl,
            CreatedByUserId = t.Wallet?.OwnerId ?? Guid.Empty,
            CreatedByUserName = t.Wallet?.Owner?.FullName,
            CreatedAt = t.CreatedAt,
            LastUpdatedAt = t.LastUpdatedAt,
            IsDeleted = t.IsDeleted
        };
    }
}
