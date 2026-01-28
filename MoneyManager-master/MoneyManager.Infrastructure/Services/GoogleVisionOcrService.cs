using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Globalization;
using Microsoft.Extensions.Logging;
using MoneyManager.Application.DTOs.Transaction;
using MoneyManager.Application.Interfaces;

namespace MoneyManager.Infrastructure.Services;

/// <summary>
/// Google Cloud Vision OCR Service Implementation
/// </summary>
public class GoogleVisionOcrService : IOcrService
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<GoogleVisionOcrService> _logger;
    
    // Google Vision API endpoint
    private const string VisionApiUrl = "https://vision.googleapis.com/v1/images:annotate";
    
    // Category keywords mapping (Vietnamese context)
    private static readonly Dictionary<string, List<string>> CategoryKeywords = new()
    {
        // Food & Drinks
        { "food", new List<string> { 
            "restaurant", "nhà hàng", "quán ăn", "ăn uống", "cafe", "cà phê", "coffee",
            "bánh", "bread", "phở", "bún", "cơm", "rice", "pizza", "burger", "kfc",
            "lotteria", "jollibee", "highland", "starbucks", "circle k", "7-eleven",
            "ministop", "familymart", "gs25", "vinmart", "grab food", "shopee food",
            "now", "baemin", "gofood", "đồ ăn", "thức ăn", "ẩm thực", "beer", "bia"
        }},
        // Transport
        { "transport", new List<string> {
            "grab", "be", "xăng", "gas", "petrol", "taxi", "uber", "gojek", "xe ôm",
            "parking", "đỗ xe", "gửi xe", "toll", "phí cầu đường", "vé xe", "bus",
            "metro", "tàu", "train", "máy bay", "flight", "vietjet", "vietnam airlines",
            "bamboo", "airport", "sân bay"
        }},
        // Shopping
        { "shopping", new List<string> {
            "shop", "store", "cửa hàng", "siêu thị", "supermarket", "big c", "coopmart",
            "lotte mart", "aeon", "mega market", "emart", "winmart", "bách hóa",
            "tiki", "shopee", "lazada", "sendo", "thế giới di động", "điện máy xanh",
            "fpt shop", "cellphones", "fashion", "thời trang", "quần áo", "giày dép"
        }},
        // Entertainment
        { "entertainment", new List<string> {
            "cinema", "rạp", "cgv", "lotte cinema", "galaxy", "bhd", "game", "karaoke",
            "bar", "pub", "club", "netflix", "spotify", "youtube", "giải trí", "vui chơi",
            "du lịch", "travel", "hotel", "khách sạn", "resort"
        }},
        // Health
        { "health", new List<string> {
            "pharmacy", "nhà thuốc", "thuốc", "medicine", "bệnh viện", "hospital",
            "phòng khám", "clinic", "doctor", "bác sĩ", "y tế", "health", "gym",
            "fitness", "long châu", "pharmacity", "an khang"
        }},
        // Bills & Utilities
        { "bills", new List<string> {
            "điện", "electric", "evn", "nước", "water", "internet", "wifi", "fpt",
            "viettel", "vnpt", "mobifone", "vinaphone", "truyền hình", "tv", "gas",
            "phí dịch vụ", "quản lý", "chung cư"
        }},
        // Education
        { "education", new List<string> {
            "school", "trường", "học phí", "tuition", "sách", "book", "course",
            "khóa học", "học viện", "university", "đại học", "tiếng anh", "english",
            "ielts", "toeic"
        }}
    };

    public GoogleVisionOcrService(HttpClient httpClient, string apiKey, ILogger<GoogleVisionOcrService> logger)
    {
        _httpClient = httpClient;
        _apiKey = apiKey;
        _logger = logger;
    }

    public async Task<OcrResultResponse> ExtractReceiptDataAsync(string imageUrl)
    {
        try
        {
            _logger.LogInformation("Starting OCR processing for image: {ImageUrl}", imageUrl);
            
            // Call Google Vision API
            var visionRequest = new GoogleVisionRequest
            {
                Requests = new List<AnnotateImageRequest>
                {
                    new()
                    {
                        Image = new ImageSource { Source = new ImageSourceInfo { ImageUri = imageUrl } },
                        Features = new List<Feature>
                        {
                            new() { Type = "TEXT_DETECTION", MaxResults = 50 },
                            new() { Type = "DOCUMENT_TEXT_DETECTION", MaxResults = 1 }
                        }
                    }
                }
            };

            var jsonOptions = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            };

            var requestJson = JsonSerializer.Serialize(visionRequest, jsonOptions);
            var content = new StringContent(requestJson, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{VisionApiUrl}?key={_apiKey}", content);
            var responseContent = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Google Vision API error: {StatusCode} - {Response}", response.StatusCode, responseContent);
                return new OcrResultResponse
                {
                    Success = false,
                    ErrorMessage = $"OCR API error: {response.StatusCode}"
                };
            }

            var visionResponse = JsonSerializer.Deserialize<GoogleVisionResponse>(responseContent, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (visionResponse?.Responses == null || !visionResponse.Responses.Any())
            {
                return new OcrResultResponse
                {
                    Success = false,
                    ErrorMessage = "No text detected in image"
                };
            }

            var textAnnotations = visionResponse.Responses.FirstOrDefault()?.TextAnnotations;
            var fullTextAnnotation = visionResponse.Responses.FirstOrDefault()?.FullTextAnnotation;

            var fullText = textAnnotations?.FirstOrDefault()?.Description ?? 
                          fullTextAnnotation?.Text ?? string.Empty;

            _logger.LogInformation("OCR extracted text length: {Length}", fullText.Length);

            // Parse extracted text
            var result = ParseReceiptText(fullText);
            result.RawData = JsonSerializer.Serialize(new { fullText, extractedAt = DateTime.UtcNow });

            _logger.LogInformation("OCR result - Amount: {Amount}, Date: {Date}, Merchant: {Merchant}", 
                result.Amount, result.Date, result.MerchantName);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing OCR for image: {ImageUrl}", imageUrl);
            return new OcrResultResponse
            {
                Success = false,
                ErrorMessage = $"OCR processing error: {ex.Message}"
            };
        }
    }

    /// <summary>
    /// Extract receipt data from base64 image - NOT IMPLEMENTED for Google Vision (use Gemini instead)
    /// </summary>
    public Task<OcrResultResponse> ExtractReceiptDataFromBase64Async(string base64Image, string mimeType)
    {
        // Google Vision API requires billing, recommend using Gemini instead
        return Task.FromResult(new OcrResultResponse
        {
            Success = false,
            ErrorMessage = "Google Vision API requires billing. Please use Gemini OCR service instead."
        });
    }

    /// <summary>
    /// Parse receipt text to extract structured data
    /// </summary>
    private OcrResultResponse ParseReceiptText(string text)
    {
        var result = new OcrResultResponse { Success = true };

        if (string.IsNullOrWhiteSpace(text))
        {
            result.Success = false;
            result.ErrorMessage = "Empty text from OCR";
            return result;
        }

        var lines = text.Split('\n', StringSplitOptions.RemoveEmptyEntries)
                       .Select(l => l.Trim())
                       .ToList();

        // Extract merchant name (usually first meaningful lines)
        result.MerchantName = ExtractMerchantName(lines);

        // Extract amount (look for total, tổng, thành tiền, etc.)
        result.Amount = ExtractAmount(text, lines);

        // Extract date
        result.Date = ExtractDate(text);

        // Extract description/items
        result.Description = ExtractDescription(lines, result.MerchantName);

        return result;
    }

    /// <summary>
    /// Extract merchant/store name from receipt
    /// </summary>
    private string? ExtractMerchantName(List<string> lines)
    {
        // First few non-empty lines usually contain store name
        // Skip lines that look like addresses or phone numbers
        foreach (var line in lines.Take(5))
        {
            var cleanLine = line.Trim();
            
            // Skip if too short
            if (cleanLine.Length < 3) continue;
            
            // Skip if looks like phone number
            if (Regex.IsMatch(cleanLine, @"^[\d\s\-\.\(\)]+$")) continue;
            
            // Skip if looks like address (số, đường, phố, quận, TP)
            if (Regex.IsMatch(cleanLine, @"(số|đường|phố|quận|tp\.|p\.|hcm|hn|hà nội|hồ chí minh)", RegexOptions.IgnoreCase))
                continue;
            
            // Skip if looks like date
            if (Regex.IsMatch(cleanLine, @"\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}")) continue;
            
            // This might be the store name
            // Clean up common suffixes
            var name = Regex.Replace(cleanLine, @"(co\.,? ?ltd|công ty|tnhh|cổ phần|chi nhánh).*", "", RegexOptions.IgnoreCase).Trim();
            
            if (name.Length >= 3)
                return name;
        }

        return null;
    }

    /// <summary>
    /// Extract total amount from receipt
    /// </summary>
    private decimal? ExtractAmount(string fullText, List<string> lines)
    {
        // Vietnamese amount patterns
        var patterns = new[]
        {
            // Total patterns (including "TIEN MAT", "tiền mặt")
            @"(?:tổng\s*(?:cộng|tiền)?|thành\s*tiền|total|tổng\s*thanh\s*toán|thanh\s*toán|amount|grand\s*total|ti[eề]n\s*m[aặ]t|cash)[:\s]*(\d[\d\.,\s]*)",
            // VND patterns
            @"(\d[\d\.,\s]+)\s*(?:vnd|đồng|vnđ|đ)",
            // Price with comma separator (Vietnamese style: 150.000 or 150,000)
            @"(\d{1,3}(?:[\.,]\d{3})+)(?!\d)",
            // Large numbers that look like prices (standalone on a line)
            @"(?:^|\s)(\d{4,}(?:[\.,]\d+)?)(?:\s|$|đ|vnd)"
        };

        decimal maxAmount = 0;
        
        foreach (var pattern in patterns)
        {
            var matches = Regex.Matches(fullText, pattern, RegexOptions.IgnoreCase | RegexOptions.Multiline);
            
            foreach (Match match in matches)
            {
                var amountStr = match.Groups[1].Value;
                var amount = ParseVietnameseAmount(amountStr);
                
                if (amount.HasValue && amount.Value > maxAmount && amount.Value < 1_000_000_000) // Sanity check
                {
                    maxAmount = amount.Value;
                }
            }
        }

        // Also check lines for structured "Total: xxx" format
        foreach (var line in lines)
        {
            if (Regex.IsMatch(line, @"(tổng|total|thành tiền|thanh toán|ti[eề]n\s*m[aặ]t|cash)", RegexOptions.IgnoreCase))
            {
                var amountMatch = Regex.Match(line, @"(\d[\d\.,\s]+)");
                if (amountMatch.Success)
                {
                    var amount = ParseVietnameseAmount(amountMatch.Groups[1].Value);
                    if (amount.HasValue && amount.Value > maxAmount && amount.Value < 1_000_000_000)
                    {
                        maxAmount = amount.Value;
                    }
                }
            }
        }

        return maxAmount > 0 ? maxAmount : null;
    }

    /// <summary>
    /// Parse Vietnamese-style amount (150.000 or 150,000 = 150000)
    /// </summary>
    private decimal? ParseVietnameseAmount(string amountStr)
    {
        if (string.IsNullOrWhiteSpace(amountStr)) return null;

        // Remove spaces
        amountStr = Regex.Replace(amountStr, @"\s+", "");
        
        // Vietnamese uses . or , as thousand separator
        // Check pattern: if has 3 digits after separator, it's thousand separator
        if (Regex.IsMatch(amountStr, @"^\d{1,3}([\.,]\d{3})+$"))
        {
            // Remove all separators
            amountStr = Regex.Replace(amountStr, @"[\.,]", "");
        }
        
        if (decimal.TryParse(amountStr, NumberStyles.Any, CultureInfo.InvariantCulture, out var result))
        {
            return result;
        }

        return null;
    }

    /// <summary>
    /// Extract date from receipt
    /// </summary>
    private DateTime? ExtractDate(string text)
    {
        // Vietnamese date patterns
        var patterns = new[]
        {
            // DD/MM/YYYY or DD-MM-YYYY
            @"(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})",
            // DD/MM/YY
            @"(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2})(?!\d)",
            // YYYY/MM/DD or YYYY-MM-DD
            @"(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})"
        };

        foreach (var pattern in patterns)
        {
            var match = Regex.Match(text, pattern);
            if (match.Success)
            {
                int day, month, year;

                if (pattern.StartsWith(@"(\d{4})"))
                {
                    // YYYY/MM/DD format
                    year = int.Parse(match.Groups[1].Value);
                    month = int.Parse(match.Groups[2].Value);
                    day = int.Parse(match.Groups[3].Value);
                }
                else
                {
                    // DD/MM/YYYY format
                    day = int.Parse(match.Groups[1].Value);
                    month = int.Parse(match.Groups[2].Value);
                    year = int.Parse(match.Groups[3].Value);
                    
                    // Handle 2-digit year
                    if (year < 100)
                    {
                        year += year > 50 ? 1900 : 2000;
                    }
                }

                // Validate date
                if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 1990 && year <= 2100)
                {
                    try
                    {
                        return new DateTime(year, month, day);
                    }
                    catch
                    {
                        // Invalid date, continue searching
                    }
                }
            }
        }

        // No date found, return null (let UI use today as default)
        return null;
    }

    /// <summary>
    /// Extract description from items
    /// </summary>
    private string? ExtractDescription(List<string> lines, string? merchantName)
    {
        // Look for item lines (usually have quantity and price)
        var itemLines = lines
            .Where(l => Regex.IsMatch(l, @"\d") && l.Length > 5)
            .Where(l => !Regex.IsMatch(l, @"(tổng|total|vat|tax|phone|tel|fax|địa chỉ|address)", RegexOptions.IgnoreCase))
            .Where(l => l != merchantName)
            .Take(5)
            .ToList();

        if (itemLines.Any())
        {
            return string.Join(", ", itemLines.Take(3).Select(CleanItemLine));
        }

        return merchantName != null ? $"Thanh toán tại {merchantName}" : null;
    }

    private string CleanItemLine(string line)
    {
        // Remove prices and quantities from item description
        var clean = Regex.Replace(line, @"\d[\d\.,\s]*(?:vnd|đ|vnđ)?$", "", RegexOptions.IgnoreCase);
        clean = Regex.Replace(clean, @"^\d+\s*[xX×]\s*", ""); // Remove "2 x" prefix
        return clean.Trim().TrimEnd(':', '-', '.');
    }

    public Task<(Guid? CategoryId, string? CategoryName)> SuggestCategoryAsync(
        string? merchantName, 
        string? description, 
        IEnumerable<CategorySuggestion> categories)
    {
        if (string.IsNullOrEmpty(merchantName) && string.IsNullOrEmpty(description))
        {
            return Task.FromResult<(Guid?, string?)>((null, null));
        }

        var searchText = $"{merchantName} {description}".ToLowerInvariant();
        
        // Find matching category based on keywords
        foreach (var (categoryKey, keywords) in CategoryKeywords)
        {
            if (keywords.Any(keyword => searchText.Contains(keyword.ToLowerInvariant())))
            {
                // Find matching category in user's categories
                var matchingCategory = categories.FirstOrDefault(c => 
                    c.Name.ToLowerInvariant().Contains(categoryKey) ||
                    c.Keywords.Any(k => k.ToLowerInvariant().Contains(categoryKey)));

                if (matchingCategory != null)
                {
                    return Task.FromResult<(Guid?, string?)>((matchingCategory.Id, matchingCategory.Name));
                }

                // Try fuzzy match on category name
                var fuzzyMatch = categories.FirstOrDefault(c =>
                    categoryKey.Contains(c.Name.ToLowerInvariant()) ||
                    c.Name.ToLowerInvariant().Contains(categoryKey.Substring(0, Math.Min(4, categoryKey.Length))));

                if (fuzzyMatch != null)
                {
                    return Task.FromResult<(Guid?, string?)>((fuzzyMatch.Id, fuzzyMatch.Name));
                }
            }
        }

        // No match found
        return Task.FromResult<(Guid?, string?)>((null, null));
    }
}

