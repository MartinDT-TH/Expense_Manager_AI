namespace MoneyManager.Domain.Enums;

// Loại ví
//public enum WalletType
//{
//    Cash,       // Tiền mặt
//    BankAccount,// Ngân hàng
//    CreditCard, // Thẻ tín dụng
//    EWallet     // Ví điện tử (Momo, ZaloPay...)
//}

// Loại danh mục (Thu/Chi)
public enum CategoryType
{
    Expense, // Chi tiêu
    Income   // Thu nhập
}

// Vai trò trong nhóm
public enum GroupRole
{
    Admin,  // Trưởng nhóm
    Member  // Thành viên
}

// Nền tảng thanh toán
public enum SubscriptionPlatform
{
    GooglePlay,
    AppStore
}

// Trạng thái gói cước
public enum SubscriptionStatus
{
    Success,    // Thành công
    Expired,    // Hết hạn
    Refunded,   // Đã hoàn tiền
    Cancelled   // Đã hủy
}

public enum CurrencyCode
{
    VND, // Việt Nam Đồng
    USD, // Đô la Mỹ
    EUR, // Euro
    JPY, // Yên Nhật
    GBP, // Bảng Anh
    AUD, // Đô la Úc
    SGD  // Đô la Singapore
    // Thêm các loại tiền khác nếu cần
}