namespace MoneyManager.Application.DTOs.Category;

// ===== REQUEST DTOs =====

/// <summary>
/// Request tạo danh mục mới
/// </summary>
public class CreateCategoryRequest
{
    /// <summary>
    /// ID do Client gen (GUID) - Hỗ trợ offline-first
    /// </summary>
    public Guid? Id { get; set; }
    
    /// <summary>
    /// Tên danh mục (VD: "Ăn uống", "Lương", "Tiền nhà")
    /// </summary>
    public string Name { get; set; } = string.Empty;
    
    /// <summary>
    /// Mã icon (VD: "food", "salary", "house")
    /// </summary>
    public string? IconCode { get; set; }
    
    /// <summary>
    /// Loại: EXPENSE (Chi) hoặc INCOME (Thu)
    /// </summary>
    public string Type { get; set; } = "EXPENSE";
    
    /// <summary>
    /// ID danh mục cha (nếu là danh mục con)
    /// </summary>
    public Guid? ParentId { get; set; }
}

/// <summary>
/// Request cập nhật danh mục
/// </summary>
public class UpdateCategoryRequest
{
    public string? Name { get; set; }
    public string? IconCode { get; set; }
    public Guid? ParentId { get; set; }
}

// ===== RESPONSE DTOs =====

/// <summary>
/// Response trả về thông tin danh mục
/// </summary>
public class CategoryResponse
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? IconCode { get; set; }
    public string Type { get; set; } = string.Empty; // EXPENSE, INCOME
    public Guid? ParentId { get; set; }
    public string? ParentName { get; set; }
    
    /// <summary>
    /// True = Danh mục hệ thống (không thể xóa/sửa)
    /// False = Danh mục do user tạo
    /// </summary>
    public bool IsSystemCategory { get; set; }
    
    public DateTime CreatedAt { get; set; }
    public DateTime LastUpdatedAt { get; set; }
    
    /// <summary>
    /// Danh mục con (nếu có)
    /// </summary>
    public List<CategoryResponse>? Children { get; set; }
}

/// <summary>
/// Response danh sách danh mục theo loại
/// </summary>
public class CategoriesGroupedResponse
{
    public List<CategoryResponse> ExpenseCategories { get; set; } = new();
    public List<CategoryResponse> IncomeCategories { get; set; } = new();
}
