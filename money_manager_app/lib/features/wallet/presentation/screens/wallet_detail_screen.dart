import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/extensions.dart';
import '../../../transaction/presentation/bloc/transaction_bloc.dart';
import '../../../transaction/presentation/bloc/transaction_event.dart';
import '../../../transaction/presentation/bloc/transaction_state.dart';
import '../../../transaction/data/models/transaction_model.dart';
import '../../../transaction/domain/entities/transaction.dart';
import '../../domain/entities/wallet.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../widgets/add_wallet_bottom_sheet.dart';

class WalletDetailScreen extends StatefulWidget {
  final Wallet wallet;

  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  late Wallet _currentWallet;

  @override
  void initState() {
    super.initState();
    _currentWallet = widget.wallet;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<TransactionBloc>()
            ..add(TransactionsLoadRequested(
              filter: TransactionFilter(walletId: widget.wallet.id, pageSize: 50),
            )),
        ),
        BlocProvider(
          create: (_) => sl<WalletBloc>()..add(WalletsLoadRequested()),
        ),
      ],
      child: BlocListener<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletLoaded) {
            // Kiểm tra xem wallet còn tồn tại không (có thể đã bị xóa)
            final walletExists = state.wallets.any((w) => w.id == widget.wallet.id);
            if (!walletExists) {
              // Wallet đã bị xóa, pop ra màn trước
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ví đã bị xóa')),
              );
              return;
            }
            final updatedWallet = state.wallets.firstWhere(
              (w) => w.id == widget.wallet.id,
            );
            setState(() => _currentWallet = updatedWallet);
          } else if (state is WalletOperationSuccess) {
            // Kiểm tra xem wallet còn tồn tại không (có thể đã bị xóa)
            final walletExists = state.wallets.any((w) => w.id == widget.wallet.id);
            if (!walletExists) {
              // Wallet đã bị xóa, pop ra màn trước
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
              return;
            }
            final updatedWallet = state.wallets.firstWhere(
              (w) => w.id == widget.wallet.id,
            );
            setState(() => _currentWallet = updatedWallet);
          }
        },
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
          body: CustomScrollView(
            slivers: [
              // Custom App Bar with Wallet Card
              SliverToBoxAdapter(
                child: _buildHeader(context, isDark),
              ),
              
              // Stats Cards
              SliverToBoxAdapter(
                child: _buildStatsSection(context, isDark),
              ),
              
              // Recent Transactions Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Giao dịch gần đây',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF2D3436),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to all transactions
                        },
                        child: const Text(
                          'Xem tất cả',
                          style: TextStyle(
                            color: Color(0xFF6C5CE7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Transactions List
              BlocBuilder<TransactionBloc, TransactionState>(
                builder: (context, state) {
                  if (state is TransactionLoading) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  
                  if (state is TransactionLoaded) {
                    final transactions = state.transactions.take(10).toList();
                    
                    if (transactions.isEmpty) {
                      return SliverFillRemaining(
                        child: _buildEmptyTransactions(isDark),
                      );
                    }
                    
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final transaction = transactions[index];
                          return _buildTransactionItem(transaction, isDark);
                        },
                        childCount: transactions.length,
                      ),
                    );
                  }
                  
                  return SliverFillRemaining(
                    child: _buildEmptyTransactions(isDark),
                  );
                },
              ),
              
              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getWalletGradient(),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Tài khoản',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showWalletOptions(context),
                  ),
                ],
              ),
            ),
            
            // Wallet Card
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: _buildMainWalletCard(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainWalletCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getWalletCardColor(),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Balance Label
          Text(
            'Số dư hiện tại',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _getWalletTextColor().withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          // Balance
          Text(
            _currentWallet.balance.toCurrency(_currentWallet.currency),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _getWalletTextColor(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentWallet.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _getWalletTextColor().withOpacity(0.8),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Divider
          Container(
            height: 1,
            color: _getWalletTextColor().withOpacity(0.1),
          ),
          
          const SizedBox(height: 16),
          
          // Initial Balance & Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Initial Balance (subtle display)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Số dư ban đầu',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _getWalletTextColor().withOpacity(0.5),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentWallet.initialBalance.toCurrency(_currentWallet.currency),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _getWalletTextColor().withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              // Card info / Logo
              Row(
                children: [
                  if (_currentWallet.type.toUpperCase() == 'BANK' ||
                      _currentWallet.type.toUpperCase() == 'CREDIT_CARD')
                    Text(
                      '**** ${_generateCardNumber()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getWalletTextColor().withOpacity(0.6),
                        letterSpacing: 1,
                      ),
                    ),
                  const SizedBox(width: 8),
                  _buildCardLogo(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardLogo() {
    switch (_currentWallet.type.toUpperCase()) {
      case 'BANK':
      case 'CREDIT_CARD':
        return Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            Transform.translate(
              offset: const Offset(-8, 0),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      case 'E_WALLET':
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.phone_android,
            color: _getWalletTextColor(),
            size: 20,
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.payments,
            color: _getWalletTextColor(),
            size: 20,
          ),
        );
    }
  }

  Widget _buildStatsSection(BuildContext context, bool isDark) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        double monthlyExpense = 0;
        double monthlyIncome = 0;
        
        if (state is TransactionLoaded) {
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          
          for (var tx in state.transactions) {
            if (tx.transactionDate.isAfter(startOfMonth) ||
                tx.transactionDate.isAtSameMomentAs(startOfMonth)) {
              if (tx.type == TransactionType.expense) {
                monthlyExpense += tx.amount.abs();
              } else {
                monthlyIncome += tx.amount.abs();
              }
            }
          }
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Thu nhập',
                  monthlyIncome,
                  Icons.arrow_downward_rounded,
                  const Color(0xFF00B894),
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Chi tiêu',
                  monthlyExpense,
                  Icons.arrow_upward_rounded,
                  const Color(0xFFE17055),
                  isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, double amount, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount.toCurrency(_currentWallet.currency),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2D3436),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction, bool isDark) {
    final isExpense = transaction.type == TransactionType.expense;
    final hasReceipt = transaction.receiptUrl != null && transaction.receiptUrl!.isNotEmpty;
    
    return GestureDetector(
      onTap: () => _showTransactionDetail(context, transaction, isDark),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
            // Category Icon with receipt indicator
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(transaction.categoryName).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(transaction.categoryIcon ?? transaction.categoryName),
                    color: _getCategoryColor(transaction.categoryName),
                    size: 24,
                  ),
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
                          transaction.categoryName ?? 'Giao dịch',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                          ),
                        ),
                      ),
                      if (hasReceipt)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Hóa đơn',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C5CE7),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.transactionDate),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Amount
            Row(
              children: [
                Text(
                  '${isExpense ? '-' : '+'}\$${_formatAmount(transaction.amount.abs())}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isExpense ? const Color(0xFFE17055) : const Color(0xFF00B894),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thêm giao dịch đầu tiên',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showWalletOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Bỏ Edit Wallet - chỉ cho Delete
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete, color: Colors.red),
              ),
              title: const Text(
                'Xóa ví',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditWalletDialog(BuildContext context) {
    AddWalletBottomSheet.show(context, wallet: _currentWallet);
  }

  void _showDeleteConfirmation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletBloc = context.read<WalletBloc>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Xóa ví',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Bạn có chắc muốn xóa "${_currentWallet.name}" không? Thao tác này không thể hoàn tác.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Hủy',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              walletBloc.add(WalletDeleteRequested(id: _currentWallet.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
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
                      color: _getCategoryColor(transaction.categoryName).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getCategoryIcon(transaction.categoryIcon ?? transaction.categoryName),
                      color: _getCategoryColor(transaction.categoryName),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.categoryName ?? 'Giao dịch',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isExpense ? 'Chi tiêu' : 'Thu nhập',
                          style: TextStyle(
                            fontSize: 14,
                            color: isExpense ? const Color(0xFFE17055) : const Color(0xFF00B894),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isExpense ? '-' : '+'}\$${_formatAmount(transaction.amount.abs())}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? const Color(0xFFE17055) : const Color(0xFF00B894),
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
                      'Ngày',
                      _formatDate(transaction.transactionDate),
                      Icons.calendar_today_outlined,
                      isDark,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Wallet
                    _buildDetailRow(
                      'Ví',
                      _currentWallet.name,
                      Icons.account_balance_wallet_outlined,
                      isDark,
                    ),
                    
                    // Note
                    if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Ghi chú',
                        transaction.note!,
                        Icons.note_outlined,
                        isDark,
                      ),
                    ],
                    
                    // Created by (for group transactions)
                    if (transaction.createdByUserName != null && transaction.groupId != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Tạo bởi',
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
                        'Nhóm',
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
                            'Hóa đơn / Biên lai',
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
                                            'Không thể tải hình ảnh',
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
                                          'Nhấn để xem',
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
                      'Mã giao dịch: ${transaction.id.substring(0, 8)}...',
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
                              'Không thể tải hình ảnh',
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
                    'Chụm để phóng to • Kéo để di chuyển',
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

  // Helper methods
  List<Color> _getWalletGradient() {
    switch (_currentWallet.type.toUpperCase()) {
      case 'BANK':
        return [const Color(0xFF667EEA), const Color(0xFF764BA2)];
      case 'E_WALLET':
        return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
      case 'CREDIT_CARD':
        return [const Color(0xFFFF416C), const Color(0xFFFF4B2B)];
      case 'CASH':
      default:
        return [const Color(0xFF6C5CE7), const Color(0xFF8B7CF7)];
    }
  }

  Color _getWalletCardColor() {
    switch (_currentWallet.type.toUpperCase()) {
      case 'BANK':
        return const Color(0xFFFFD93D);
      case 'E_WALLET':
        return const Color(0xFF6BCB77);
      case 'CREDIT_CARD':
        return const Color(0xFFBDBDBD);
      case 'CASH':
      default:
        return const Color(0xFFFFD93D);
    }
  }

  Color _getWalletTextColor() {
    switch (_currentWallet.type.toUpperCase()) {
      case 'BANK':
      case 'CASH':
        return const Color(0xFF2D3436);
      case 'CREDIT_CARD':
        return const Color(0xFF2D3436);
      default:
        return const Color(0xFF2D3436);
    }
  }

  String _generateCardNumber() {
    // Generate last 4 digits based on wallet id hash
    final hash = _currentWallet.id.hashCode.abs();
    return (hash % 10000).toString().padLeft(4, '0');
  }

  String _formatMonth(DateTime date) {
    final months = ['Th1', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6', 
                    'Th7', 'Th8', 'Th9', 'Th10', 'Th11', 'Th12'];
    return '${months[date.month - 1]}/${date.year}';
  }

  String _formatDate(DateTime date) {
    final months = ['Th1', 'Th2', 'Th3', 'Th4', 'Th5', 'Th6', 
                    'Th7', 'Th8', 'Th9', 'Th10', 'Th11', 'Th12'];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatAmount(double amount) {
    // Chỉ rút gọn khi >= 1 tỷ
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    }
    // Hiển thị đầy đủ số cho số < 1 tỷ
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  IconData _getCategoryIcon(String? iconOrName) {
    if (iconOrName == null) return Icons.receipt;
    
    final iconMap = {
      'shopping': Icons.shopping_bag,
      'food': Icons.restaurant,
      'transport': Icons.directions_car,
      'entertainment': Icons.movie,
      'health': Icons.medical_services,
      'education': Icons.school,
      'bills': Icons.receipt,
      'salary': Icons.attach_money,
      'investment': Icons.trending_up,
      'gift': Icons.card_giftcard,
      'sports': Icons.fitness_center,
      'medicine': Icons.medication,
    };
    
    return iconMap[iconOrName.toLowerCase()] ?? Icons.receipt;
  }

  Color _getCategoryColor(String? name) {
    if (name == null) return const Color(0xFF6C5CE7);
    
    final colorMap = {
      'shopping': const Color(0xFF00CEC9),
      'food': const Color(0xFFFF7675),
      'transport': const Color(0xFF74B9FF),
      'entertainment': const Color(0xFFA29BFE),
      'health': const Color(0xFFFF7675),
      'education': const Color(0xFF55EFC4),
      'bills': const Color(0xFFFDCB6E),
      'salary': const Color(0xFF00B894),
      'investment': const Color(0xFF6C5CE7),
      'gift': const Color(0xFFE84393),
      'sports': const Color(0xFF00CEC9),
      'medicine': const Color(0xFFFF7675),
    };
    
    return colorMap[name.toLowerCase()] ?? const Color(0xFF6C5CE7);
  }
}
