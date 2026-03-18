import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/ads/ad_banner_widget.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../budget/presentation/bloc/budget_event.dart';
import '../../../budget/presentation/bloc/budget_state.dart';
import '../../../budget/presentation/screens/budget_screen.dart';
import '../../../category/presentation/bloc/category_bloc.dart';
import '../../../category/presentation/screens/categories_screen.dart';
import '../../../settings/presentation/screens/theme_settings_screen.dart';
import '../../../transaction/presentation/bloc/transaction_bloc.dart';
import '../../../transaction/presentation/bloc/transaction_event.dart';
import '../../../transaction/presentation/bloc/transaction_state.dart';
import '../../../transaction/data/models/transaction_model.dart';
import '../../../transaction/domain/entities/transaction.dart';
import '../../../transaction/presentation/widgets/add_transaction_options_sheet.dart';
import '../../../transaction/presentation/screens/transactions_screen.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../wallet/presentation/screens/wallets_screen_v2.dart';
import '../../../group/presentation/bloc/group_bloc.dart';
import '../../../group/presentation/screens/group_list_screen.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../../../profile/presentation/bloc/profile_event.dart';
import '../../../profile/presentation/bloc/profile_state.dart';
import '../../../profile/presentation/screens/profile_edit_screen.dart';
import '../../../reports/presentation/screens/statistics_screen.dart';
import '../widgets/home_header.dart';
import '../widgets/monthly_budget_card.dart';
import '../widgets/top_expenses_section.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/account_wallets_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Use BlocBuilder to get userId and use as key for fresh data on account switch
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final userId = authState is Authenticated ? authState.user.id : '';

        return BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is Authenticated &&
              (previous is! Authenticated ||
                  (previous as Authenticated).user.id !=
                      (current as Authenticated).user.id),
          listener: (context, state) {
            if (state is Authenticated) {
              context.read<ProfileBloc>().add(LoadProfile());
            }
          },
          child: MultiBlocProvider(
            // Key ensures new Blocs are created when user changes
            key: ValueKey(userId),
            providers: [
              BlocProvider(
                create: (_) => sl<WalletBloc>()..add(WalletsLoadRequested()),
              ),
              BlocProvider(
                create: (_) => sl<TransactionBloc>()
                  ..add(TransactionsLoadRequested(
                      filter: TransactionFilter(pageSize: 100))),
              ),
              BlocProvider(
                create: (_) =>
                    sl<BudgetBloc>()..add(const BudgetsLoadRequested()),
              ),
            ],
            child: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Scaffold(
                  backgroundColor: isDark
                      ? const Color(0xFF121212)
                      : const Color(0xFFF8F9FE),
                  body: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _DashboardTab(userId: userId),
                      const TransactionsScreen(),
                      const SizedBox(), // Placeholder for FAB
                      const _StatisticsTab(),
                      const _ProfileTab(),
                    ],
                  ),
                  bottomNavigationBar: CustomBottomNav(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      if (index != 2) {
                        setState(() => _currentIndex = index);
                      }
                    },
                    onFabPressed: () {
                      AddTransactionOptionsSheet.show(context);
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final String userId;

  const _DashboardTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFF8F9FE),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header with wave background - get real data from WalletBloc
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                String name = 'Người dùng';
                name = 'Người dùng';
                String? avatarUrl;
                if (authState is Authenticated) {
                  name = authState.user.fullName;
                  avatarUrl = authState.user.avatarUrl;
                }

                return BlocBuilder<WalletBloc, WalletState>(
                  builder: (context, walletState) {
                    double totalBalance = 0;
                    if (walletState is WalletLoaded) {
                      totalBalance = walletState.wallets.fold(
                        0.0,
                        (sum, wallet) => sum + wallet.balance,
                      );
                    }

                return HomeHeader(
                  userName: name,
                  totalBalance: totalBalance,
                  currency: 'VND',
                  avatarUrl: avatarUrl,
                );
              },
            );
          },
        ),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                final isPremium =
                    authState is Authenticated && authState.user.isPremium;
                if (isPremium) {
                  return const SizedBox.shrink();
                }
                return const Center(child: AdBannerWidget());
              },
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Monthly Summary Section - from real transaction data
                  BlocBuilder<TransactionBloc, TransactionState>(
                    builder: (context, txState) {
                      double totalExpense = 0;
                      double totalIncome = 0;

                      if (txState is TransactionLoaded) {
                        final now = DateTime.now();
                        final startOfMonth = DateTime(now.year, now.month, 1);

                        for (var tx in txState.transactions) {
                          if (tx.transactionDate.isAfter(startOfMonth) ||
                              tx.transactionDate
                                  .isAtSameMomentAs(startOfMonth)) {
                            if (tx.type == TransactionType.expense) {
                              totalExpense += tx.amount.abs();
                            } else {
                              totalIncome += tx.amount.abs();
                            }
                          }
                        }
                      }

                      final daysInMonth = DateTime(
                              DateTime.now().year, DateTime.now().month + 1, 0)
                          .day;
                      final daysLeft = daysInMonth - DateTime.now().day;

                      // Use real budget from BudgetBloc
                      return BlocBuilder<BudgetBloc, BudgetState>(
                        builder: (context, budgetState) {
                          double? budgetLimit;
                          double currentSpent = totalExpense;
                          bool hasBudget = false;

                          if (budgetState is BudgetLoaded &&
                              budgetState.currentMonthBudget != null) {
                            final budget = budgetState.currentMonthBudget!;
                            budgetLimit = budget.amountLimit;
                            currentSpent = budget
                                .amountSpent; // Use spent from API (actual calculation)
                            hasBudget = true;
                          }

                          // Calculate daily budget based on real budget or fallback
                          final effectiveBudget = budgetLimit ??
                              (totalIncome > 0
                                  ? totalIncome
                                  : totalExpense * 1.2);
                          final remainingBudget =
                              effectiveBudget - currentSpent;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tổng quan tháng',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF2D3436),
                                ),
                              ),
                              const SizedBox(height: 12),
                              MonthlyBudgetCard(
                                monthName: _getMonthName(DateTime.now().month),
                                currentSpent: currentSpent,
                                budgetLimit: effectiveBudget,
                                dailyBudgetMin: daysLeft > 0
                                    ? remainingBudget / daysLeft
                                    : 0,
                                dailyBudgetMax: daysLeft > 0
                                    ? effectiveBudget / daysLeft
                                    : 0,
                                daysLeft: daysLeft,
                                hasBudget: hasBudget,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const BudgetScreen(),
                                    ),
                                  );
                                  // Reload budget data after returning from BudgetScreen
                                  if (context.mounted) {
                                    context
                                        .read<BudgetBloc>()
                                        .add(const BudgetsLoadRequested());
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Top Expenses Section - from real data
                  BlocBuilder<TransactionBloc, TransactionState>(
                    builder: (context, state) {
                      if (state is TransactionLoaded &&
                          state.transactions.isNotEmpty) {
                        // Group expenses by category
                        final expensesByCategory = <String, _CategoryExpense>{};
                        double totalExpense = 0;

                        final now = DateTime.now();
                        final startOfMonth = DateTime(now.year, now.month, 1);

                        for (var tx in state.transactions) {
                          if (tx.type == TransactionType.expense &&
                              (tx.transactionDate.isAfter(startOfMonth) ||
                                  tx.transactionDate
                                      .isAtSameMomentAs(startOfMonth))) {
                            final categoryName = tx.categoryName ?? 'Khác';
                            final amount = tx.amount.abs();
                            totalExpense += amount;

                            if (expensesByCategory.containsKey(categoryName)) {
                              expensesByCategory[categoryName]!.amount +=
                                  amount;
                            } else {
                              expensesByCategory[categoryName] =
                                  _CategoryExpense(
                                name: categoryName,
                                amount: amount,
                                iconCode: tx.categoryIcon ?? 'category',
                              );
                            }
                          }
                        }

                        if (expensesByCategory.isEmpty) {
                          return _buildEmptyExpenses();
                        }

                        // Sort by amount and take top 3
                        final sortedExpenses = expensesByCategory.values
                            .toList()
                          ..sort((a, b) => b.amount.compareTo(a.amount));

                        final topExpenses = sortedExpenses.take(3).map((e) {
                          final percentage = totalExpense > 0
                              ? (e.amount / totalExpense * 100).round()
                              : 0;
                          return TopExpenseItem(
                            category: e.name,
                            percentage: percentage,
                            amount: -e.amount,
                            icon: CategoryIcons.getIcon(e.iconCode),
                            color: _getCategoryColor(e.name),
                          );
                        }).toList();

                        return TopExpensesSection(expenses: topExpenses);
                      }

                      return _buildEmptyExpenses();
                    },
                  ),

                  const SizedBox(height: 24),

                  // My Accounts Section
                  const AccountWalletsSection(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyExpenses() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Chưa có chi tiêu trong tháng này',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12'
    ];
    return months[month - 1];
  }

  Color _getCategoryColor(String category) {
    final colors = [
      const Color(0xFFFFB74D),
      const Color(0xFF4FC3F7),
      const Color(0xFFE57373),
      const Color(0xFF81C784),
      const Color(0xFFBA68C8),
      const Color(0xFF4DB6AC),
    ];
    return colors[category.hashCode.abs() % colors.length];
  }
}

