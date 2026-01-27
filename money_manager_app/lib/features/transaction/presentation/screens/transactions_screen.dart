import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../wallet/domain/entities/wallet.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../domain/entities/transaction.dart';
import '../../data/models/transaction_model.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime? selectedDate;
  String? selectedWalletId;
  bool showAllExpenses = false;
  bool showAllIncomes = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<TransactionBloc>()
            ..add(TransactionsLoadRequested(filter: TransactionFilter(pageSize: 50))),
        ),
        BlocProvider(
          create: (_) => sl<WalletBloc>()..add(WalletsLoadRequested()),
        ),
      ],
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
        appBar: AppBar(
          backgroundColor: const Color(0xFF6C5CE7),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Transactions',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        if (state is TransactionLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is TransactionError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<TransactionBloc>().add(
                      TransactionsLoadRequested(filter: TransactionFilter(pageSize: 50)),
                    );
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is TransactionLoaded) {
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh both transactions and wallets
              context.read<WalletBloc>().add(WalletsLoadRequested());
              context.read<TransactionBloc>().add(
                TransactionsLoadRequested(
                  filter: TransactionFilter(
                    walletId: selectedWalletId,
                    startDate: selectedDate,
                    endDate: selectedDate,
                    pageSize: 50,
                  ),
                ),
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Section
                  _buildFilterSection(context, state),
                  const SizedBox(height: 24),

                  // Summary
                  _buildSummary(state),
                  const SizedBox(height: 24),

                  // Expenses Section
                  _buildSectionHeader(
                    'All My Expenses (${state.expenses.length})',
                    () => setState(() => showAllExpenses = !showAllExpenses),
                    showAllExpenses,
                  ),
                  const SizedBox(height: 12),
                  if (state.expenses.isEmpty)
                    _buildEmptyState('No expenses yet')
                  else
                    ..._getDisplayedTransactions(state.expenses, showAllExpenses)
                        .map((t) => _buildTransactionCard(t, isExpense: true)),

                  const SizedBox(height: 24),

                  // Income Section
                  _buildSectionHeader(
                    'All My Income (${state.incomes.length})',
                    () => setState(() => showAllIncomes = !showAllIncomes),
                    showAllIncomes,
                  ),
                  const SizedBox(height: 12),
                  if (state.incomes.isEmpty)
                    _buildEmptyState('No income yet')
                  else
                    ..._getDisplayedTransactions(state.incomes, showAllIncomes)
                        .map((t) => _buildTransactionCard(t, isExpense: false)),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        }

        return const SizedBox();
      },
    );
  }

  List<Transaction> _getDisplayedTransactions(List<Transaction> transactions, bool showAll) {
    if (showAll || transactions.length <= 3) {
      return transactions;
    }
    return transactions.take(3).toList();
  }

  Widget _buildFilterSection(BuildContext context, TransactionLoaded state) {
    return Column(
      children: [
        // Date Picker - Custom beautiful design
        GestureDetector(
          onTap: () => _showCustomDatePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedDate != null ? 'Selected Date' : 'Select Date',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedDate != null
                            ? _formatDateVN(selectedDate!)
                            : 'All Dates',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedDate != null)
                  GestureDetector(
                    onTap: () => _clearDateFilter(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  )
                else
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Wallet Filter
        BlocBuilder<WalletBloc, WalletState>(
          builder: (context, walletState) {
            List<Wallet> wallets = [];
            if (walletState is WalletLoaded) {
              wallets = walletState.wallets;
            } else if (walletState is WalletOperationSuccess) {
              wallets = walletState.wallets;
            }

            // Validate selectedWalletId - reset nếu không tồn tại trong danh sách
            final validWalletIds = wallets.map((w) => w.id).toSet();
            final currentSelectedId = selectedWalletId;
            if (currentSelectedId != null && !validWalletIds.contains(currentSelectedId)) {
              // Reset về null nếu wallet ID không hợp lệ
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => selectedWalletId = null);
                }
              });
              // Sử dụng null tạm thời cho dropdown này
              return _buildWalletDropdown(wallets, null, context);
            }

            return _buildWalletDropdown(wallets, selectedWalletId, context);
          },
        ),
      ],
    );
  }

  Widget _buildWalletDropdown(List<Wallet> wallets, String? currentWalletId, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: currentWalletId,
          hint: const Text('All Wallets'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, size: 20),
                  SizedBox(width: 8),
                  Text('All Wallets'),
                ],
              ),
            ),
            ...wallets.map((wallet) => DropdownMenuItem(
              value: wallet.id,
              child: Row(
                children: [
                  Icon(_getWalletIcon(wallet.type), size: 20),
                  const SizedBox(width: 8),
                  Text(wallet.name),
                  const Spacer(),
                  Text(
                    '${wallet.balance < 0 ? "-" : ""}${_formatCurrency(wallet.balance.abs())}',
                    style: TextStyle(
                      color: wallet.balance < 0 
                          ? const Color(0xFFE53935)
                          : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: wallet.balance < 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            )),
          ],
          onChanged: (value) {
            setState(() => selectedWalletId = value);
            _applyFilters(context);
          },
        ),
      ),
    );
  }

  Widget _buildSummary(TransactionLoaded state) {
    return Row(
      children: [
        // Income Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00B894).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('Income', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatCurrency(state.totalIncome),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Expense Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE17055).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('Expense', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatCurrency(state.totalExpense),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  void _showCustomDatePicker(BuildContext context) async {
    final now = DateTime.now();
    
    final config = CalendarDatePicker2Config(
      calendarType: CalendarDatePicker2Type.single,
      selectedDayHighlightColor: const Color(0xFF6C5CE7),
      weekdayLabelTextStyle: const TextStyle(
        color: Color(0xFF636E72),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      controlsTextStyle: const TextStyle(
        color: Color(0xFF2D3436),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      dayTextStyle: const TextStyle(
        color: Color(0xFF2D3436),
        fontWeight: FontWeight.w500,
      ),
      selectedDayTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      todayTextStyle: const TextStyle(
        color: Color(0xFF6C5CE7),
        fontWeight: FontWeight.bold,
      ),
      disabledDayTextStyle: TextStyle(
        color: Colors.grey[400],
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      currentDate: now,
      weekdayLabels: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      firstDayOfWeek: 1,
      controlsHeight: 56,
      lastMonthIcon: const Icon(Icons.chevron_left, color: Color(0xFF6C5CE7)),
      nextMonthIcon: const Icon(Icons.chevron_right, color: Color(0xFF6C5CE7)),
      dayBorderRadius: BorderRadius.circular(12),
      selectableDayPredicate: (day) => !day.isAfter(now),
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Date',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => selectedDate = null);
                        _applyFilters(context);
                      },
                      child: const Text(
                        'Clear Filter',
                        style: TextStyle(color: Color(0xFF6C5CE7)),
                      ),
                    ),
                  ],
                ),
              ),
              // Quick options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildQuickDateOption('Today', now, ctx, context, isDark),
                    const SizedBox(width: 8),
                    _buildQuickDateOption('Yesterday', now.subtract(const Duration(days: 1)), ctx, context, isDark),
                    const SizedBox(width: 8),
                    _buildQuickDateOption('This Week', now.subtract(Duration(days: now.weekday - 1)), ctx, context, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              // Calendar
              Expanded(
                child: CalendarDatePicker2(
                  config: config,
                  value: selectedDate != null ? [selectedDate!] : [],
                  onValueChanged: (dates) {
                    if (dates.isNotEmpty) {
                      final date = dates[0];
                      if (date != null) {
                        Navigator.pop(ctx);
                        setState(() => selectedDate = date);
                        _applyFilters(context);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickDateOption(String label, DateTime date, BuildContext sheetContext, BuildContext mainContext, bool isDark) {
    final isSelected = selectedDate != null && 
        selectedDate!.day == date.day && 
        selectedDate!.month == date.month && 
        selectedDate!.year == date.year;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.pop(sheetContext);
          setState(() => selectedDate = date);
          _applyFilters(mainContext);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF6C5CE7) 
                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : const Color(0xFF636E72)),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _clearDateFilter(BuildContext context) {
    setState(() => selectedDate = null);
    _applyFilters(context);
  }

  void _applyFilters(BuildContext context) {
    // Để filter theo ngày chính xác, cần:
    // startDate = đầu ngày (00:00:00)
    // endDate = cuối ngày (23:59:59) hoặc đầu ngày hôm sau
    DateTime? startDate;
    DateTime? endDate;
    
    if (selectedDate != null) {
      // Đầu ngày được chọn
      startDate = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, 0, 0, 0);
      // Cuối ngày được chọn (23:59:59)
      endDate = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, 23, 59, 59);
    }
    
    context.read<TransactionBloc>().add(
      TransactionsLoadRequested(
        filter: TransactionFilter(
          walletId: selectedWalletId,
          startDate: startDate,
          endDate: endDate,
          pageSize: 50,
        ),
      ),
    );
  }

  IconData _getWalletIcon(String type) {
    switch (type.toUpperCase()) {
      case 'CASH':
        return Icons.money;
      case 'BANK':
        return Icons.account_balance;
      case 'EWALLET':
        return Icons.phone_android;
      case 'CREDIT':
        return Icons.credit_card;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll, bool isExpanded) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436),
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isExpanded ? 'Collapse' : 'See All',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6C5CE7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction, {required bool isExpense}) {
    final iconData = _getCategoryIcon(transaction.categoryIcon ?? transaction.categoryName);
    final iconColors = _getCategoryColors(transaction.categoryName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasReceipt = transaction.receiptUrl != null && transaction.receiptUrl!.isNotEmpty;
    
    return GestureDetector(
      onTap: () => _showTransactionDetail(context, transaction, isDark),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon with receipt indicator
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: iconColors['bgColor'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColors['iconColor'], size: 24),
                ),
                // Receipt indicator badge
                if (hasReceipt)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.note ?? transaction.categoryName ?? 'Transaction',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasReceipt)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Bill',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C5CE7),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.categoryName ?? '',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatFullDate(transaction.transactionDate),
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                      ),
                      if (transaction.walletName != null) ...[
                        Text(' • ', style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400])),
                        Icon(_getWalletIcon(''), size: 12, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            transaction.walletName!,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[500]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '${isExpense ? '-' : '+'} ${_formatCurrency(transaction.amount)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isExpense ? const Color(0xFFE53935) : const Color(0xFF43A047),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? categoryIcon) {
    return CategoryIcons.getIcon(categoryIcon);
  }

  Map<String, Color> _getCategoryColors(String? categoryName) {
    if (categoryName == null) {
      return {'bgColor': const Color(0xFFE3F2FD), 'iconColor': const Color(0xFF1976D2)};
    }
    
    final name = categoryName.toLowerCase();
    
    // ===== INCOME CATEGORIES (check first for specific income types) =====
    if (name.contains('salary')) {
      return {'bgColor': const Color(0xFFE8F5E9), 'iconColor': const Color(0xFF43A047)}; // Green
    }
    if (name.contains('bonus')) {
      return {'bgColor': const Color(0xFFFFF8E1), 'iconColor': const Color(0xFFFF8F00)}; // Amber/Orange
    }
    if (name.contains('investment')) {
      return {'bgColor': const Color(0xFFE3F2FD), 'iconColor': const Color(0xFF1565C0)}; // Blue
    }
    if (name.contains('freelance')) {
      return {'bgColor': const Color(0xFFE0F7FA), 'iconColor': const Color(0xFF00ACC1)}; // Cyan
    }
    if (name.contains('business')) {
      return {'bgColor': const Color(0xFFF3E5F5), 'iconColor': const Color(0xFF7B1FA2)}; // Purple
    }
    if (name.contains('rental income')) {
      return {'bgColor': const Color(0xFFE8EAF6), 'iconColor': const Color(0xFF5C6BC0)}; // Indigo
    }
    if (name.contains('refund')) {
      return {'bgColor': const Color(0xFFFFEBEE), 'iconColor': const Color(0xFFE53935)}; // Red
    }
    if (name.contains('other income')) {
      return {'bgColor': const Color(0xFFFFF3E0), 'iconColor': const Color(0xFFFF9800)}; // Orange
    }
    if (name.contains('gift') && !name.contains('expense')) {
      return {'bgColor': const Color(0xFFFCE4EC), 'iconColor': const Color(0xFFEC407A)}; // Pink
    }
    
    // ===== EXPENSE CATEGORIES =====
    if (name.contains('food') || name.contains('restaurant') || name.contains('drinks')) {
      return {'bgColor': const Color(0xFFFFF3E0), 'iconColor': const Color(0xFFE65100)}; // Deep Orange
    }
    if (name.contains('transport') || name.contains('car') || name.contains('fuel') || name.contains('gas')) {
      return {'bgColor': const Color(0xFFE3F2FD), 'iconColor': const Color(0xFF1976D2)}; // Blue
    }
    if (name.contains('shopping')) {
      return {'bgColor': const Color(0xFFF3E5F5), 'iconColor': const Color(0xFF9C27B0)}; // Purple
    }
    if (name.contains('groceries')) {
      return {'bgColor': const Color(0xFFE8F5E9), 'iconColor': const Color(0xFF388E3C)}; // Green
    }
    if (name.contains('entertainment') || name.contains('movie') || name.contains('game')) {
      return {'bgColor': const Color(0xFFFCE4EC), 'iconColor': const Color(0xFFE91E63)}; // Pink
    }
    if (name.contains('health') || name.contains('medical')) {
      return {'bgColor': const Color(0xFFFFEBEE), 'iconColor': const Color(0xFFC62828)}; // Red
    }
    if (name.contains('fitness')) {
      return {'bgColor': const Color(0xFFE0F7FA), 'iconColor': const Color(0xFF00838F)}; // Teal
    }
    if (name.contains('bill') || name.contains('utilities')) {
      return {'bgColor': const Color(0xFFECEFF1), 'iconColor': const Color(0xFF607D8B)}; // Blue Grey
    }
    if (name.contains('rent')) {
      return {'bgColor': const Color(0xFFE0F2F1), 'iconColor': const Color(0xFF00695C)}; // Teal
    }
    if (name.contains('insurance')) {
      return {'bgColor': const Color(0xFFE8EAF6), 'iconColor': const Color(0xFF3949AB)}; // Indigo
    }
    if (name.contains('education') || name.contains('learning') || name.contains('course')) {
      return {'bgColor': const Color(0xFFE8EAF6), 'iconColor': const Color(0xFF3F51B5)}; // Indigo
    }
    if (name.contains('personal') || name.contains('care') || name.contains('beauty')) {
      return {'bgColor': const Color(0xFFFCE4EC), 'iconColor': const Color(0xFFD81B60)}; // Pink
    }
    if (name.contains('travel') || name.contains('vacation') || name.contains('trip')) {
      return {'bgColor': const Color(0xFFE0F7FA), 'iconColor': const Color(0xFF00838F)}; // Teal
    }
    if (name.contains('pets') || name.contains('pet')) {
      return {'bgColor': const Color(0xFFEFEBE9), 'iconColor': const Color(0xFF6D4C41)}; // Brown
    }
    if (name.contains('other expense')) {
      return {'bgColor': const Color(0xFFECEFF1), 'iconColor': const Color(0xFF455A64)}; // Blue Grey
    }
    
    return {'bgColor': const Color(0xFFE3F2FD), 'iconColor': const Color(0xFF1976D2)};
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateVN(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today, ${date.day}/${date.month}';
    } else if (dateOnly == yesterday) {
      return 'Yesterday, ${date.day}/${date.month}';
    }
    
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _formatFullDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatCurrency(double amount) {
    final absAmount = amount.abs();
    // Chỉ rút gọn khi >= 1 tỷ
    if (absAmount >= 1000000000) {
      return '${(absAmount / 1000000000).toStringAsFixed(1)}B ₫';
    }
    // Hiển thị đầy đủ số cho số < 1 tỷ
    return '${absAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )} ₫';
  }

  void _showTransactionDetail(BuildContext context, Transaction transaction, bool isDark) {
    final isExpense = transaction.type == TransactionType.expense;
    final hasReceipt = transaction.receiptUrl != null && transaction.receiptUrl!.isNotEmpty;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _getCategoryColors(transaction.categoryName)['bgColor'],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getCategoryIcon(transaction.categoryIcon ?? transaction.categoryName),
                      color: _getCategoryColors(transaction.categoryName)['iconColor'],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.categoryName ?? 'Transaction',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isExpense ? 'Expense' : 'Income',
                          style: TextStyle(
                            fontSize: 14,
                            color: isExpense ? const Color(0xFFE53935) : const Color(0xFF43A047),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isExpense ? '-' : '+'} ${_formatCurrency(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? const Color(0xFFE53935) : const Color(0xFF43A047),
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
            
            // Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    _buildDetailRow(
                      'Date',
                      _formatDetailDate(transaction.transactionDate),
                      Icons.calendar_today_outlined,
                      isDark,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Wallet
                    if (transaction.walletName != null)
                      _buildDetailRow(
                        'Wallet',
                        transaction.walletName!,
                        Icons.account_balance_wallet_outlined,
                        isDark,
                      ),
                    
                    // Note
                    if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Note',
                        transaction.note!,
                        Icons.note_outlined,
                        isDark,
                      ),
                    ],
                    
                    // Created by (for group transactions)
                    if (transaction.createdByUserName != null && transaction.groupId != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Created by',
                        transaction.createdByUserName!,
                        Icons.person_outline,
                        isDark,
                        valueColor: const Color(0xFF6C5CE7),
                      ),
                    ],
                    
                    // Group
                    if (transaction.groupId != null && transaction.groupName != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Group',
                        transaction.groupName!,
                        Icons.group_outlined,
                        isDark,
                        valueColor: const Color(0xFF6C5CE7),
                      ),
                    ],
                    
                    // Bill Image Section
                    if (hasReceipt) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 20,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bill / Receipt',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showFullImage(context, transaction.receiptUrl!, isDark),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  transaction.receiptUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: const Color(0xFF6C5CE7),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Unable to load image',
                                            style: TextStyle(
                                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                // Tap to view overlay
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.zoom_in,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Tap to view',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Transaction ID (for reference)
                    Text(
                      'Transaction ID: ${transaction.id.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? (isDark ? Colors.white : const Color(0xFF2D3436)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDetailDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showFullImage(BuildContext context, String imageUrl, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Image with InteractiveViewer for zoom/pan
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 300,
                      height: 400,
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFF6C5CE7),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 200,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 64,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Unable to load image',
                              style: TextStyle(
                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            // Hint text
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pinch to zoom • Drag to pan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
