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
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF8F5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Transactions',
            style: TextStyle(
              color: Colors.black,
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
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        if (state is TransactionLoaded) {
          return RefreshIndicator(
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
                    _buildEmptyState('Chưa có chi tiêu nào')
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
                    _buildEmptyState('Chưa có thu nhập nào')
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
        // Date Picker
        GestureDetector(
          onTap: () => _showDatePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? _formatDate(selectedDate!)
                      : 'All Dates',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    if (selectedDate != null)
                      GestureDetector(
                        onTap: () => _clearDateFilter(context),
                        child: const Icon(Icons.close, color: Colors.white70, size: 20),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  ],
                ),
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

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: selectedWalletId,
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
                            _formatCurrency(wallet.balance),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
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
        ),
      ],
    );
  }

  Widget _buildSummary(TransactionLoaded state) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('Total Income', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(state.totalIncome),
                  style: const TextStyle(
                    color: Color(0xFF43A047),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: Column(
              children: [
                const Text('Total Expense', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(state.totalExpense),
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  void _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF7C4DFF)),
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
            color: Colors.black87,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            isExpanded ? 'Show Less' : 'See All',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction, {required bool isExpense}) {
    final iconData = _getCategoryIcon(transaction.categoryIcon ?? transaction.categoryName);
    final iconColors = _getCategoryColors(transaction.categoryName);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconColors['bgColor'],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColors['iconColor'], size: 24),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.note ?? transaction.categoryName ?? 'Transaction',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.categoryName ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatFullDate(transaction.transactionDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (transaction.walletName != null) ...[
                      Text(' • ', style: TextStyle(color: Colors.grey[400])),
                      Icon(_getWalletIcon(''), size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 2),
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
    
    // Tên tiếng Việt từ Backend
    if (name.contains('ăn uống') || name.contains('food') || name.contains('restaurant')) {
      return {'bgColor': const Color(0xFFFFF3E0), 'iconColor': const Color(0xFFE65100)};
    }
    if (name.contains('di chuyển') || name.contains('transport') || name.contains('car')) {
      return {'bgColor': const Color(0xFFE8F5E9), 'iconColor': const Color(0xFF388E3C)};
    }
    if (name.contains('mua sắm') || name.contains('shopping')) {
      return {'bgColor': const Color(0xFFE3F2FD), 'iconColor': const Color(0xFF1976D2)};
    }
    if (name.contains('giải trí') || name.contains('entertainment')) {
      return {'bgColor': const Color(0xFFFCE4EC), 'iconColor': const Color(0xFFE91E63)};
    }
    if (name.contains('sức khỏe') || name.contains('health')) {
      return {'bgColor': const Color(0xFFFCE4EC), 'iconColor': const Color(0xFFC2185B)};
    }
    if (name.contains('hóa đơn') || name.contains('bill')) {
      return {'bgColor': const Color(0xFFECEFF1), 'iconColor': const Color(0xFF607D8B)};
    }
    if (name.contains('lương') || name.contains('salary') || name.contains('income')) {
      return {'bgColor': const Color(0xFFE8F5E9), 'iconColor': const Color(0xFF43A047)};
    }
    if (name.contains('thưởng') || name.contains('bonus') || name.contains('gift')) {
      return {'bgColor': const Color(0xFFFFF8E1), 'iconColor': const Color(0xFFFF8F00)};
    }
    if (name.contains('đầu tư') || name.contains('invest')) {
      return {'bgColor': const Color(0xFFE8F5E9), 'iconColor': const Color(0xFF2E7D32)};
    }
    if (name.contains('education')) {
      return {'bgColor': const Color(0xFFE8EAF6), 'iconColor': const Color(0xFF3F51B5)};
    }
    if (name.contains('house') || name.contains('housing')) {
      return {'bgColor': const Color(0xFFE0F7FA), 'iconColor': const Color(0xFF00838F)};
    }
    if (name.contains('business')) {
      return {'bgColor': const Color(0xFFF3E5F5), 'iconColor': const Color(0xFF7B1FA2)};
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
}
