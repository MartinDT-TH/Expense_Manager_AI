using System.ComponentModel.DataAnnotations;

namespace MoneyManager.Domain.Entities
{
    // Dùng cho các bảng nghiệp vụ cần Sync (Mobile <-> Server)
    public abstract class BaseSyncEntity
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid(); // Client tự gen ID này

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Cốt lõi của Sync
        public DateTime LastUpdatedAt { get; set; } = DateTime.UtcNow;
        public bool IsDeleted { get; set; } = false;
    }
}