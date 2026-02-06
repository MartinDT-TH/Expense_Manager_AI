using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using MoneyManager.Application.Interfaces;
using MoneyManager.Infrastructure.Services;
using MoneyManager.Domain.Entities;
using MoneyManager.Infrastructure.Data;
using MoneyManager.Infrastructure.Data.Context;
using MoneyManager.API.Hubs;
using System.Text;


var builder = WebApplication.CreateBuilder(args);

// 1. DB Context - SQL Server with transient-failure resiliency
builder.Services.AddDbContext<MoneyManagerDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnectionString"),
        sqlOptions =>
        {
            // Retry on transient errors (e.g., dropped connections on cloud DB)
            sqlOptions.EnableRetryOnFailure(
                maxRetryCount: 5,
                maxRetryDelay: TimeSpan.FromSeconds(10),
                errorNumbersToAdd: null);
        }));

// 2. Identity
builder.Services.AddIdentity<AppUser, AppRole>()
    .AddEntityFrameworkStores<MoneyManagerDbContext>()
    .AddDefaultTokenProviders();

// 3. Authentication with JWT
var key = Encoding.ASCII.GetBytes(builder.Configuration["JwtSettings:Key"]!);
builder.Services.AddAuthentication(options => {
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(options => {
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = false,
        ValidateAudience = false
    };
    
    // Configure JWT events for proper error handling and SignalR
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            
            // If the request is for SignalR hub
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        },
        
        // Return proper JSON error for invalid/expired tokens
        OnAuthenticationFailed = context =>
        {
            var response = context.HttpContext.Response;
            
            // Determine error type
            string errorCode;
            string message;
            
            if (context.Exception is SecurityTokenExpiredException)
            {
                errorCode = "TOKEN_EXPIRED";
                message = "Token đã hết hạn. Vui lòng đăng nhập lại.";
                response.Headers.Append("Token-Expired", "true");
            }
            else if (context.Exception is SecurityTokenInvalidSignatureException)
            {
                errorCode = "TOKEN_INVALID";
                message = "Token không hợp lệ.";
            }
            else
            {
                errorCode = "AUTH_FAILED";
                message = "Xác thực thất bại.";
            }
            
            // Store error info for OnChallenge
            context.HttpContext.Items["AuthErrorCode"] = errorCode;
            context.HttpContext.Items["AuthErrorMessage"] = message;
            
            return Task.CompletedTask;
        },
        
        // Handle 401 challenge - return JSON instead of default response
        OnChallenge = async context =>
        {
            // Skip default challenge behavior
            context.HandleResponse();
            
            var response = context.HttpContext.Response;
            response.StatusCode = 401;
            response.ContentType = "application/json";
            
            // Get error info from OnAuthenticationFailed if available
            var errorCode = context.HttpContext.Items["AuthErrorCode"] as string ?? "UNAUTHORIZED";
            var message = context.HttpContext.Items["AuthErrorMessage"] as string ?? "Bạn cần đăng nhập để truy cập.";
            
            var errorResponse = new
            {
                success = false,
                errorCode = errorCode,
                message = message
            };
            
            await response.WriteAsJsonAsync(errorResponse);
        },
        
        // Handle 403 forbidden
        OnForbidden = async context =>
        {
            var response = context.HttpContext.Response;
            response.StatusCode = 403;
            response.ContentType = "application/json";
            
            var errorResponse = new
            {
                success = false,
                errorCode = "FORBIDDEN",
                message = "Bạn không có quyền truy cập tài nguyên này."
            };
            
            await response.WriteAsJsonAsync(errorResponse);
        }
    };
});

// 3.1 SignalR Configuration
builder.Services.AddSignalR();
builder.Services.AddScoped<IGroupHubNotifier, GroupHubNotifier>();

// 3.2 Memory Cache for OTP storage
builder.Services.AddMemoryCache();

