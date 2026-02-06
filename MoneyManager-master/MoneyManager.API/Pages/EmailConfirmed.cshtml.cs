using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace MoneyManager.API.Pages;

public class EmailConfirmedModel : PageModel
{
    [FromQuery(Name = "success")]
    public bool Success { get; set; }

    [FromQuery(Name = "message")]
    public string Message { get; set; } = "Email của bạn đã được xác thực. Bạn có thể mở ứng dụng để đăng nhập.";

    public string DeepLink { get; set; } = "moneymanager://login";
    public string FallbackUrl { get; set; } = "https://yourdomain.com/";
    public string Icon => Success ? "✅" : "⚠️";

    public void OnGet()
    {
        // Nothing else required; properties are bound from query
    }
}
