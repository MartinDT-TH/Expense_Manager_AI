using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MoneyManager.Domain.Entities;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;

namespace MoneyManager.Infrastructure.Data
{
    public static class DbInitializer
    {
        public static async Task Initialize(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var services = scope.ServiceProvider;

            try
            {
                var context = services.GetRequiredService<MoneyManagerDbContext>();
                var userManager = services.GetRequiredService<UserManager<AppUser>>();
                var roleManager = services.GetRequiredService<RoleManager<AppRole>>();

                // 1. Chạy Migration tự động
                await context.Database.MigrateAsync();

                // Kiểm tra nếu đã có dữ liệu Category thì coi như đã seed rồi -> Return
                if (context.Categories.Any()) return;

                // ==================================================
                // 1. SEED ROLES
                // ==================================================
                var roleList = new[]
                {
                    new { Name = "Admin", Description = "Quản trị viên hệ thống, có toàn quyền" },
                    new { Name = "Member", Description = "Người dùng phổ thông, giới hạn quyền theo gói" }
                };

                foreach (var role in roleList)
                {
                    if (!await roleManager.RoleExistsAsync(role.Name))
                    {
                        await roleManager.CreateAsync(new AppRole
                        {
                            Name = role.Name,
                            Description = role.Description // Map description vào đây
                        });
                    }
                }

                // ==================================================
                // 2. SEED USERS
                // ==================================================

                // 2.1 Admin
                var adminUser = new AppUser
                {
                    UserName = "admin@money.com",
                    Email = "admin@money.com",
                    FullName = "System Administrator",
                    IsActive = true,
                    IsPremium = true,
                    CreatedAt = DateTime.UtcNow,
                    EmailConfirmed = true
                };
                if (await userManager.CreateAsync(adminUser, "Admin@123") == IdentityResult.Success)
                {
                    await userManager.AddToRoleAsync(adminUser, "Admin");
                }

                // 2.2 User Free (Chỉ dùng được 2 ví)
                var freeUser = new AppUser
                {
                    UserName = "free@money.com",
                    Email = "free@money.com",
                    FullName = "Nguyen Van Free",
                    AvatarUrl = "https://i.pravatar.cc/150?u=free",
                    IsActive = true,
                    IsPremium = false,
                    CreatedAt = DateTime.UtcNow,
                    EmailConfirmed = true
                };
                await userManager.CreateAsync(freeUser, "User@123");
                await userManager.AddToRoleAsync(freeUser, "Member");

                // 2.3 User Premium (Được tạo nhóm, scan AI)
                var premiumUser = new AppUser
                {
                    UserName = "vip@money.com",
                    Email = "vip@money.com",
                    FullName = "Tran Thi Premium",
                    AvatarUrl = "https://i.pravatar.cc/150?u=vip",
                    IsActive = true,
                    IsPremium = true,
                    PremiumExpiryDate = DateTime.UtcNow.AddYears(1),
                    CreatedAt = DateTime.UtcNow,
                    EmailConfirmed = true
                };
                await userManager.CreateAsync(premiumUser, "User@123");
                await userManager.AddToRoleAsync(premiumUser, "Member");

                // 2.4 Test User (Cho testing - CHÍNH)
                var testUser = new AppUser
                {
                    UserName = "test@test.com",
                    Email = "test@test.com",
                    FullName = "Test User",
                    AvatarUrl = "https://i.pravatar.cc/150?u=test",
                    IsActive = true,
                    IsPremium = true, // Premium để test full features
                    PremiumExpiryDate = DateTime.UtcNow.AddYears(1),
                    CreatedAt = DateTime.UtcNow,
                    EmailConfirmed = true
                };
                await userManager.CreateAsync(testUser, "Test123@");
                await userManager.AddToRoleAsync(testUser, "Member");

                // ==================================================
                // 3. SEED CATEGORIES (Danh mục hệ thống - OwnerId = null)
                // ==================================================
                var categories = new List<Category>
                {
                    // EXPENSE
                    new Category { Name = "Food & Drinks", Type = CategoryType.Expense, IconCode = "fastfood", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Transportation", Type = CategoryType.Expense, IconCode = "commute", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Shopping", Type = CategoryType.Expense, IconCode = "shopping_cart", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Entertainment", Type = CategoryType.Expense, IconCode = "movie", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Health", Type = CategoryType.Expense, IconCode = "medical_services", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Bills & Utilities", Type = CategoryType.Expense, IconCode = "receipt", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Groceries", Type = CategoryType.Expense, IconCode = "local_grocery_store", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Education", Type = CategoryType.Expense, IconCode = "school", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Rent", Type = CategoryType.Expense, IconCode = "home", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Insurance", Type = CategoryType.Expense, IconCode = "security", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Pets", Type = CategoryType.Expense, IconCode = "pets", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Gifts", Type = CategoryType.Expense, IconCode = "card_giftcard", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Travel", Type = CategoryType.Expense, IconCode = "flight", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Fitness", Type = CategoryType.Expense, IconCode = "fitness_center", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Personal Care", Type = CategoryType.Expense, IconCode = "spa", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Other Expense", Type = CategoryType.Expense, IconCode = "more_horiz", CreatedAt = DateTime.UtcNow },
                    
                    // INCOME
                    new Category { Name = "Salary", Type = CategoryType.Income, IconCode = "payments", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Bonus", Type = CategoryType.Income, IconCode = "card_giftcard", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Investment", Type = CategoryType.Income, IconCode = "trending_up", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Freelance", Type = CategoryType.Income, IconCode = "computer", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Business", Type = CategoryType.Income, IconCode = "business", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Rental Income", Type = CategoryType.Income, IconCode = "house", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Refund", Type = CategoryType.Income, IconCode = "replay", CreatedAt = DateTime.UtcNow },
                    new Category { Name = "Other Income", Type = CategoryType.Income, IconCode = "more_horiz", CreatedAt = DateTime.UtcNow }
                };
                context.Categories.AddRange(categories);
                await context.SaveChangesAsync(); // Save to get Category IDs for Transactions

                // Get category IDs for Transaction seeding
                var foodCat = categories.First(c => c.Name == "Food & Drinks");
                var salaryCat = categories.First(c => c.Name == "Salary");
                var shoppingCat = categories.First(c => c.Name == "Shopping");

                // ==================================================
                // 4. SEED WALLETS (với InitialBalance)
                // ==================================================
                // Wallet sẽ có InitialBalance (số dư ban đầu)
                // Balance sẽ được tính sau khi thêm các giao dịch:
                // Balance = InitialBalance + Sum(Income) - Sum(Expense)
                
                var wallets = new List<Wallet>
                {
                    // User Free: 2 Wallets
                    new Wallet { Name = "Cash", InitialBalance = 5000000, Balance = 5000000, Type = "CASH", OwnerId = freeUser.Id, CreatedAt = DateTime.UtcNow },
                    new Wallet { Name = "Bank Account", InitialBalance = 20000000, Balance = 20000000, Type = "BANK", OwnerId = freeUser.Id, CreatedAt = DateTime.UtcNow },

                    // User Premium: 3 Wallets
                    new Wallet { Name = "Spending Wallet", InitialBalance = 10000000, Balance = 10000000, Type = "CASH", OwnerId = premiumUser.Id, CreatedAt = DateTime.UtcNow },
                    new Wallet { Name = "Savings Bank", InitialBalance = 50000000, Balance = 50000000, Type = "BANK", OwnerId = premiumUser.Id, CreatedAt = DateTime.UtcNow },
                    new Wallet { Name = "Visa Credit", InitialBalance = 0, Balance = 0, Type = "CREDIT_CARD", OwnerId = premiumUser.Id, CreatedAt = DateTime.UtcNow },

                    // Test User: 3 Wallets
                    new Wallet { Name = "Ví tiền mặt", InitialBalance = 50000000, Balance = 50000000, Type = "CASH", OwnerId = testUser.Id, CreatedAt = DateTime.UtcNow },
                    new Wallet { Name = "Vietcombank", InitialBalance = 100000000, Balance = 100000000, Type = "BANK", OwnerId = testUser.Id, CreatedAt = DateTime.UtcNow },
                    new Wallet { Name = "MoMo", InitialBalance = 5000000, Balance = 5000000, Type = "E_WALLET", OwnerId = testUser.Id, CreatedAt = DateTime.UtcNow }
                };
                context.Wallets.AddRange(wallets);
                await context.SaveChangesAsync();

                var freeUserCashWallet = wallets.First(w => w.OwnerId == freeUser.Id && w.Type == "CASH");
                var freeUserBankWallet = wallets.First(w => w.OwnerId == freeUser.Id && w.Type == "BANK");
                var premiumUserCashWallet = wallets.First(w => w.OwnerId == premiumUser.Id && w.Type == "CASH");
                var premiumUserBankWallet = wallets.First(w => w.OwnerId == premiumUser.Id && w.Type == "BANK");
                var premiumUserCreditWallet = wallets.First(w => w.OwnerId == premiumUser.Id && w.Type == "CREDIT_CARD");
                var testUserCashWallet = wallets.First(w => w.OwnerId == testUser.Id && w.Type == "CASH");
                var testUserBankWallet = wallets.First(w => w.OwnerId == testUser.Id && w.Type == "BANK");
                var testUserEWallet = wallets.First(w => w.OwnerId == testUser.Id && w.Type == "E_WALLET");

                // ==================================================
                // 5. SEED GROUPS & MEMBERS (Quỹ nhóm)
                // ==================================================
                var familyGroup = new Group
                {
                    Name = "Gia đình hạnh phúc",
                    Description = "Quỹ chi tiêu chung",
                    InviteCode = "FAMILY88",
                    CreatedByUserId = premiumUser.Id,
                    CreatedAt = DateTime.UtcNow
                };
                context.Groups.Add(familyGroup);
                await context.SaveChangesAsync();

                var groupMembers = new List<GroupMember>
                {
                    // Premium User là Admin nhóm
                    new GroupMember { GroupId = familyGroup.Id, UserId = premiumUser.Id, Role = GroupRole.Admin, JoinedAt = DateTime.UtcNow },
                    // Free User là Member
                    new GroupMember { GroupId = familyGroup.Id, UserId = freeUser.Id, Role = GroupRole.Member, JoinedAt = DateTime.UtcNow }
                };
                context.GroupMembers.AddRange(groupMembers);

                // ==================================================
                // 6. SEED BUDGETS (Ngân sách)
                // ==================================================
                // Budget tổng cho Free User (CategoryId = null = total monthly budget)
                var freeUserBudget = new Budget
                {
                    AmountLimit = 5000000, // Giới hạn 5tr/tháng
                    StartDate = new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1),
                    EndDate = new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1).AddMonths(1).AddDays(-1),
                    CategoryId = null, // Total monthly budget
                    OwnerId = freeUser.Id,
                    IsRecurring = false,
                    CreatedAt = DateTime.UtcNow
                };
                context.Budgets.Add(freeUserBudget);

                // Budget tổng cho Test User - recurring (áp dụng mọi tháng)
                var testBudget = new Budget
                {
                    AmountLimit = 30000000, // Giới hạn 30tr/tháng
                    StartDate = new DateTime(2000, 1, 1), // Recurring marker
                    EndDate = new DateTime(9999, 12, 31), // Recurring marker
                    CategoryId = null, // Total monthly budget
                    OwnerId = testUser.Id,
                    IsRecurring = true,
                    CreatedAt = DateTime.UtcNow
                };
                context.Budgets.Add(testBudget);

                // ==================================================
                // 7. SEED TRANSACTIONS (Giao dịch)
                // Logic: Balance = InitialBalance + Sum(Income) - Sum(Expense)
                // ==================================================
                var transactions = new List<Transaction>();
                
                // Tracking balance changes cho mỗi ví
                decimal freeUserCashTotalIncome = 0, freeUserCashTotalExpense = 0;
                decimal testUserCashTotalIncome = 0, testUserCashTotalExpense = 0;
                decimal testUserBankTotalIncome = 0, testUserBankTotalExpense = 0;
                decimal testUserEWalletTotalIncome = 0, testUserEWalletTotalExpense = 0;
                decimal premiumUserBankTotalIncome = 0, premiumUserBankTotalExpense = 0;
                decimal premiumUserCreditTotalExpense = 0;

                // ========== FREE USER TRANSACTIONS ==========
                // Tổng 10 giao dịch cho Free User Cash Wallet
                var freeUserTransactions = new[]
                {
                    // Income
                    new { Amount = 8000000m, Note = "Lương tháng 1", Days = -20, IsIncome = true },
                    new { Amount = 2000000m, Note = "Thưởng Tết", Days = -15, IsIncome = true },
                    // Expenses
                    new { Amount = 1500000m, Note = "Tiền ăn tuần 1", Days = -18, IsIncome = false },
                    new { Amount = 500000m, Note = "Đổ xăng", Days = -16, IsIncome = false },
                    new { Amount = 2000000m, Note = "Mua quần áo", Days = -12, IsIncome = false },
                    new { Amount = 300000m, Note = "Café với bạn", Days = -10, IsIncome = false },
                    new { Amount = 1200000m, Note = "Tiền ăn tuần 2", Days = -8, IsIncome = false },
                    new { Amount = 200000m, Note = "Grab đi làm", Days = -5, IsIncome = false },
                    new { Amount = 800000m, Note = "Tiền điện nước", Days = -3, IsIncome = false },
                    new { Amount = 150000m, Note = "Mua sách", Days = -1, IsIncome = false },
                };

                foreach (var t in freeUserTransactions)
                {
                    if (t.IsIncome) freeUserCashTotalIncome += t.Amount;
                    else freeUserCashTotalExpense += t.Amount;

                    transactions.Add(new Transaction
                    {
                        Amount = t.Amount,
                        Note = t.Note,
                        TransactionDate = DateTime.UtcNow.AddDays(t.Days),
                        WalletId = freeUserCashWallet.Id,
                        CategoryId = t.IsIncome ? salaryCat.Id : (t.Note.Contains("ăn") ? foodCat.Id : shoppingCat.Id),
                        CreatedAt = DateTime.UtcNow.AddDays(t.Days),
                        LastUpdatedAt = DateTime.UtcNow.AddDays(t.Days)
                    });
                }

                // ========== TEST USER TRANSACTIONS ==========
                var houseCat = categories.First(c => c.Name == "Bills & Utilities");
                var transportCat = categories.First(c => c.Name == "Transportation");
                var entertainCat = categories.First(c => c.Name == "Entertainment");
                var healthCat = categories.First(c => c.Name == "Health");
                var bonusCat = categories.First(c => c.Name == "Bonus");
                var investCat = categories.First(c => c.Name == "Investment");
                var groceryCat = categories.First(c => c.Name == "Groceries");
                var eduCat = categories.First(c => c.Name == "Education");

                // Test User Cash Wallet - Expenses
                var testCashExpenses = new[]
                {
                    new { Amount = 2350000m, Note = "Đi chợ cuối tuần", Days = -1, Category = groceryCat },
                    new { Amount = 5170000m, Note = "Ăn nhà hàng sinh nhật", Days = -3, Category = foodCat },
                    new { Amount = 1880000m, Note = "Học phí tiếng Anh", Days = -4, Category = eduCat },
                    new { Amount = 6815000m, Note = "Tiền nhà tháng 1", Days = -5, Category = houseCat },
                    new { Amount = 5875000m, Note = "Bảo dưỡng xe máy", Days = -7, Category = transportCat },
                    new { Amount = 1410000m, Note = "Khám sức khỏe", Days = -10, Category = healthCat },
                    new { Amount = 3500000m, Note = "Mua quần áo Tết", Days = -12, Category = shoppingCat },
                    new { Amount = 850000m, Note = "Xem phim + ăn uống", Days = -14, Category = entertainCat },
                };

                foreach (var t in testCashExpenses)
                {
                    testUserCashTotalExpense += t.Amount;
                    transactions.Add(new Transaction
                    {
                        Amount = t.Amount,
                        Note = t.Note,
                        TransactionDate = DateTime.UtcNow.AddDays(t.Days),
                        WalletId = testUserCashWallet.Id,
                        CategoryId = t.Category.Id,
                        CreatedAt = DateTime.UtcNow.AddDays(t.Days),
                        LastUpdatedAt = DateTime.UtcNow.AddDays(t.Days)
                    });
                }

                // Test User Bank Wallet - Income & Expenses
                var testBankTransactions = new (decimal Amount, string Note, int Days, Category Category, bool IsIncome)[]
                {
                    // Income
                    (25000000m, "Lương tháng 1/2026", -20, salaryCat, true),
                    (12000000m, "Thu nhập cho thuê nhà", -10, investCat, true),
                    (8000000m, "Thu nhập kinh doanh online", -12, salaryCat, true),
                    (2600000m, "Eric trả nợ", -14, bonusCat, true),
                    (5000000m, "Thưởng KPI Q4", -8, bonusCat, true),
                    // Expenses
                    (15000000m, "Chuyển tiền mua vàng", -6, investCat, false),
                    (3000000m, "Thanh toán VISA", -4, shoppingCat, false),
                    (2500000m, "Chuyển tiền cho ba mẹ", -2, shoppingCat, false),
                };

                foreach (var t in testBankTransactions)
                {
                    if (t.IsIncome) testUserBankTotalIncome += t.Amount;
                    else testUserBankTotalExpense += t.Amount;

                    transactions.Add(new Transaction
                    {
                        Amount = t.Amount,
                        Note = t.Note,
                        TransactionDate = DateTime.UtcNow.AddDays(t.Days),
                        WalletId = testUserBankWallet.Id,
                        CategoryId = t.Category.Id,
                        CreatedAt = DateTime.UtcNow.AddDays(t.Days),
                        LastUpdatedAt = DateTime.UtcNow.AddDays(t.Days)
                    });
                }

                // Test User E-Wallet (MoMo) Transactions
                var testEWalletTransactions = new (decimal Amount, string Note, int Days, Category Category, bool IsIncome)[]
                {
                    (2000000m, "Nạp tiền từ Bank", -15, salaryCat, true),
                    (500000m, "Hoàn tiền mua hàng", -5, bonusCat, true),
                    (350000m, "Grab Food", -1, foodCat, false),
                    (200000m, "Grab đi làm", -2, transportCat, false),
                    (150000m, "Thanh toán Shopee", -3, shoppingCat, false),
                    (800000m, "Nạp game", -7, entertainCat, false),
                    (500000m, "Thanh toán điện", -10, houseCat, false),
                };

                foreach (var t in testEWalletTransactions)
                {
                    if (t.IsIncome) testUserEWalletTotalIncome += t.Amount;
                    else testUserEWalletTotalExpense += t.Amount;

                    transactions.Add(new Transaction
                    {
                        Amount = t.Amount,
                        Note = t.Note,
                        TransactionDate = DateTime.UtcNow.AddDays(t.Days),
                        WalletId = testUserEWallet.Id,
                        CategoryId = t.Category.Id,
                        CreatedAt = DateTime.UtcNow.AddDays(t.Days),
                        LastUpdatedAt = DateTime.UtcNow.AddDays(t.Days)
                    });
                }

                // ========== PREMIUM USER TRANSACTIONS ==========
                // Premium User Bank - một vài giao dịch
                transactions.Add(new Transaction
                {
                    Amount = 15000000,
                    Note = "Lương tháng 1",
                    TransactionDate = DateTime.UtcNow.AddDays(-18),
                    WalletId = premiumUserBankWallet.Id,
                    CategoryId = salaryCat.Id,
                    CreatedAt = DateTime.UtcNow.AddDays(-18),
                    LastUpdatedAt = DateTime.UtcNow.AddDays(-18)
                });
                premiumUserBankTotalIncome += 15000000;

                // Premium User Credit Card - chi tiêu nhóm
                transactions.Add(new Transaction
                {
                    Amount = 1500000,
                    Note = "Ăn nhà hàng cuối tuần (Quỹ nhóm)",
                    TransactionDate = DateTime.UtcNow.AddDays(-2),
                    WalletId = premiumUserCreditWallet.Id,
                    CategoryId = foodCat.Id,
                    GroupId = familyGroup.Id,
                    CreatedAt = DateTime.UtcNow.AddDays(-2),
                    LastUpdatedAt = DateTime.UtcNow.AddDays(-2)
                });
                premiumUserCreditTotalExpense += 1500000;

                context.Transactions.AddRange(transactions);
                await context.SaveChangesAsync();

                // ==================================================
                // 8. UPDATE WALLET BALANCES (Balance = InitialBalance + Income - Expense)
                // ==================================================
                freeUserCashWallet.Balance = freeUserCashWallet.InitialBalance + freeUserCashTotalIncome - freeUserCashTotalExpense;
                // Free Bank: không có giao dịch -> giữ nguyên
                
                testUserCashWallet.Balance = testUserCashWallet.InitialBalance + testUserCashTotalIncome - testUserCashTotalExpense;
                testUserBankWallet.Balance = testUserBankWallet.InitialBalance + testUserBankTotalIncome - testUserBankTotalExpense;
                testUserEWallet.Balance = testUserEWallet.InitialBalance + testUserEWalletTotalIncome - testUserEWalletTotalExpense;
                
                premiumUserBankWallet.Balance = premiumUserBankWallet.InitialBalance + premiumUserBankTotalIncome - premiumUserBankTotalExpense;
                premiumUserCreditWallet.Balance = premiumUserCreditWallet.InitialBalance - premiumUserCreditTotalExpense; // Credit card: chi tiêu = nợ
                
                await context.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Lỗi Seed Data: {ex.Message}");
                throw;
            }
        }
    }
}