#region Google Vision API Models

internal class GoogleVisionRequest
{
    public List<AnnotateImageRequest> Requests { get; set; } = new();
}

internal class AnnotateImageRequest
{
    public ImageSource Image { get; set; } = new();
    public List<Feature> Features { get; set; } = new();
}

internal class ImageSource
{
    public ImageSourceInfo? Source { get; set; }
    public string? Content { get; set; } // Base64 encoded image
}

internal class ImageSourceInfo
{
    public string? ImageUri { get; set; }
    public string? GcsImageUri { get; set; }
}

internal class Feature
{
    public string Type { get; set; } = string.Empty;
    public int MaxResults { get; set; } = 10;
}

internal class GoogleVisionResponse
{
    public List<AnnotateImageResponse>? Responses { get; set; }
}

internal class AnnotateImageResponse
{
    public List<TextAnnotation>? TextAnnotations { get; set; }
    public FullTextAnnotation? FullTextAnnotation { get; set; }
    public ErrorInfo? Error { get; set; }
}

internal class TextAnnotation
{
    public string? Locale { get; set; }
    public string? Description { get; set; }
    public BoundingPoly? BoundingPoly { get; set; }
}

internal class FullTextAnnotation
{
    public string? Text { get; set; }
    public List<Page>? Pages { get; set; }
}

internal class Page
{
    public List<Block>? Blocks { get; set; }
}

internal class Block
{
    public List<Paragraph>? Paragraphs { get; set; }
}

internal class Paragraph
{
    public List<Word>? Words { get; set; }
}

internal class Word
{
    public List<Symbol>? Symbols { get; set; }
}

internal class Symbol
{
    public string? Text { get; set; }
}

internal class BoundingPoly
{
    public List<Vertex>? Vertices { get; set; }
}

internal class Vertex
{
    public int X { get; set; }
    public int Y { get; set; }
}

internal class ErrorInfo
{
    public int Code { get; set; }
    public string? Message { get; set; }
}

#endregion
