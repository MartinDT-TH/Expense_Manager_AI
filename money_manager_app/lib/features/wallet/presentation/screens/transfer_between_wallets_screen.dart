import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/extensions.dart';
import '../../../transaction/presentation/bloc/transaction_bloc.dart';
import '../../../transaction/presentation/bloc/transaction_event.dart';
import '../../../transaction/data/models/transaction_model.dart';
import '../../../transaction/domain/entities/transaction.dart';
import '../../domain/entities/wallet.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';

class TransferBetweenWalletsScreen extends StatefulWidget {
  final Wallet? sourceWallet;

  const TransferBetweenWalletsScreen({super.key, this.sourceWallet});

  @override
  State<TransferBetweenWalletsScreen> createState() => _TransferBetweenWalletsScreenState();
}

class _TransferBetweenWalletsScreenState extends State<TransferBetweenWalletsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  Wallet? _sourceWallet;
  Wallet? _destinationWallet;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sourceWallet = widget.sourceWallet;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _swapWallets() {
    setState(() {
      final temp = _sourceWallet;
      _sourceWallet = _destinationWallet;
      _destinationWallet = temp;
    });
  }

  void _performTransfer() {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceWallet == null || _destinationWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both source and destination wallets')),
      );
      return;
    }
    if (_sourceWallet!.id == _destinationWallet!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source and destination wallets must be different')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount > _sourceWallet!.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance in source wallet')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Create two transactions for the transfer
    final now = DateTime.now();
    final note = _noteController.text.trim().isNotEmpty 
        ? _noteController.text.trim() 
        : 'Transfer from ${_sourceWallet!.name} to ${_destinationWallet!.name}';

    // Expense transaction from source wallet
    final expenseTransaction = TransactionModel(
      id: const Uuid().v4(),
      amount: -amount.abs(),
      type: TransactionType.expense,
      categoryId: 'transfer',
      categoryName: 'Transfer',
      categoryIcon: 'swap_horiz',
      walletId: _sourceWallet!.id,
      note: note,
      transactionDate: now,
      isRecurring: false,
      isSynced: false,
      createdAt: now,
      updatedAt: now,
    );

    // Income transaction to destination wallet
    final incomeTransaction = TransactionModel(
      id: const Uuid().v4(),
      amount: amount.abs(),
      type: TransactionType.income,
      categoryId: 'transfer',
      categoryName: 'Transfer',
      categoryIcon: 'swap_horiz',
      walletId: _destinationWallet!.id,
      note: note,
      transactionDate: now,
      isRecurring: false,
      isSynced: false,
      createdAt: now,
      updatedAt: now,
    );

    // Use transaction bloc to create both transactions
    context.read<TransactionBloc>().add(TransactionCreateRequested(expenseTransaction));
    context.read<TransactionBloc>().add(TransactionCreateRequested(incomeTransaction));

    // Update wallet balances
    context.read<WalletBloc>().add(WalletUpdateRequested(
      wallet: _sourceWallet!.copyWith(
        balance: _sourceWallet!.balance - amount,
        lastUpdatedAt: now,
        isSynced: false,
      ),
    ));

    context.read<WalletBloc>().add(WalletUpdateRequested(
      wallet: _destinationWallet!.copyWith(
        balance: _destinationWallet!.balance + amount,
        lastUpdatedAt: now,
        isSynced: false,
      ),
    ));

    // Show success and pop
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully transferred ${amount.toCurrency(_sourceWallet!.currency)}'),
        backgroundColor: const Color(0xFF00B894),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (_) => sl<WalletBloc>()..add(WalletsLoadRequested()),
      child: BlocProvider(
        create: (_) => sl<TransactionBloc>(),
        child: Builder(
          builder: (context) {
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Transfer',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
              ),
              body: BlocBuilder<WalletBloc, WalletState>(
                builder: (context, state) {
                  List<Wallet> wallets = [];
                  if (state is WalletLoaded) {
                    wallets = state.wallets;
                  } else if (state is WalletOperationSuccess) {
                    wallets = state.wallets;
                  }

                  if (wallets.length < 2) {
                    return _buildNotEnoughWallets(isDark);
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Transfer Illustration
                          _buildTransferIllustration(isDark),
                          
                          const SizedBox(height: 32),
                          
                          // Source Wallet
                          _buildWalletSelector(
                            label: 'From',
                            selectedWallet: _sourceWallet,
                            wallets: wallets,
                            isDark: isDark,
                            onSelected: (wallet) {
                              setState(() => _sourceWallet = wallet);
                            },
                          ),
                          
                          // Swap Button
                          Center(
                            child: GestureDetector(
                              onTap: _swapWallets,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C5CE7).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.swap_vert,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          
                          // Destination Wallet
                          _buildWalletSelector(
                            label: 'To',
                            selectedWallet: _destinationWallet,
                            wallets: wallets,
                            isDark: isDark,
                            onSelected: (wallet) {
                              setState(() => _destinationWallet = wallet);
                            },
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Amount Input
                          _buildAmountInput(isDark),
                          
                          const SizedBox(height: 20),
                          
                          // Note Input
                          _buildNoteInput(isDark),
                          
                          const SizedBox(height: 32),
                          
                          // Transfer Button
                          _buildTransferButton(isDark),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransferIllustration(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.swap_horizontal_circle,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Transfer Between Wallets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Move money between your accounts',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSelector({
    required String label,
    required Wallet? selectedWallet,
    required List<Wallet> wallets,
    required bool isDark,
    required Function(Wallet) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showWalletPicker(wallets, isDark, onSelected),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                if (selectedWallet != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _getWalletGradient(selectedWallet.type),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getWalletIcon(selectedWallet.type),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedWallet.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                          ),
                        ),
                        Text(
                          selectedWallet.balance.toCurrency(selectedWallet.currency),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Wallet',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
                Icon(
                  Icons.keyboard_arrow_down,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showWalletPicker(List<Wallet> wallets, bool isDark, Function(Wallet) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Select Wallet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: wallets.length,
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getWalletGradient(wallet.type),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getWalletIcon(wallet.type),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      wallet.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                    subtitle: Text(
                      wallet.balance.toCurrency(wallet.currency),
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      onSelected(wallet);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
          ],
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.attach_money,
                color: Color(0xFF6C5CE7),
              ),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value.replaceAll(',', ''));
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNoteInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _noteController,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
          decoration: InputDecoration(
            hintText: 'Add a note...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            prefixIcon: Icon(
              Icons.notes,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _performTransfer,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.send, color: Colors.white),
          label: Text(
            _isLoading ? 'Processing...' : 'Transfer Now',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotEnoughWallets(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horizontal_circle,
                size: 64,
                color: Color(0xFF6C5CE7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Need More Wallets',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need at least 2 wallets to make a transfer. Create another wallet first.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getWalletGradient(String type) {
    switch (type.toUpperCase()) {
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

  IconData _getWalletIcon(String type) {
    switch (type.toUpperCase()) {
      case 'BANK':
        return Icons.account_balance;
      case 'E_WALLET':
        return Icons.phone_android;
      case 'CREDIT_CARD':
        return Icons.credit_card;
      case 'CASH':
      default:
        return Icons.payments;
    }
  }
}
