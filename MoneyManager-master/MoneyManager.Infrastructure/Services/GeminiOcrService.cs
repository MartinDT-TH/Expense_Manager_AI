using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using MoneyManager.Application.DTOs.Transaction;
using MoneyManager.Application.Interfaces;

namespace MoneyManager.Infrastructure.Services;

/// <summary>
/// Google Gemini Vision OCR Service Implementation
/// FREE: 60 requests/minute, 1500 requests/day
/// Uses AI Vision with prompt-based extraction (no regex needed)
/// </summary>
public class GeminiOcrService : IOcrService
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<GeminiOcrService> _logger;
    
    // Gemini API endpoint - Use gemini-2.5-flash for better vision capability
    private const string GeminiApiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
    
    // Category keywords mapping (for SuggestCategoryAsync)
    private static readonly Dictionary<string, List<string>> CategoryKeywords = new()
    {
        { "food", new List<string> { 
            "restaurant", "nhà hàng", "quán ăn", "ăn uống", "cafe", "cà phê", "coffee",
            "bánh", "bread", "phở", "bún", "cơm", "rice", "pizza", "burger", "kfc",
            "lotteria", "jollibee", "highland", "starbucks", "circle k", "7-eleven",
            "grab food", "shopee food", "now", "baemin", "đồ ăn", "thức ăn", "beer", "bia"
        }},
        { "transport", new List<string> {
            "grab", "be", "xăng", "gas", "petrol", "taxi", "uber", "gojek", "xe ôm",
            "parking", "đỗ xe", "gửi xe", "toll", "phí cầu đường", "vé xe", "bus"
        }},
        { "shopping", new List<string> {
            "shop", "store", "cửa hàng", "siêu thị", "supermarket", "big c", "coopmart",
            "lotte mart", "aeon", "mega market", "emart", "winmart", "bách hóa",
            "tiki", "shopee", "lazada", "sendo", "thế giới di động", "điện máy xanh"
        }},
        { "entertainment", new List<string> {
            "cinema", "rạp", "cgv", "lotte cinema", "galaxy", "bhd", "game", "karaoke",
            "bar", "pub", "club", "netflix", "spotify", "giải trí", "vui chơi"
        }},
        { "health", new List<string> {
            "pharmacy", "nhà thuốc", "thuốc", "medicine", "bệnh viện", "hospital",
            "phòng khám", "clinic", "doctor", "bác sĩ", "y tế", "health", "gym"
        }},
        { "bills", new List<string> {
            "điện", "electric", "evn", "nước", "water", "internet", "wifi", "fpt",
            "viettel", "vnpt", "mobifone", "vinaphone", "truyền hình", "tv"
        }},
        { "education", new List<string> {
            "school", "trường", "học phí", "tuition", "sách", "book", "course",
            "khóa học", "học viện", "university", "đại học", "tiếng anh"
        }}
    };

    public GeminiOcrService(HttpClient httpClient, string apiKey, ILogger<GeminiOcrService> logger)
    {
        _httpClient = httpClient;
        _apiKey = apiKey;
        _logger = logger;
    }

    public async Task<OcrResultResponse> ExtractReceiptDataAsync(string imageUrl)
    {
        try
        {
            _logger.LogInformation("Starting Gemini OCR processing for image: {ImageUrl}", imageUrl);
            
            // Download image and convert to base64
            var imageBytes = await DownloadImageAsync(imageUrl);
            if (imageBytes == null || imageBytes.Length == 0)
            {
                return new OcrResultResponse
                {
                    Success = false,
                    ErrorMessage = "Failed to download image"
                };
            }
            
            var base64Image = Convert.ToBase64String(imageBytes);
            var mimeType = GetMimeType(imageUrl);
            
            _logger.LogInformation("Image downloaded, size: {Size} bytes, mime: {MimeType}", imageBytes.Length, mimeType);
            
            // Call the base64 method
            return await ExtractReceiptDataFromBase64Async(base64Image, mimeType);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing Gemini OCR for image: {ImageUrl}", imageUrl);
            return new OcrResultResponse
            {
                Success = false,
                ErrorMessage = $"Gemini OCR processing error: {ex.Message}"
            };
        }
    }
    
    public async Task<OcrResultResponse> ExtractReceiptDataFromBase64Async(string base64Image, string mimeType)
    {
        try
        {
            _logger.LogInformation("Starting Gemini OCR processing for base64 image, mime: {MimeType}", mimeType);
            
            // Create Gemini request with structured prompt
            var geminiRequest = new GeminiRequest
            {
                Contents = new List<GeminiContent>
                {
                    new()
                    {
                        Parts = new List<GeminiPart>
                        {
                            new GeminiTextPart { Text = CreateExtractionPrompt() },
                            new GeminiImagePart
                            {
                                InlineData = new GeminiInlineData
                                {
                                    MimeType = mimeType,
                                    Data = base64Image
                                }
                            }
                        }
                    }
                },
                GenerationConfig = new GeminiGenerationConfig
                {
                    Temperature = 0.1, // Low temperature for accuracy
                    TopK = 32,
                    TopP = 1,
                    MaxOutputTokens = 1024
                }
            };

            var jsonOptions = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            };

            var requestJson = JsonSerializer.Serialize(geminiRequest, jsonOptions);
            var content = new StringContent(requestJson, Encoding.UTF8, "application/json");

            var requestUrl = $"{GeminiApiUrl}?key={_apiKey}";
            var response = await _httpClient.PostAsync(requestUrl, content);
            var responseContent = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Gemini API error: {StatusCode} - {Response}", response.StatusCode, responseContent);
                return new OcrResultResponse
                {
                    Success = false,
                    ErrorMessage = $"Gemini API error: {response.StatusCode} - {ExtractErrorMessage(responseContent)}"
                };
            }

            _logger.LogInformation("Gemini API response received");
            
            // Parse Gemini response
            var geminiResponse = JsonSerializer.Deserialize<GeminiResponse>(responseContent, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            var generatedText = geminiResponse?.Candidates?.FirstOrDefault()?.Content?.Parts?.FirstOrDefault()?.Text;
            
            if (string.IsNullOrEmpty(generatedText))
            {
                return new OcrResultResponse
                {
                    Success = false,
                    ErrorMessage = "No text generated from Gemini"
                };
            }

            _logger.LogInformation("Gemini generated text: {Text}", generatedText.Length > 500 ? generatedText[..500] + "..." : generatedText);

            // Parse JSON from Gemini response
            var result = ParseGeminiResponse(generatedText);
            result.RawData = JsonSerializer.Serialize(new { generatedText, extractedAt = DateTime.UtcNow });

            _logger.LogInformation("Gemini OCR result - Amount: {Amount}, Date: {Date}, Merchant: {Merchant}", 
                result.Amount, result.Date, result.MerchantName);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing Gemini OCR from base64");
            return new OcrResultResponse
            {
                Success = false,
                ErrorMessage = $"Gemini OCR processing error: {ex.Message}"
            };
        }
    }

    /// <summary>
    /// Create the prompt for receipt extraction
    /// </summary>
    private string CreateExtractionPrompt()
    {
        return @"Analyze this receipt/bill image and extract information in JSON format.

IMPORTANT RULES:
1. Extract the TOTAL amount (look for: Total, Tổng, Thành tiền, TIEN MAT, Tiền mặt, Grand Total, Amount Due)
2. Extract the date (any format, convert to YYYY-MM-DD)
3. Extract merchant/store name (usually at the top)
4. Extract a brief description of items purchased
5. Suggest a category from: Ăn uống, Di chuyển, Mua sắm, Y tế, Giải trí, Giáo dục, Hóa đơn, Khác

Return ONLY valid JSON in this exact format (no markdown, no explanation):
{
    ""amount"": 123456,
    ""date"": ""2024-01-15"",
    ""merchant"": ""Store Name"",
    ""description"": ""Brief description of purchase"",
    ""category_suggestion"": ""Ăn uống"",
    ""confidence"": 0.95
}

If a field cannot be determined, use null for that field.
Amount should be a number without currency symbols.
Date must be in YYYY-MM-DD format.";
    }

    /// <summary>
    /// Parse Gemini's JSON response into OcrResultResponse
    /// </summary>
    private OcrResultResponse ParseGeminiResponse(string generatedText)
    {
        var result = new OcrResultResponse { Success = true };

        try
        {
            // Clean up the response - remove markdown code blocks if present
            var jsonText = generatedText.Trim();
            if (jsonText.StartsWith("```json"))
            {
                jsonText = jsonText.Substring(7);
            }
            else if (jsonText.StartsWith("```"))
            {
                jsonText = jsonText.Substring(3);
            }
            if (jsonText.EndsWith("```"))
            {
                jsonText = jsonText.Substring(0, jsonText.Length - 3);
            }
            jsonText = jsonText.Trim();

            // Parse JSON
            using var doc = JsonDocument.Parse(jsonText);
            var root = doc.RootElement;

            // Extract amount
            if (root.TryGetProperty("amount", out var amountProp))
            {
                if (amountProp.ValueKind == JsonValueKind.Number)
                {
                    result.Amount = amountProp.GetDecimal();
                }
                else if (amountProp.ValueKind == JsonValueKind.String)
                {
                    var amountStr = amountProp.GetString()?.Replace(",", "").Replace(".", "").Trim();
                    if (decimal.TryParse(amountStr, out var amount))
                    {
                        result.Amount = amount;
                    }
                }
            }

            // Extract date
            if (root.TryGetProperty("date", out var dateProp) && dateProp.ValueKind == JsonValueKind.String)
            {
                var dateStr = dateProp.GetString();
                if (!string.IsNullOrEmpty(dateStr) && DateTime.TryParse(dateStr, out var date))
                {
                    result.Date = date;
                }
            }

            // Extract merchant
            if (root.TryGetProperty("merchant", out var merchantProp) && merchantProp.ValueKind == JsonValueKind.String)
            {
                result.MerchantName = merchantProp.GetString();
            }

            // Extract description
            if (root.TryGetProperty("description", out var descProp) && descProp.ValueKind == JsonValueKind.String)
            {
                result.Description = descProp.GetString();
            }

            // Extract category suggestion
            if (root.TryGetProperty("category_suggestion", out var catProp) && catProp.ValueKind == JsonValueKind.String)
            {
                result.SuggestedCategoryName = catProp.GetString();
            }

            _logger.LogInformation("Successfully parsed Gemini JSON response");
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Failed to parse Gemini response as JSON, attempting text extraction");
            // If JSON parsing fails, try to extract basic info from text
            result = ExtractFromPlainText(generatedText);
        }

        return result;
    }

    /// <summary>
    /// Fallback: Extract data from plain text if JSON parsing fails
    /// </summary>
    private OcrResultResponse ExtractFromPlainText(string text)
    {
        var result = new OcrResultResponse { Success = true };

        // Try to find amount pattern
        var amountPatterns = new[]
        {
            @"amount[""']?\s*[:=]\s*(\d[\d,\.]*)",
            @"(\d{1,3}(?:[,\.]\d{3})+|\d+)\s*(?:VND|đ|dong|đồng)?",
        };

        foreach (var pattern in amountPatterns)
        {
            var match = System.Text.RegularExpressions.Regex.Match(text, pattern, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            if (match.Success)
            {
                var amountStr = match.Groups[1].Value.Replace(",", "").Replace(".", "");
                if (decimal.TryParse(amountStr, out var amount) && amount > 0)
                {
                    result.Amount = amount;
                    break;
                }
            }
        }

        // Try to find date pattern
        var dateMatch = System.Text.RegularExpressions.Regex.Match(text, @"(\d{4}[-/]\d{2}[-/]\d{2})|(\d{2}[-/]\d{2}[-/]\d{4})");
        if (dateMatch.Success)
        {
            if (DateTime.TryParse(dateMatch.Value, out var date))
            {
                result.Date = date;
            }
        }

        return result;
    }

    /// <summary>
    /// Download image from URL
    /// </summary>
    private async Task<byte[]?> DownloadImageAsync(string imageUrl)
    {
        try
        {
            return await _httpClient.GetByteArrayAsync(imageUrl);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to download image from {Url}", imageUrl);
            return null;
        }
    }

    /// <summary>
    /// Get MIME type from URL
    /// </summary>
    private string GetMimeType(string url)
    {
        var extension = Path.GetExtension(url)?.ToLowerInvariant() ?? ".jpg";
        return extension switch
        {
            ".png" => "image/png",
            ".gif" => "image/gif",
            ".webp" => "image/webp",
            ".bmp" => "image/bmp",
            _ => "image/jpeg"
        };
    }

    /// <summary>
    /// Extract error message from API response
    /// </summary>
    private string ExtractErrorMessage(string responseContent)
    {
        try
        {
            using var doc = JsonDocument.Parse(responseContent);
            if (doc.RootElement.TryGetProperty("error", out var error))
            {
                if (error.TryGetProperty("message", out var message))
                {
                    return message.GetString() ?? "Unknown error";
                }
            }
        }
        catch { }
        return responseContent.Length > 200 ? responseContent[..200] : responseContent;
    }

    public Task<(Guid? CategoryId, string? CategoryName)> SuggestCategoryAsync(
        string? merchantName, 
        string? description, 
        IEnumerable<CategorySuggestion> categories)
    {
        var searchText = $"{merchantName} {description}".ToLowerInvariant();
        
        // Find best matching category based on keywords
        var categoryList = categories.ToList();
        
        foreach (var category in categoryList.Where(c => c.Type == "EXPENSE"))
        {
            // Check if any keyword matches
            var categoryNameLower = category.Name.ToLowerInvariant();
            
            // Map category name to our keyword dictionary
            string? keywordKey = null;
            if (categoryNameLower.Contains("ăn") || categoryNameLower.Contains("food") || categoryNameLower.Contains("uống"))
                keywordKey = "food";
            else if (categoryNameLower.Contains("di chuyển") || categoryNameLower.Contains("transport") || categoryNameLower.Contains("xăng"))
                keywordKey = "transport";
            else if (categoryNameLower.Contains("mua sắm") || categoryNameLower.Contains("shopping"))
                keywordKey = "shopping";
            else if (categoryNameLower.Contains("giải trí") || categoryNameLower.Contains("entertainment"))
                keywordKey = "entertainment";
            else if (categoryNameLower.Contains("y tế") || categoryNameLower.Contains("health") || categoryNameLower.Contains("sức khỏe"))
                keywordKey = "health";
            else if (categoryNameLower.Contains("hóa đơn") || categoryNameLower.Contains("bill") || categoryNameLower.Contains("điện") || categoryNameLower.Contains("nước"))
                keywordKey = "bills";
            else if (categoryNameLower.Contains("giáo dục") || categoryNameLower.Contains("education") || categoryNameLower.Contains("học"))
                keywordKey = "education";
            
            if (keywordKey != null && CategoryKeywords.TryGetValue(keywordKey, out var keywords))
            {
                if (keywords.Any(k => searchText.Contains(k)))
                {
                    return Task.FromResult<(Guid? CategoryId, string? CategoryName)>((category.Id, category.Name));
                }
            }
            
            // Also check category's own keywords
            if (category.Keywords.Any(k => searchText.Contains(k.ToLowerInvariant())))
            {
                return Task.FromResult<(Guid? CategoryId, string? CategoryName)>((category.Id, category.Name));
            }
        }

        return Task.FromResult<(Guid? CategoryId, string? CategoryName)>((null, null));
    }
}

