using System.Text.Json;
using Microsoft.Extensions.Logging;
using MoneyManager.Application.DTOs.Transaction;
using MoneyManager.Application.Interfaces;

namespace MoneyManager.Infrastructure.Services;

/// <summary>
/// Hybrid OCR Service - Tries Gemini first, falls back to Groq if quota exceeded
/// Strategy: Gemini (60 req/min, 1500/day) → Groq (30 req/min, UNLIMITED/day)
/// </summary>
public class HybridOcrService : IOcrService
{
    private readonly GeminiOcrService _geminiService;
    private readonly GroqOcrService _groqService;
    private readonly ILogger<HybridOcrService> _logger;
    
    // Track Gemini quota (simple in-memory tracking)
    private static int _geminiDailyCount = 0;
    private static DateTime _lastResetDate = DateTime.UtcNow.Date;
    private const int GeminiDailyLimit = 1400; // Leave 100 buffer

    public HybridOcrService(
        GeminiOcrService geminiService,
        GroqOcrService groqService,
        ILogger<HybridOcrService> logger)
    {
        _geminiService = geminiService;
        _groqService = groqService;
        _logger = logger;
    }

    public async Task<OcrResultResponse> ExtractReceiptDataAsync(string imageUrl)
    {
        ResetDailyCounterIfNeeded();
        
        // Try Gemini first if quota available
        if (_geminiDailyCount < GeminiDailyLimit)
        {
            _logger.LogInformation("[Hybrid] Trying Gemini first (daily count: {Count}/{Limit})", 
                _geminiDailyCount, GeminiDailyLimit);
            
            var geminiResult = await _geminiService.ExtractReceiptDataAsync(imageUrl);
            
            if (geminiResult.Success)
            {
                _geminiDailyCount++;
                geminiResult.RawData = AddProviderInfo(geminiResult.RawData, "gemini");
                _logger.LogInformation("[Hybrid] Gemini succeeded");
                return geminiResult;
            }
            
            // Check if it's a quota error (429)
            if (geminiResult.ErrorMessage?.Contains("429") == true || 
                geminiResult.ErrorMessage?.Contains("quota") == true ||
                geminiResult.ErrorMessage?.Contains("rate") == true)
            {
                _logger.LogWarning("[Hybrid] Gemini quota exceeded, falling back to Groq");
            }
            else
            {
                // Other error, still try Groq
                _logger.LogWarning("[Hybrid] Gemini failed: {Error}, trying Groq", geminiResult.ErrorMessage);
            }
        }
        else
        {
            _logger.LogInformation("[Hybrid] Gemini daily limit reached, using Groq directly");
        }
        
        // Fallback to Groq
        _logger.LogInformation("[Hybrid] Using Groq (unlimited daily quota)");
        var groqResult = await _groqService.ExtractReceiptDataAsync(imageUrl);
        groqResult.RawData = AddProviderInfo(groqResult.RawData, "groq");
        
        return groqResult;
    }

    public async Task<OcrResultResponse> ExtractReceiptDataFromBase64Async(string base64Image, string mimeType)
    {
        ResetDailyCounterIfNeeded();
        
        // Try Gemini first if quota available
        if (_geminiDailyCount < GeminiDailyLimit)
        {
            _logger.LogInformation("[Hybrid] Trying Gemini first (daily count: {Count}/{Limit})", 
                _geminiDailyCount, GeminiDailyLimit);
            
            var geminiResult = await _geminiService.ExtractReceiptDataFromBase64Async(base64Image, mimeType);
            
            if (geminiResult.Success)
            {
                _geminiDailyCount++;
                geminiResult.RawData = AddProviderInfo(geminiResult.RawData, "gemini");
                _logger.LogInformation("[Hybrid] Gemini succeeded");
                return geminiResult;
            }
            
            // Check if it's a quota error
            if (geminiResult.ErrorMessage?.Contains("429") == true || 
                geminiResult.ErrorMessage?.Contains("quota") == true ||
                geminiResult.ErrorMessage?.Contains("rate") == true ||
                geminiResult.ErrorMessage?.Contains("RESOURCE_EXHAUSTED") == true)
            {
                _logger.LogWarning("[Hybrid] Gemini quota exceeded, falling back to Groq");
            }
            else
            {
                _logger.LogWarning("[Hybrid] Gemini failed: {Error}, trying Groq", geminiResult.ErrorMessage);
            }
        }
        else
        {
            _logger.LogInformation("[Hybrid] Gemini daily limit reached, using Groq directly");
        }
        
        // Fallback to Groq
        _logger.LogInformation("[Hybrid] Using Groq (unlimited daily quota)");
        var groqResult = await _groqService.ExtractReceiptDataFromBase64Async(base64Image, mimeType);
        groqResult.RawData = AddProviderInfo(groqResult.RawData, "groq");
        
        return groqResult;
    }

    public async Task<(Guid? CategoryId, string? CategoryName)> SuggestCategoryAsync(
        string? merchantName, 
        string? description, 
        IEnumerable<CategorySuggestion> categories)
    {
        // Use Gemini for category suggestion (lightweight, doesn't count towards vision quota)
        return await _geminiService.SuggestCategoryAsync(merchantName, description, categories);
    }

    /// <summary>
    /// Reset daily counter at midnight UTC
    /// </summary>
    private void ResetDailyCounterIfNeeded()
    {
        var today = DateTime.UtcNow.Date;
        if (today > _lastResetDate)
        {
            _logger.LogInformation("[Hybrid] Resetting daily Gemini counter (new day)");
            _geminiDailyCount = 0;
            _lastResetDate = today;
        }
    }

    /// <summary>
    /// Add provider info to raw data for tracking
    /// </summary>
    private string AddProviderInfo(string? rawData, string provider)
    {
        try
        {
            if (string.IsNullOrEmpty(rawData))
            {
                return JsonSerializer.Serialize(new { provider, processedAt = DateTime.UtcNow });
            }
            
            using var doc = JsonDocument.Parse(rawData);
            var dict = JsonSerializer.Deserialize<Dictionary<string, object>>(rawData) ?? new();
            dict["provider"] = provider;
            dict["hybridMode"] = true;
            return JsonSerializer.Serialize(dict);
        }
        catch
        {
            return JsonSerializer.Serialize(new { provider, rawData, processedAt = DateTime.UtcNow });
        }
    }

    /// <summary>
    /// Get current quota status (for monitoring)
    /// </summary>
    public static (int used, int limit, DateTime resetDate) GetGeminiQuotaStatus()
    {
        return (_geminiDailyCount, GeminiDailyLimit, _lastResetDate.AddDays(1));
    }
}
