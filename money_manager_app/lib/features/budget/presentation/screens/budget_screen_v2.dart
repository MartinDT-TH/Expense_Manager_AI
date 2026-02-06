import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../category/presentation/bloc/category_bloc.dart';
import '../../../category/presentation/bloc/category_event.dart';
import '../../../category/presentation/bloc/category_state.dart';
import '../../../category/domain/entities/category.dart';
import '../../data/models/budget_model.dart';
import '../bloc/budget_bloc.dart';
import '../bloc/budget_event.dart';
import '../bloc/budget_state.dart';
import 'budget_analytics_screen.dart';

class BudgetScreenV2 extends StatelessWidget {
  const BudgetScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<BudgetBloc>()..add(const BudgetsLoadRequested())),
        BlocProvider(create: (_) => sl<CategoryBloc>()..add(const LoadCategoriesByType(CategoryType.expense))),
      ],
      child: const _BudgetScreenContent(),
    );
  }
}

class _BudgetScreenContent extends StatefulWidget {
  const _BudgetScreenContent();

  @override
  State<_BudgetScreenContent> createState() => _BudgetScreenContentState();
}

class _BudgetScreenContentState extends State<_BudgetScreenContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  bool _isRecurring = true;
  BudgetModel? _currentBudget;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _formatNumber(num number) {
    return NumberFormat('#,###', 'vi').format(number.toInt());
  }

  String _getMonthName(int month) {
    const months = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF6C5CE7),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetAnalyticsScreen()),
                ),
                tooltip: 'Xem phân tích',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6C5CE7), Color(0xFF8E7CF3)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ngân sách ${_getMonthName(now.month)} ${now.year}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Tổng quan', icon: Icon(Icons.pie_chart_rounded, size: 20)),
                Tab(text: 'Theo danh mục', icon: Icon(Icons.category_rounded, size: 20)),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildCategoryBudgetsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return BlocConsumer<BudgetBloc, BudgetState>(
      listener: (context, state) {
        if (state is BudgetOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFF00B894),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isEditing = false);
          context.read<BudgetBloc>().add(const BudgetsLoadRequested());
        } else if (state is BudgetError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is BudgetLoaded) {
          _currentBudget = state.currentMonthBudget ?? _findTotalBudget(state.budgets);
          if (_currentBudget != null && !_isEditing) {
            _amountController.text = _formatNumber(_currentBudget!.amountLimit);
            _isRecurring = _currentBudget!.isRecurring;
          }
        }

        final isLoading = state is BudgetLoading;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Budget Input Card
              _buildBudgetInputCard(
                title: 'Tổng ngân sách tháng',
                subtitle: 'Đặt hạn mức chi tiêu tổng thể',
                isLoading: isLoading,
              ),
              
              const SizedBox(height: 24),
              
              // Current Status
              if (_currentBudget != null)
                _buildBudgetStatusCard(_currentBudget!),
              
              const SizedBox(height: 24),
              
              // Quick Stats
              if (_currentBudget != null)
                _buildQuickStats(_currentBudget!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryBudgetsTab() {
    return BlocBuilder<BudgetBloc, BudgetState>(
      builder: (context, budgetState) {
        return BlocBuilder<CategoryBloc, CategoryState>(
          builder: (context, categoryState) {
            final budgets = budgetState is BudgetLoaded ? budgetState.budgets : <BudgetModel>[];
            final categories = categoryState is CategoryLoaded 
                ? categoryState.categories.where((c) => c.type == CategoryType.expense).toList()
                : <Category>[];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add Category Budget Button
                  _buildAddCategoryBudgetButton(categories, budgets),
                  
                  const SizedBox(height: 20),
                  
                  // Category Budgets List
                  const Text(
                    'Ngân sách theo danh mục',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (budgets.where((b) => b.categoryId != null).isEmpty)
                    _buildEmptyCategoryBudgets()
                  else
                    ...budgets
                        .where((b) => b.categoryId != null)
                        .map((b) => _buildCategoryBudgetCard(b)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBudgetInputCard({
    required String title,
    required String subtitle,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF8E7CF3)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF636E72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Amount Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.2), width: 2),
            ),
            child: Row(
              children: [
                const Text(
                  '₫',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandsSeparatorFormatter(),
                    ],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C5CE7),
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 32),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) {
                      if (!_isEditing) setState(() => _isEditing = true);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Amount Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickButton(5000000, '5M'),
                _buildQuickButton(10000000, '10M'),
                _buildQuickButton(15000000, '15M'),
                _buildQuickButton(20000000, '20M'),
                _buildQuickButton(30000000, '30M'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recurring Toggle
          _buildRecurringToggle(),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _saveTotalBudget,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _currentBudget != null ? 'Cập nhật ngân sách' : 'Thiết lập ngân sách',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton(int amount, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () {
          _amountController.text = _formatNumber(amount);
          setState(() => _isEditing = true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6C5CE7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringToggle() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _isRecurring ? Icons.repeat_rounded : Icons.calendar_today_rounded,
            color: _isRecurring ? const Color(0xFF6C5CE7) : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRecurring ? 'Áp dụng cho mọi tháng' : 'Chỉ tháng này',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isRecurring ? const Color(0xFF6C5CE7) : const Color(0xFF2D3436),
                  ),
                ),
                Text(
                  _isRecurring ? 'Ngân sách mặc định hàng tháng' : 'Chỉ cho ${_getMonthName(now.month)} ${now.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: _isRecurring,
            onChanged: (value) => setState(() {
              _isRecurring = value;
              _isEditing = true;
            }),
            activeColor: const Color(0xFF6C5CE7),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStatusCard(BudgetModel budget) {
    final percentage = budget.percentUsed.clamp(0.0, 100.0);
    final isExceeded = budget.isExceeded;
    final isWarning = budget.isWarning;

    Color statusColor = isExceeded 
        ? const Color(0xFFE74C3C) 
        : isWarning 
            ? const Color(0xFFF39C12) 
            : const Color(0xFF00B894);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics_rounded, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tình trạng chi tiêu',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              _buildStatusBadge(isExceeded, isWarning, statusColor),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Bar
          _buildProgressBar(percentage, statusColor),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentage.toInt()}% used',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                'Còn lại ₫${_formatNumber(budget.amountRemaining)}',
                style: const TextStyle(color: Color(0xFF636E72), fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isExceeded, bool isWarning, Color color) {
    String text = isExceeded ? 'Vượt ngân sách!' : isWarning ? 'Gần chạm mức!' : 'Đúng kế hoạch';
    IconData icon = isExceeded 
        ? Icons.warning_amber_rounded 
        : isWarning 
            ? Icons.info_outline_rounded 
            : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double percentage, Color color) {
    return Stack(
      children: [
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          width: MediaQuery.of(context).size.width * 0.8 * (percentage / 100).clamp(0.0, 1.0),
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BudgetModel budget) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day + 1;
    final dailyBudget = budget.amountRemaining / daysRemaining;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Spent',
                  '₫${_formatNumber(budget.amountSpent)}',
                  Colors.red,
                  Icons.arrow_upward_rounded,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Ngân sách ngày',
                  '₫${_formatNumber(dailyBudget > 0 ? dailyBudget : 0)}',
                  const Color(0xFF6C5CE7),
                  Icons.today_rounded,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Days Left',
                  '$daysRemaining',
                  const Color(0xFF00B894),
                  Icons.calendar_today_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAddCategoryBudgetButton(List<Category> categories, List<BudgetModel> budgets) {
    return GestureDetector(
      onTap: () => _showAddCategoryBudgetDialog(categories, budgets),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3), width: 2, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Color(0xFF6C5CE7)),
            ),
            const SizedBox(width: 12),
            const Text(
              'Thêm ngân sách danh mục',
              style: TextStyle(
                color: Color(0xFF6C5CE7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategoryBudgets() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No category budgets yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Đặt hạn mức chi tiêu cho từng danh mục',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetCard(BudgetModel budget) {
    final percentage = budget.percentUsed.clamp(0.0, 100.0);
    final color = budget.isExceeded 
        ? const Color(0xFFE74C3C) 
        : budget.isWarning 
            ? const Color(0xFFF39C12) 
            : const Color(0xFF00B894);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(budget.categoryIcon),
                  color: const Color(0xFF6C5CE7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.categoryName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '₫${_formatNumber(budget.amountSpent)} / ₫${_formatNumber(budget.amountLimit)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Text(
                '${percentage.toInt()}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryBudgetDialog(List<Category> categories, List<BudgetModel> existingBudgets) {
    final existingCategoryIds = existingBudgets.where((b) => b.categoryId != null).map((b) => b.categoryId).toSet();
    final availableCategories = categories.where((c) => !existingCategoryIds.contains(c.id)).toList();

    if (availableCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All categories already have budgets')),
      );
      return;
    }

    final amountController = TextEditingController();
    Category? selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thêm ngân sách danh mục',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                // Category Dropdown
                DropdownButtonFormField<Category>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Select Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: availableCategories.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(_getCategoryIcon(cat.iconCode), size: 20),
                        const SizedBox(width: 8),
                        Text(cat.name),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) => setModalState(() => selectedCategory = value),
                ),
                const SizedBox(height: 16),
                
                // Amount Input
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsSeparatorFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Số tiền ngân sách',
                    prefixText: '₫ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedCategory == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a category')),
                        );
                        return;
                      }
                      final amount = double.tryParse(amountController.text.replaceAll('.', ''));
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')),
                        );
                        return;
                      }

                      context.read<BudgetBloc>().add(BudgetCreateRequested(
                        request: CreateBudgetRequest(
                          amountLimit: amount,
                          categoryId: selectedCategory!.id,
                          isRecurring: true,
                        ),
                      ));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Thêm ngân sách',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? iconCode) {
    const iconMap = {
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'shopping_cart': Icons.shopping_cart,
      'movie': Icons.movie,
      'medical_services': Icons.medical_services,
      'school': Icons.school,
      'receipt': Icons.receipt,
      'local_grocery_store': Icons.local_grocery_store,
      'home': Icons.home,
      'security': Icons.security,
      'pets': Icons.pets,
      'card_giftcard': Icons.card_giftcard,
      'flight': Icons.flight,
      'fitness_center': Icons.fitness_center,
      'spa': Icons.spa,
      'more_horiz': Icons.more_horiz,
    };
    return iconMap[iconCode] ?? Icons.category;
  }

  BudgetModel? _findTotalBudget(List<BudgetModel> budgets) {
    return budgets.where((b) => b.categoryId == null).firstOrNull;
  }

  void _saveTotalBudget() {
    final amountText = _amountController.text.replaceAll('.', '').trim();
    if (amountText.isEmpty || amountText == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a budget amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return;
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    if (_currentBudget != null) {
      context.read<BudgetBloc>().add(BudgetUpdateRequested(
        id: _currentBudget!.id,
        request: UpdateBudgetRequest(amountLimit: amount, isRecurring: _isRecurring),
      ));
    } else {
      context.read<BudgetBloc>().add(BudgetCreateRequested(
        request: CreateBudgetRequest(
          amountLimit: amount,
          categoryId: null,
          startDate: _isRecurring ? null : startOfMonth,
          endDate: _isRecurring ? null : endOfMonth,
          isRecurring: _isRecurring,
        ),
      ));
    }
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final number = int.tryParse(newValue.text.replaceAll('.', ''));
    if (number == null) return oldValue;
    final formatted = NumberFormat('#,###', 'vi').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
