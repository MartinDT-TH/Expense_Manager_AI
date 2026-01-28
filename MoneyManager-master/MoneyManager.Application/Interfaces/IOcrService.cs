using MoneyManager.Application.DTOs.Transaction;

namespace MoneyManager.Application.Interfaces;

/// <summary>
/// Interface for OCR (Optical Character Recognition) services
/// </summary>
public interface IOcrService
{
    /// <summary>
    /// Extract text and data from receipt/bill image by URL
    /// </summary>
    /// <param name="imageUrl">URL of the image to process</param>
    /// <returns>Extracted data including amount, date, merchant name, etc.</returns>
    Task<OcrResultResponse> ExtractReceiptDataAsync(string imageUrl);
    
    /// <summary>
    /// Extract text and data from receipt/bill image by Base64
    /// </summary>
    /// <param name="base64Image">Base64 encoded image data</param>
    /// <param name="mimeType">MIME type of the image (e.g., image/png, image/jpeg)</param>
    /// <returns>Extracted data including amount, date, merchant name, etc.</returns>
    Task<OcrResultResponse> ExtractReceiptDataFromBase64Async(string base64Image, string mimeType);
    
    /// <summary>
    /// Suggest category based on merchant name or description
    /// </summary>
    /// <param name="merchantName">Name of the merchant</param>
    /// <param name="description">Description or items from receipt</param>
    /// <param name="categories">List of available categories</param>
    /// <returns>Best matching category ID</returns>
    Task<(Guid? CategoryId, string? CategoryName)> SuggestCategoryAsync(
        string? merchantName, 
        string? description, 
        IEnumerable<CategorySuggestion> categories);
}

/// <summary>
/// Category info for suggestion matching
/// </summary>
public class CategorySuggestion
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty; // EXPENSE, INCOME
    public List<string> Keywords { get; set; } = new(); // Keywords to match
}
