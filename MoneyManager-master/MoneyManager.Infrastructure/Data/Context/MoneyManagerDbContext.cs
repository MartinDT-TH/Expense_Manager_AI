using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;

namespace MoneyManager.Infrastructure.Data.Context;

public partial class MoneyManagerDbContext : IdentityDbContext<AppUser, AppRole, Guid>
{
    // Constructor nhận options từ Program.cs (DI Container)
    public MoneyManagerDbContext(DbContextOptions<MoneyManagerDbContext> options)
        : base(options)
    {
    }

    // --- Khai báo các bảng (DbSet) ---
    public virtual DbSet<Budget> Budgets { get; set; }
    public virtual DbSet<Category> Categories { get; set; }
    public virtual DbSet<Group> Groups { get; set; }
    public virtual DbSet<GroupMember> GroupMembers { get; set; }
    public virtual DbSet<SubscriptionLog> SubscriptionLogs { get; set; }
    public virtual DbSet<SystemAuditLog> SystemAuditLogs { get; set; }
    public virtual DbSet<Transaction> Transactions { get; set; }
    public virtual DbSet<Wallet> Wallets { get; set; }

    // --- Cấu hình Fluent API ---
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // 1. QUAN TRỌNG: Gọi base để Identity tự tạo các bảng Users, Roles, Claims...
        base.OnModelCreating(modelBuilder);

        // 2. Cấu hình AppUser (Mở rộng từ IdentityUser)
        modelBuilder.Entity<AppUser>(entity =>
        {
            entity.ToTable("AspNetUsers"); // Giữ tên bảng mặc định

            entity.Property(e => e.FullName).HasMaxLength(250);
            entity.Property(e => e.AvatarUrl).HasMaxLength(500);
            entity.Property(e => e.BanReason).HasMaxLength(500);
            entity.Property(e => e.PremiumExpiryDate).HasColumnType("datetime");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()"); // Tự động lấy giờ UTC

            // Logic mặc định
            entity.Property(e => e.IsActive).HasDefaultValue(true);
            entity.Property(e => e.IsPremium).HasDefaultValue(false);
        });

        // 3. Wallet (Ví tiền) - Cấu hình Hybrid
        modelBuilder.Entity<Wallet>(entity => {
            // Currency là Enum -> Lưu chữ (VND, USD) để dễ đọc trong DB
            entity.Property(e => e.Currency).HasConversion<string>().HasMaxLength(5);

            // Type là String -> User tự nhập (Tiền mặt, Hụi, Bitcoin...) -> Không convert
            entity.Property(e => e.Type).HasMaxLength(50);

            entity.Property(e => e.Balance).HasColumnType("decimal(18, 2)").HasDefaultValue(0m);
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // 4. Category (Danh mục)
        modelBuilder.Entity<Category>(entity => {
            // Type là Enum (Income/Expense) -> Lưu chữ
            entity.Property(e => e.Type).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.IconCode).HasMaxLength(50);
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // 5. GroupMember (Thành viên nhóm)
        modelBuilder.Entity<GroupMember>(entity => {
            // Khóa chính phức hợp (Composite Key)
            entity.HasKey(e => new { e.GroupId, e.UserId });

            // Role là Enum (Admin/Member) -> Lưu chữ
            entity.Property(e => e.Role).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.JoinedAt).HasDefaultValueSql("GETUTCDATE()");
        });

        // 6. SubscriptionLog (Lịch sử mua gói)
        modelBuilder.Entity<SubscriptionLog>(entity => {
            // Tất cả Enum lưu chữ hết cho dễ debug
            entity.Property(e => e.Platform).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.Status).HasConversion<string>().HasMaxLength(20);
            entity.Property(e => e.Currency).HasConversion<string>().HasMaxLength(5);
            entity.Property(e => e.Amount).HasColumnType("decimal(18, 2)");
        });

        // 7. Transaction (Giao dịch)
        modelBuilder.Entity<Transaction>(entity => {
            entity.Property(e => e.Amount).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TransactionDate).HasColumnType("datetime");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
            entity.Property(e => e.Note).HasMaxLength(500);
        });

        // 8. Budget (Ngân sách)
        modelBuilder.Entity<Budget>(entity => {
            entity.Property(e => e.AmountLimit).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.StartDate).HasColumnType("datetime");
            entity.Property(e => e.EndDate).HasColumnType("datetime");
        });

        // 9. Group (Nhóm)
        modelBuilder.Entity<Group>(entity => {
            entity.Property(e => e.Name).HasMaxLength(100);
            entity.Property(e => e.InviteCode).HasMaxLength(20);

            // Quan hệ: 1 User tạo nhiều Group
            // ClientSetNull: Nếu User bị xóa, Group vẫn còn nhưng CreatorId sẽ bị null (tránh lỗi vòng lặp khóa ngoại)
            entity.HasOne(g => g.CreatedByUser)
                  .WithMany(u => u.CreatedGroups)
                  .HasForeignKey(g => g.CreatedByUserId)
                  .OnDelete(DeleteBehavior.ClientSetNull);
        });

        // 10. Audit Log
        modelBuilder.Entity<SystemAuditLog>(entity => {
            entity.Property(e => e.Timestamp).HasDefaultValueSql("GETUTCDATE()");
        });
    }
}