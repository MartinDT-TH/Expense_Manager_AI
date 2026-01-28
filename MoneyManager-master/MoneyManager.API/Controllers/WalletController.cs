using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using MoneyManager.Application.DTOs.Wallet;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Entities;
using System.Security.Claims;

namespace MoneyManager.API.Controllers;

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class WalletController : ControllerBase
{
    private readonly IWalletService _walletService;
    private readonly UserManager<AppUser> _userManager;

    public WalletController(IWalletService walletService, UserManager<AppUser> userManager)
    {
        _walletService = walletService;
        _userManager = userManager;
    }

    /// <summary>
    /// Lấy thông tin user hiện tại từ token
    /// </summary>
    private async Task<AppUser?> GetCurrentUserAsync()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(userId)) return null;
        return await _userManager.FindByIdAsync(userId);
    }

    /// <summary>
    /// GET: api/Wallet
    /// Lấy danh sách ví của user đang đăng nhập
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetWallets()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var wallets = await _walletService.GetWalletsAsync(user.Id);
        return Ok(wallets);
    }

    /// <summary>
    /// GET: api/Wallet/{id}
    /// Lấy chi tiết 1 ví
    /// </summary>
    [HttpGet("{id}")]
    public async Task<IActionResult> GetWallet(Guid id)
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var wallet = await _walletService.GetWalletByIdAsync(id, user.Id);
        if (wallet == null)
        {
            return NotFound(new { message = "Không tìm thấy ví." });
        }

        return Ok(wallet);
    }

    /// <summary>
    /// POST: api/Wallet
    /// Tạo ví mới (Free user: max 2 ví)
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateWallet([FromBody] CreateWalletRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var wallet = await _walletService.CreateWalletAsync(request, user.Id, user.IsPremium);
            return CreatedAtAction(nameof(GetWallet), new { id = wallet.Id }, wallet);
        }
        catch (InvalidOperationException ex)
        {
            // Lỗi vượt quá số ví cho phép
            return BadRequest(new { message = ex.Message, code = "WALLET_LIMIT_EXCEEDED" });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// PUT: api/Wallet/{id}
    /// Cập nhật ví
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateWallet(Guid id, [FromBody] UpdateWalletRequest request)
    {
        try
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var wallet = await _walletService.UpdateWalletAsync(id, request, user.Id);
            return Ok(wallet);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    /// <summary>
    /// DELETE: api/Wallet/{id}
    /// Xóa mềm ví (IsDeleted = true)
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteWallet(Guid id)
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var result = await _walletService.DeleteWalletAsync(id, user.Id);
        if (!result)
        {
            return NotFound(new { message = "Không tìm thấy ví hoặc bạn không có quyền xóa." });
        }

        return Ok(new { message = "Đã xóa ví thành công." });
    }

    /// <summary>
    /// GET: api/Wallet/total-balance
    /// Lấy tổng số dư tất cả ví
    /// </summary>
    [HttpGet("total-balance")]
    public async Task<IActionResult> GetTotalBalance()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var totalBalance = await _walletService.GetTotalBalanceAsync(user.Id);
        return Ok(totalBalance);
    }

    /// <summary>
    /// GET: api/Wallet/count
    /// Đếm số ví đang hoạt động (dùng cho check Premium)
    /// </summary>
    [HttpGet("count")]
    public async Task<IActionResult> GetWalletCount()
    {
        var user = await GetCurrentUserAsync();
        if (user == null) return Unauthorized();

        var count = await _walletService.CountActiveWalletsAsync(user.Id);
        return Ok(new { 
            count, 
            maxFreeWallets = 2,
            canCreateMore = user.IsPremium || count < 2
        });
    }
}