// 4. Đăng ký Service (QUAN TRỌNG)
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IWalletService, WalletService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<ITransactionService>(sp =>
{
    var context = sp.GetRequiredService<MoneyManagerDbContext>();
    var ocrService = sp.GetRequiredService<IOcrService>();
    var logger = sp.GetRequiredService<ILogger<TransactionService>>();
    var notifier = sp.GetService<IGroupHubNotifier>();
    return new TransactionService(context, ocrService, logger, notifier);
});
builder.Services.AddScoped<IBudgetService, BudgetService>();
builder.Services.AddScoped<IGroupService>(sp =>
{
    var context = sp.GetRequiredService<MoneyManagerDbContext>();
    var notifier = sp.GetService<IGroupHubNotifier>();
    return new GroupService(context, notifier);
});
builder.Services.AddScoped<ISyncService, SyncService>();
builder.Services.AddScoped<IReportService, ReportService>();

// 4.2 Subscription/Purchase Verification Service
builder.Services.AddHttpClient("GooglePlayApi", client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
});
builder.Services.AddScoped<IPurchaseVerificationService, PurchaseVerificationService>();

// 4.1 OCR Service Configuration - HYBRID MODE
// Primary: Google Gemini (FREE - 60 req/min, 1500/day)
// Fallback: Groq Llama Vision (FREE - 30 req/min, UNLIMITED/day)
var geminiApiKey = builder.Configuration["Gemini:ApiKey"] ?? "AIzaSyDQD7WzOCibosMNngEJh1RmU66_pbf_sMI";
var groqApiKey = builder.Configuration["Groq:ApiKey"] ?? "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";

// Register individual OCR services
builder.Services.AddHttpClient<GeminiOcrService>((serviceProvider, client) =>
{
    client.Timeout = TimeSpan.FromSeconds(60);
}).AddTypedClient<GeminiOcrService>((httpClient, serviceProvider) =>
{
    var logger = serviceProvider.GetRequiredService<ILogger<GeminiOcrService>>();
    return new GeminiOcrService(httpClient, geminiApiKey, logger);
});

builder.Services.AddHttpClient<GroqOcrService>((serviceProvider, client) =>
{
    client.Timeout = TimeSpan.FromSeconds(30); // Groq is faster
}).AddTypedClient<GroqOcrService>((httpClient, serviceProvider) =>
{
    var logger = serviceProvider.GetRequiredService<ILogger<GroqOcrService>>();
    return new GroqOcrService(httpClient, groqApiKey, logger);
});

// Register HybridOcrService as the primary IOcrService
builder.Services.AddScoped<IOcrService>(serviceProvider =>
{
    var geminiService = serviceProvider.GetRequiredService<GeminiOcrService>();
    var groqService = serviceProvider.GetRequiredService<GroqOcrService>();
    var logger = serviceProvider.GetRequiredService<ILogger<HybridOcrService>>();
    return new HybridOcrService(geminiService, groqService, logger);
});

builder.Services.AddControllers(); 
builder.Services.AddRazorPages();
builder.Services.AddEndpointsApiExplorer();

// 5. Swagger Config with Auth Button
builder.Services.AddSwaggerGen(c => {
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "MoneyManager API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "Nhập 'Bearer [Token]'",
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            new string[] {}
        }
    });
});

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
//builder.Services.AddOpenApi();

var app = builder.Build();

// === SEED DATA ===
using (var scope = app.Services.CreateScope())
{
    try
    {
        // Truyền ServiceProvider vào hàm static
        await DbInitializer.Initialize(scope.ServiceProvider);
    }
    catch (Exception ex)
    {
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "Loi khi khoi tao Database.");
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
    //app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseAuthentication(); // Bật xác thực
app.UseAuthorization();  // Bật phân quyền

// Map SignalR Hub
app.MapHub<GroupHub>("/hubs/group");

app.MapControllers();
app.MapRazorPages();

app.Run();
