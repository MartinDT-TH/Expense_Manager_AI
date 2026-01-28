using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using MoneyManager.Application.DTOs.Transaction;
using MoneyManager.Application.Interfaces;

namespace MoneyManager.Infrastructure.Services;

/// <summary>
/// Groq OCR Service Implementation using Llama 4 Scout Vision
/// FREE: 30 requests/minute, UNLIMITED daily requests
/// Super fast inference (< 1 second)
/// Model: meta-llama/llama-4-scout-17b-16e-instruct (replacement for deprecated llama-3.2-90b-vision-preview)
/// </summary>
public class GroqOcrService : IOcrService
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly ILogger<GroqOcrService> _logger;
    
    // Groq API endpoint
    private const string GroqApiUrl = "https://api.groq.com/openai/v1/chat/completions";
    
    // Llama 4 Scout Vision model - replacement for deprecated llama-3.2-90b-vision-preview
    // Supports vision with 20MB max image size
    private const string ModelId = "meta-llama/llama-4-scout-17b-16e-instruct";

    public GroqOcrService(HttpClient httpClient, string apiKey, ILogger<GroqOcrService> logger)
    {
        _httpClient = httpClient;
        _apiKey = apiKey;
        _logger = logger;
    }

    public async Task<OcrResultResponse> ExtractReceiptDataAsync(string imageUrl)
    {
        try
        {
            _logger.LogInformation("[Groq] Starting OCR processing for image URL: {ImageUrl}", imageUrl);
            
            // Download image and convert to base64
            var imageBytes = await _httpClient.GetByteArrayAsync(imageUrl);
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
            
            return await ExtractReceiptDataFromBase64Async(base64Image, mimeType);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Groq] Error processing OCR for image URL: {ImageUrl}", imageUrl);
            return new OcrResultResponse
            {
                Success = false,
                ErrorMessage = $"Groq OCR processing error: {ex.Message}"
            };
        }
    }

    public async Task<OcrResultResponse> ExtractReceiptDataFromBase64Async(string base64Image, string mimeType)
    {
        try
        {
            _logger.LogInformation("[Groq] Starting OCR processing for base64 image, mime: {MimeType}", mimeType);
            
            // Create Groq request (OpenAI-compatible format)
            var groqRequest = new GroqChatRequest
            {
                Model = ModelId,
                Messages = new List<GroqMessage>
                {
                    new()
                    {
                        Role = "user",
                        Content = new List<GroqContent>
                        {
                            new GroqTextContent { Type = "text", Text = CreateExtractionPrompt() },
                            new GroqImageContent
                            {
                                Type = "image_url",
                                ImageUrl = new GroqImageUrl
                                {
                                    Url = $"data:{mimeType};base64,{base64Image}"
                                }
                            }
                        }
                    }
                },
                Temperature = 0.1,
                MaxTokens = 1024
            };

            var jsonOptions = new JsonSerializerOptions
            {
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            };

            var requestJson = JsonSerializer.Serialize(groqRequest, jsonOptions);
            _logger.LogDebug("[Groq] Request JSON: {Json}", requestJson);
            var content = new StringContent(requestJson, Encoding.UTF8, "application/json");

            // Add Authorization header
            _httpClient.DefaultRequestHeaders.Clear();
            _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {_apiKey}");

            var response = await _httpClient.PostAsync(GroqApiUrl, content);
            var responseContent = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("[Groq] API error: {StatusCode} - {Response}", response.StatusCode, responseContent);
                return new OcrResultResponse
                {
                    Success = false,
                    ErrorMessage = $"Groq API error: {response.StatusCode} - {ExtractErrorMessage(responseContent)}"
                };
            }

            _logger.LogInformation("[Groq] API response received successfully");
            
            // Parse Groq response
            var groqResponse = JsonSerializer.Deserialize<GroqChatResponse>(responseContent, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            var generatedText = groqResponse?.Choices?.FirstOrDefault()?.Message?.Content;
            
            if (string.IsNullOrEmpty(generatedText))
            {
                return new OcrResultResponse
                {
                    Success = false,
                    ErrorMessage = "No text generated from Groq"
                };
            }

            _logger.LogInformation("[Groq] Generated text length: {Length}", generatedText.Length);

            // Parse JSON from response
            var result = ParseGroqResponse(generatedText);
            result.RawData = JsonSerializer.Serialize(new { generatedText, extractedAt = DateTime.UtcNow, provider = "groq" });

            _logger.LogInformation("[Groq] OCR result - Amount: {Amount}, Date: {Date}, Merchant: {Merchant}", 
                result.Amount, result.Date, result.MerchantName);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Groq] Error processing OCR from base64");
            return new OcrResultResponse
            {
                Success = false,
                ErrorMessage = $"Groq OCR processing error: {ex.Message}"
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
    /// Parse Groq's response into OcrResultResponse
    /// </summary>
    private OcrResultResponse ParseGroqResponse(string generatedText)
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

            _logger.LogInformation("[Groq] Successfully parsed JSON response");
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "[Groq] Failed to parse response as JSON");
            result.Success = false;
            result.ErrorMessage = "Failed to parse Groq response";
        }

        return result;
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
        // Reuse category suggestion logic - same as Gemini
        var searchText = $"{merchantName} {description}".ToLowerInvariant();
        
        foreach (var category in categories.Where(c => c.Type == "EXPENSE"))
        {
            if (category.Keywords.Any(k => searchText.Contains(k.ToLowerInvariant())))
            {
                return Task.FromResult<(Guid?, string?)>((category.Id, category.Name));
            }
        }
        
        return Task.FromResult<(Guid?, string?)>((null, null));
    }
}

#region Groq Request/Response Models

public class GroqChatRequest
{
    [JsonPropertyName("model")]
    public string Model { get; set; } = string.Empty;
    
    [JsonPropertyName("messages")]
    public List<GroqMessage> Messages { get; set; } = new();
    
    [JsonPropertyName("temperature")]
    public double Temperature { get; set; } = 0.1;
    
    [JsonPropertyName("max_tokens")]
    public int MaxTokens { get; set; } = 1024;
}

public class GroqMessage
{
    [JsonPropertyName("role")]
    public string Role { get; set; } = "user";
    
    [JsonPropertyName("content")]
    public List<GroqContent> Content { get; set; } = new();
}

[JsonPolymorphic(TypeDiscriminatorPropertyName = "type")]
[JsonDerivedType(typeof(GroqTextContent), "text")]
[JsonDerivedType(typeof(GroqImageContent), "image_url")]
public abstract class GroqContent
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;
}

public class GroqTextContent : GroqContent
{
    [JsonPropertyName("text")]
    public string Text { get; set; } = string.Empty;
}

public class GroqImageContent : GroqContent
{
    [JsonPropertyName("image_url")]
    public GroqImageUrl ImageUrl { get; set; } = new();
}

public class GroqImageUrl
{
    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;
}

public class GroqChatResponse
{
    public List<GroqChoice>? Choices { get; set; }
}

public class GroqChoice
{
    public GroqMessageResponse? Message { get; set; }
}

public class GroqMessageResponse
{
    public string? Content { get; set; }
}

#endregion