#region Gemini API Models

public class GeminiRequest
{
    public List<GeminiContent> Contents { get; set; } = new();
    public GeminiGenerationConfig? GenerationConfig { get; set; }
}

public class GeminiContent
{
    public List<GeminiPart> Parts { get; set; } = new();
}

[JsonPolymorphic]
[JsonDerivedType(typeof(GeminiTextPart))]
[JsonDerivedType(typeof(GeminiImagePart))]
public abstract class GeminiPart { }

public class GeminiTextPart : GeminiPart
{
    public string Text { get; set; } = string.Empty;
}

public class GeminiImagePart : GeminiPart
{
    [JsonPropertyName("inline_data")]
    public GeminiInlineData InlineData { get; set; } = new();
}

public class GeminiInlineData
{
    [JsonPropertyName("mime_type")]
    public string MimeType { get; set; } = "image/jpeg";
    public string Data { get; set; } = string.Empty;
}

public class GeminiGenerationConfig
{
    public double Temperature { get; set; } = 0.1;
    public int TopK { get; set; } = 32;
    public double TopP { get; set; } = 1;
    public int MaxOutputTokens { get; set; } = 1024;
}

public class GeminiResponse
{
    public List<GeminiCandidate>? Candidates { get; set; }
}

public class GeminiCandidate
{
    public GeminiContentResponse? Content { get; set; }
}

public class GeminiContentResponse
{
    public List<GeminiPartResponse>? Parts { get; set; }
}

public class GeminiPartResponse
{
    public string? Text { get; set; }
}

#endregion
