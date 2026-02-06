using Microsoft.AspNetCore.Identity;
using System.ComponentModel.DataAnnotations.Schema;

namespace MoneyManager.Domain.Entities
{
    public class AppUser : IdentityUser<Guid> // Id là Guid
    {
        public string? FullName { get; set; }
        public string? AvatarUrl { get; set; }
        
        // Profile fields
        public string? Phone { get; set; }
        public string? Address { get; set; }

        public bool IsPremium { get; set; } = false;
        public DateTime? PremiumExpiryDate { get; set; }

        public bool IsActive { get; set; } = true;
        public string? BanReason { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // ===== 2FA & OAuth Fields =====
        public bool TwoFactorEnabled { get; set; } = false;
        public string? TwoFactorSecret { get; set; }  // TOTP secret key (encrypted)
        public string? BackupCodes { get; set; }      // JSON array of hashed backup codes
        
        // Google OAuth
        public string? GoogleId { get; set; }
        public string? GoogleEmail { get; set; }
        public bool IsGoogleLinked { get; set; } = false;
        
        // Refresh Token
        public string? RefreshToken { get; set; }
        public DateTime? RefreshTokenExpiryTime { get; set; }

        public virtual ICollection<Budget> Budgets { get; set; } = new List<Budget>();
        public virtual ICollection<Category> Categories { get; set; } = new List<Category>();

        // Danh sách các nhóm mình là thành viên (Member/Admin)
        public virtual ICollection<GroupMember> GroupMembers { get; set; } = new List<GroupMember>();
        // Danh sách các nhóm mình tạo (Owner)
        public virtual ICollection<Group> CreatedGroups { get; set; } = new List<Group>();
        public virtual ICollection<SubscriptionLog> SubscriptionLogs { get; set; } = new List<SubscriptionLog>();
        public virtual ICollection<Wallet> Wallets { get; set; } = new List<Wallet>();
    }
    public class AppRole : IdentityRole<Guid>
    {
        // Thêm Description để chú thích role này làm gì (VD: "Quản trị viên hệ thống")
        public string? Description { get; set; }
    }
}