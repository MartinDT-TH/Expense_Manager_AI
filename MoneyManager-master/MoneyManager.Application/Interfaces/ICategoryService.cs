using MoneyManager.Application.DTOs.Category;

namespace MoneyManager.Application.Interfaces;

public interface ICategoryService
{
    /// <summary>
    /// Lấy tất cả danh mục (System + Custom của user)
    /// </summary>
    Task<List<CategoryResponse>> GetAllCategoriesAsync(Guid userId);
    
    /// <summary>
    /// Lấy danh mục theo loại (Expense/Income)
    /// </summary>
    Task<List<CategoryResponse>> GetCategoriesByTypeAsync(Guid userId, string type);
    
    /// <summary>
    /// Lấy danh mục đã group theo loại
    /// </summary>
    Task<CategoriesGroupedResponse> GetCategoriesGroupedAsync(Guid userId);
    
    /// <summary>
    /// Lấy chi tiết 1 danh mục
    /// </summary>
    Task<CategoryResponse?> GetCategoryByIdAsync(Guid categoryId, Guid userId);
    
    /// <summary>
    /// Tạo danh mục riêng của user
    /// </summary>
    Task<CategoryResponse> CreateCategoryAsync(CreateCategoryRequest request, Guid userId);
    
    /// <summary>
    /// Cập nhật danh mục (chỉ danh mục của user)
    /// </summary>
    Task<CategoryResponse> UpdateCategoryAsync(Guid categoryId, UpdateCategoryRequest request, Guid userId);
    
    /// <summary>
    /// Xóa mềm danh mục (chỉ danh mục của user)
    /// </summary>
    Task<bool> DeleteCategoryAsync(Guid categoryId, Guid userId);

    /// <summary>
    /// Lấy tất cả danh mục hệ thống (public, không cần login)
    /// </summary>
    Task<List<CategoryResponse>> GetSystemCategoriesAsync();
    
    /// <summary>
    /// Lấy danh mục hệ thống theo loại (public, không cần login)
    /// </summary>
    Task<List<CategoryResponse>> GetSystemCategoriesByTypeAsync(string type);
}
