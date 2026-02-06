using MoneyManager.Application.DTOs.Budget;

namespace MoneyManager.Application.Interfaces;

public interface IBudgetService
{
    /// <summary>
    /// Lấy danh sách ngân sách của user
    /// </summary>
    Task<List<BudgetResponse>> GetBudgetsAsync(Guid userId);
    
    /// <summary>
    /// Lấy chi tiết 1 ngân sách (kèm tình trạng chi tiêu)
    /// </summary>
    Task<BudgetResponse?> GetBudgetByIdAsync(Guid budgetId, Guid userId);
    
    /// <summary>
    /// Tạo ngân sách mới
    /// </summary>
    Task<BudgetResponse> CreateBudgetAsync(CreateBudgetRequest request, Guid userId);
    
    /// <summary>
    /// Cập nhật ngân sách
    /// </summary>
    Task<BudgetResponse> UpdateBudgetAsync(Guid budgetId, UpdateBudgetRequest request, Guid userId);
    
    /// <summary>
    /// Xóa mềm ngân sách
    /// </summary>
    Task<bool> DeleteBudgetAsync(Guid budgetId, Guid userId);
    
    /// <summary>
    /// Lấy cảnh báo ngân sách (> 80% hoặc vượt quá)
    /// </summary>
    Task<BudgetWarningResponse> GetBudgetWarningsAsync(Guid userId);
    
    /// <summary>
    /// Lấy ngân sách đang hoạt động (trong khoảng thời gian hiện tại)
    /// </summary>
    Task<List<BudgetResponse>> GetActiveBudgetsAsync(Guid userId);
    
    /// <summary>
    /// Lấy ngân sách áp dụng cho tháng hiện tại
    /// Ưu tiên: Budget cụ thể cho tháng > Budget recurring (mặc định)
    /// </summary>
    Task<BudgetResponse?> GetCurrentMonthBudgetAsync(Guid userId);
    
    /// <summary>
    /// Lấy lịch sử ngân sách theo tháng
    /// </summary>
    Task<BudgetHistoryResponse> GetBudgetHistoryAsync(Guid userId, int months = 6);
    
    /// <summary>
    /// Lấy phân tích ngân sách
    /// </summary>
    Task<BudgetAnalyticsResponse> GetBudgetAnalyticsAsync(Guid userId);
    
    /// <summary>
    /// Lấy đề xuất ngân sách thông minh dựa trên chi tiêu
    /// </summary>
    Task<List<BudgetSuggestion>> GetBudgetSuggestionsAsync(Guid userId);
}