class _CategoryExpense {
  final String name;
  double amount;
  final String iconCode;

  _CategoryExpense({
    required this.name,
    required this.amount,
    required this.iconCode,
  });
}

class _StatisticsTab extends StatelessWidget {
  const _StatisticsTab();

  @override
  Widget build(BuildContext context) {
    return const StatisticsScreen();
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 0,
        title: const Text(
          'Hồ sơ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Card
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              String name = 'Người dùng';
              name = 'Người dùng';
              String email = '';
              String? avatarUrl;
              if (state is Authenticated) {
                name = state.user.fullName;
                email = state.user.email;
                avatarUrl = state.user.avatarUrl;
              }
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileEditScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade300,
                                Colors.purple.shade600,
                              ],
                            ),
                            image: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (avatarUrl == null || avatarUrl!.trim().isEmpty)
                              ? Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'N',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3436),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Color(0xFF636E72),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Settings Items
          _buildSettingsItem(
            context: context,
            icon: Icons.account_balance_wallet,
            title: 'Quản lý ví',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WalletsScreenV2(),
                ),
              ).then((_) {
                // Refresh wallet data when returning
                if (context.mounted) {
                  context.read<WalletBloc>().add(WalletsLoadRequested());
                }
              });
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.category,
            title: 'Danh mục',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider(
                    create: (context) => sl<CategoryBloc>(),
                    child: const CategoriesScreen(),
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.savings,
            title: 'Ngân sách',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BudgetScreen(),
                ),
              );
              // Reload budget data after returning from BudgetScreen
              if (context.mounted) {
                context.read<BudgetBloc>().add(const BudgetsLoadRequested());
              }
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.groups_rounded,
            title: 'Quỹ nhóm',
            subtitle: 'Quản lý chi tiêu chung',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider(
                    create: (context) => sl<GroupBloc>(),
                    child: const GroupListScreen(),
                  ),
                ),
              );
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.notifications,
            title: 'Thông báo',
            onTap: () {},
          ),
          ListenableBuilder(
            listenable: sl<ThemeService>(),
            builder: (context, child) {
              return _buildSettingsItem(
                context: context,
                icon: Icons.palette_rounded,
                title: 'Giao diện',
                subtitle: sl<ThemeService>().themeModeString,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ThemeSettingsScreen(),
                    ),
                  );
                },
              );
            },
          ),
          _buildSettingsItem(
            context: context,
            icon: Icons.language,
            title: 'Ngôn ngữ',
            subtitle: 'Tiếng Việt',
            onTap: () {},
          ),

          const SizedBox(height: 24),

          // Logout Button
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc muốn đăng xuất?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(LogoutRequested());
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Đăng xuất',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE17055).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Color(0xFFE17055)),
                  SizedBox(width: 8),
                  Text(
                    'Đăng xuất',
                    style: TextStyle(
                      color: Color(0xFFE17055),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF6C5CE7), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF2D3436),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color:
                            isDark ? Colors.white70 : const Color(0xFF636E72),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
