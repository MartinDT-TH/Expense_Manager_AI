import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  String? _selectedType; // 'all', 'expense', 'income'

  @override
  Widget build(BuildContext context) {
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
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
            body: SafeArea(
              child: _buildBody(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        if (state is TransactionLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6C5CE7),
            ),
          );
        }

        if (state is TransactionError) {
          return _buildErrorState(context, state.message);
        }

        if (state is TransactionLoaded) {
          return RefreshIndicator(
            color: const Color(0xFF6C5CE7),
            onRefresh: () async {
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
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),
                
                // Summary Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _buildSummaryCards(state),
                  ),
                ),

                // Filter Chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _buildFilterChips(context),
                  ),
                ),

                // Wallet Filter
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _buildWalletFilter(context),
                  ),
                ),

                // Transactions List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: _buildTransactionsList(state),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Top bar
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                ),
              ),
              const Expanded(
                child: Text(
                  'Transactions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showDatePicker(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                      if (selectedDate != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _clearDateFilter(context),
                          child: const Icon(Icons.close, color: Colors.white70, size: 16),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Date display
          if (selectedDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDate(selectedDate!),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards(TransactionLoaded state) {
    final balance = state.totalIncome - state.totalExpense;
    
    return Row(
      children: [
        // Income Card
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.arrow_downward_rounded,
            label: 'Income',
            amount: state.totalIncome,
            gradientColors: const [Color(0xFF00B894), Color(0xFF55EFC4)],
            iconBgColor: const Color(0xFF00B894),
          ),
        ),
        const SizedBox(width: 12),
        // Expense Card
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.arrow_upward_rounded,
            label: 'Expense',
            amount: state.totalExpense,
            gradientColors: const [Color(0xFFE17055), Color(0xFFFAB1A0)],
            iconBgColor: const Color(0xFFE17055),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required double amount,
    required List<Color> gradientColors,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Row(
      children: [
        _buildFilterChip(
          label: 'All',
          isSelected: _selectedType == null || _selectedType == 'all',
          onTap: () {
            setState(() => _selectedType = 'all');
          },
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          label: 'Expense',
          isSelected: _selectedType == 'expense',
          onTap: () {
            setState(() => _selectedType = 'expense');
          },
          color: const Color(0xFFE17055),
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          label: 'Income',
          isSelected: _selectedType == 'income',
          onTap: () {
            setState(() => _selectedType = 'income');
          },
          color: const Color(0xFF00B894),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeColor = color ?? const Color(0xFF6C5CE7);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildWalletFilter(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, walletState) {
        List<Wallet> wallets = [];
        if (walletState is WalletLoaded) {
          wallets = walletState.wallets;
        } else if (walletState is WalletOperationSuccess) {
          wallets = walletState.wallets;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: selectedWalletId,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6C5CE7)),
              hint: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet, size: 18, color: Color(0xFF6C5CE7)),
                  ),
                  const SizedBox(width: 12),
                  const Text('All wallets', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3436), fontSize: 15)),
                ],
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_wallet, size: 18, color: Color(0xFF6C5CE7)),
                      ),
                      const SizedBox(width: 12),
                      const Text('All wallets', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3436), fontSize: 15)),
                    ],
                  ),
                ),
                ...wallets.map((wallet) => DropdownMenuItem(
                  value: wallet.id,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getWalletColor(wallet.type).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getWalletIcon(wallet.type), size: 18, color: _getWalletColor(wallet.type)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(wallet.name)),
                      Text(
                        _formatCurrency(wallet.balance),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
      },
    );
  }

  Widget _buildTransactionsList(TransactionLoaded state) {
    List<Transaction> transactions = [];
    
    if (_selectedType == 'expense') {
      transactions = state.expenses;
    } else if (_selectedType == 'income') {
      transactions = state.incomes;
    } else {
      transactions = [...state.expenses, ...state.incomes]
        ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    }

    if (transactions.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final transaction = transactions[index];
          final isExpense = state.expenses.contains(transaction);
          return _buildTransactionCard(transaction, isExpense: isExpense);
        },
        childCount: transactions.length,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first transaction',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction, {required bool isExpense}) {
    final iconData = _getCategoryIcon(transaction.categoryIcon ?? transaction.categoryName);
    final iconColors = _getCategoryColors(transaction.categoryName, isExpense);
    
    return Dismissible(
      key: Key(transaction.id ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        // TODO: Implement delete confirmation
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    iconColors['bgColor']!,
                    iconColors['bgColor']!.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(iconData, color: iconColors['iconColor'], size: 26),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.categoryName ?? 'Transaction',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        _formatFullDate(transaction.transactionDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      if (transaction.walletName != null) ...[
                        Text(' • ', style: TextStyle(color: Colors.grey[400])),
                        Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            transaction.walletName!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isExpense 
                    ? const Color(0xFFE17055).withValues(alpha: 0.1)
                    : const Color(0xFF00B894).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${isExpense ? '-' : '+'} ${_formatCurrency(transaction.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? const Color(0xFFE17055) : const Color(0xFF00B894),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                context.read<TransactionBloc>().add(
                  TransactionsLoadRequested(filter: TransactionFilter(pageSize: 50)),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark 
              ? const ColorScheme.dark(
                  primary: Color(0xFF6C5CE7),
                  onPrimary: Colors.white,
                  surface: Color(0xFF1E1E1E),
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: Color(0xFF6C5CE7),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
            dialogBackgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _applyFilters(context);
    }
  }

  void _clearDateFilter(BuildContext context) {
    setState(() => selectedDate = null);
    _applyFilters(context);
  }

  void _applyFilters(BuildContext context) {
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
  }

  IconData _getWalletIcon(String type) {
    switch (type.toUpperCase()) {
      case 'CASH':
        return Icons.payments_outlined;
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

  Color _getWalletColor(String type) {
    switch (type.toUpperCase()) {
      case 'CASH':
        return const Color(0xFF00B894);
      case 'BANK':
        return const Color(0xFF0984E3);
      case 'EWALLET':
        return const Color(0xFFFDAA5B);
      case 'CREDIT':
        return const Color(0xFFE17055);
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  IconData _getCategoryIcon(String? categoryIcon) {
    return CategoryIcons.getIcon(categoryIcon);
  }

  Map<String, Color> _getCategoryColors(String? categoryName, bool isExpense) {
    if (categoryName == null) {
      return isExpense 
          ? {'bgColor': const Color(0xFFFFE8E5), 'iconColor': const Color(0xFFE17055)}
          : {'bgColor': const Color(0xFFE5FFF4), 'iconColor': const Color(0xFF00B894)};
    }
    
    final name = categoryName.toLowerCase();
    
    // Expense categories
    if (name.contains('food') || name.contains('drinks') || name.contains('restaurant')) {
      return {'bgColor': const Color(0xFFFFF3E0), 'iconColor': const Color(0xFFE65100)};
    }
    if (name.contains('transport') || name.contains('car') || name.contains('commute')) {
      return {'bgColor': const Color(0xFFE3F2FD), 'iconColor': const Color(0xFF1565C0)};
    }
    if (name.contains('shopping') || name.contains('store')) {
      return {'bgColor': const Color(0xFFFCE4EC), 'iconColor': const Color(0xFFD81B60)};
    }
    if (name.contains('entertainment') || name.contains('movie') || name.contains('game')) {
      return {'bgColor': const Color(0xFFF3E5F5), 'iconColor': const Color(0xFF8E24AA)};
    }
    if (name.contains('health') || name.contains('medical') || name.contains('doctor')) {
      return {'bgColor': const Color(0xFFFFEBEE), 'iconColor': const Color(0xFFE53935)};
    }
    if (name.contains('bill') || name.contains('utilit') || name.contains('electric')) {
      return {'bgColor': const Color(0xFFECEFF1), 'iconColor': const Color(0xFF546E7A)};
    }
    if (name.contains('groceries') || name.contains('grocery')) {
      return {'bgColor': const Color(0xFFF1F8E9), 'iconColor': const Color(0xFF558B2F)};
    }
    if (name.contains('education') || name.contains('school') || name.contains('course')) {
      return {'bgColor': const Color(0xFFE8EAF6), 'iconColor': const Color(0xFF3949AB)};
    }
    if (name.contains('rent') || name.contains('home') || name.contains('house')) {
      return {'bgColor': const Color(0xFFE0F2F1), 'iconColor': const Color(0xFF00695C)};
    }
    if (name.contains('travel') || name.contains('flight') || name.contains('vacation')) {
      return {'bgColor': const Color(0xFFE1F5FE), 'iconColor': const Color(0xFF0277BD)};
    }
    if (name.contains('fitness') || name.contains('gym') || name.contains('sport')) {
      return {'bgColor': const Color(0xFFFBE9E7), 'iconColor': const Color(0xFFE64A19)};
    }
    if (name.contains('personal') || name.contains('spa') || name.contains('beauty')) {
      return {'bgColor': const Color(0xFFFFF3E0), 'iconColor': const Color(0xFFFF6F00)};
    }
    if (name.contains('pet') || name.contains('animal')) {
      return {'bgColor': const Color(0xFFFFF8E1), 'iconColor': const Color(0xFFF57C00)};
    }
    if (name.contains('insurance')) {
      return {'bgColor': const Color(0xFFE8F5E9), 'iconColor': const Color(0xFF2E7D32)};
    }
    if (name.contains('gift')) {
      return {'bgColor': const Color(0xFFFCE4EC), 'iconColor': const Color(0xFFC2185B)};
    }
    
    // Income categories
    if (name.contains('salary') || name.contains('wage')) {
      return {'bgColor': const Color(0xFFE8F5E9), 'iconColor': const Color(0xFF43A047)};
    }
    if (name.contains('bonus') || name.contains('award')) {
      return {'bgColor': const Color(0xFFFFF8E1), 'iconColor': const Color(0xFFFF8F00)};
    }
    if (name.contains('invest') || name.contains('dividend') || name.contains('stock')) {
      return {'bgColor': const Color(0xFFE0F7FA), 'iconColor': const Color(0xFF00838F)};
    }
    if (name.contains('freelance') || name.contains('gig') || name.contains('contract')) {
      return {'bgColor': const Color(0xFFE8EAF6), 'iconColor': const Color(0xFF5C6BC0)};
    }
    if (name.contains('business') || name.contains('profit')) {
      return {'bgColor': const Color(0xFFEDE7F6), 'iconColor': const Color(0xFF7B1FA2)};
    }
    if (name.contains('rental') || name.contains('lease')) {
      return {'bgColor': const Color(0xFFE0F2F1), 'iconColor': const Color(0xFF00897B)};
    }
    if (name.contains('refund') || name.contains('cashback')) {
      return {'bgColor': const Color(0xFFE3F2FD), 'iconColor': const Color(0xFF1976D2)};
    }
    
    // Default based on type
    return isExpense 
        ? {'bgColor': const Color(0xFFFFE8E5), 'iconColor': const Color(0xFFE17055)}
        : {'bgColor': const Color(0xFFE5FFF4), 'iconColor': const Color(0xFF00B894)};
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatFullDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    }
    
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
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
}
