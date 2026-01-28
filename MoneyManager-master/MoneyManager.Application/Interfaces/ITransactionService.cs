using MoneyManager.Application.DTOs.Transaction;

namespace MoneyManager.Application.Interfaces;

public interface ITransactionService
{
    /// <summary>
    /// Lấy danh sách giao dịch có filter và phân trang
    /// </summary>
    Task<TransactionListResponse> GetTransactionsAsync(Guid userId, TransactionFilterRequest filter);
    
    /// <summary>
    /// Lấy chi tiết 1 giao dịch
    /// </summary>
    Task<TransactionResponse?> GetTransactionByIdAsync(Guid transactionId, Guid userId);
    
    /// <summary>
    /// Tạo giao dịch mới
    /// </summary>
    Task<TransactionResponse> CreateTransactionAsync(CreateTransactionRequest request, Guid userId);
    
    /// <summary>
    /// Cập nhật giao dịch
    /// </summary>
    Task<TransactionResponse> UpdateTransactionAsync(Guid transactionId, UpdateTransactionRequest request, Guid userId);
    
    /// <summary>
    /// Xóa mềm giao dịch
    /// </summary>
    Task<bool> DeleteTransactionAsync(Guid transactionId, Guid userId);
    
    /// <summary>
    /// Xử lý OCR hóa đơn (Premium feature)
    /// </summary>
    Task<OcrResultResponse> ProcessOcrAsync(string imageUrl, Guid userId);
    
    /// <summary>
    /// Lấy giao dịch theo nhóm
    /// </summary>
    Task<TransactionListResponse> GetGroupTransactionsAsync(Guid groupId, Guid userId, TransactionFilterRequest filter);
    
    /// <summary>
    /// Lấy giao dịch gần đây (cho Dashboard)
    /// </summary>
    Task<List<TransactionResponse>> GetRecentTransactionsAsync(Guid userId, int count = 5);
}
