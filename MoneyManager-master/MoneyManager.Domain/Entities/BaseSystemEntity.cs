using System.ComponentModel.DataAnnotations;

namespace MoneyManager.Domain.Entities
{
    // Dùng cho các bảng Log/System chỉ nằm trên Server
    public abstract class BaseSystemEntity
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}