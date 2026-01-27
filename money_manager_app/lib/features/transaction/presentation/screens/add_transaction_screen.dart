import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/services/image_picker_service.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../category/domain/entities/category.dart';
import '../../../category/presentation/bloc/category_bloc.dart';
import '../../../category/presentation/bloc/category_event.dart';
import '../../../category/presentation/bloc/category_state.dart';
import '../../../category/presentation/widgets/add_category_dialog.dart';
import '../../../group/domain/entities/group.dart';
import '../../../group/presentation/bloc/group_bloc.dart';
import '../../../group/presentation/bloc/group_event.dart';
import '../../../group/presentation/bloc/group_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../wallet/domain/entities/wallet.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../domain/entities/transaction.dart';
import '../../data/models/transaction_model.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../bloc/transaction_state.dart';
import '../widgets/ocr_result_bottom_sheet.dart';

class AddTransactionScreen extends StatelessWidget {
  // Optional initial values from OCR or external sources
  final double? initialAmount;
  final DateTime? initialDate;
  final String? initialNote;
  final Category? initialCategory;
  final Wallet? initialWallet;
  final String? initialBillImageUrl;

  const AddTransactionScreen({
    super.key,
    this.initialAmount,
    this.initialDate,
    this.initialNote,
    this.initialCategory,
    this.initialWallet,
    this.initialBillImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => sl<CategoryBloc>()..add(const LoadCategories()),
        ),
        BlocProvider(
          create: (context) => sl<WalletBloc>()..add(WalletsLoadRequested()),
        ),
        BlocProvider(
          create: (context) => sl<TransactionBloc>(),
        ),
        BlocProvider(
          create: (context) => sl<GroupBloc>()..add(const LoadGroups()),
        ),
      ],
      child: _AddTransactionView(
        initialAmount: initialAmount,
        initialDate: initialDate,
        initialNote: initialNote,
        initialCategory: initialCategory,
        initialWallet: initialWallet,
        initialBillImageUrl: initialBillImageUrl,
      ),
    );
  }
}

class _AddTransactionView extends StatefulWidget {
  final double? initialAmount;
  final DateTime? initialDate;
  final String? initialNote;
  final Category? initialCategory;
  final Wallet? initialWallet;
  final String? initialBillImageUrl;

  const _AddTransactionView({
    this.initialAmount,
    this.initialDate,
    this.initialNote,
    this.initialCategory,
    this.initialWallet,
    this.initialBillImageUrl,
  });

  @override
  State<_AddTransactionView> createState() => _AddTransactionViewState();
}

class _AddTransactionViewState extends State<_AddTransactionView> {
  bool isIncome = true;
  String displayValue = '0';
  String expression = ''; // Hiển thị biểu thức đầy đủ
  Category? selectedCategory;
  Wallet? selectedWallet;
  Group? selectedGroup; // For group transactions
  DateTime selectedDate = DateTime.now();
  String currentOperation = '';
  double? firstOperand;
  bool justPressedOperator = false; // Track nếu vừa bấm operator
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  // Bill Image
  File? _selectedImageFile;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  double _uploadProgress = 0;

  // OCR Scanning
  bool _isOcrScanning = false;

  final ImagePickerService _imagePickerService = sl<ImagePickerService>();
  final OcrService _ocrService = sl<OcrService>();

  @override
  void initState() {
    super.initState();
    // Initialize from OCR or external data if provided
    if (widget.initialAmount != null) {
      final amount = widget.initialAmount!;
      displayValue = amount == amount.toInt()
          ? amount.toInt().toString()
          : amount.toStringAsFixed(0);
      // Default to expense for scanned receipts
      isIncome = false;
    }
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate!;
    }
    if (widget.initialNote != null) {
      _noteController.text = widget.initialNote!;
    }
    if (widget.initialCategory != null) {
      selectedCategory = widget.initialCategory;
    }
    if (widget.initialWallet != null) {
      selectedWallet = widget.initialWallet;
    }
    if (widget.initialBillImageUrl != null) {
      _uploadedImageUrl = widget.initialBillImageUrl;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Colors from design
  static const Color creamBackground = Color(0xFFF8F9FE);
  static const Color operatorPurple = Color(0xFF6C5CE7);
  static const Color incomeGreen = Color(0xFF00B894);

  void _onNumberPressed(String number) {
    setState(() {
      // Nếu vừa bấm operator, bắt đầu số mới
      if (justPressedOperator) {
        displayValue = number == '.' ? '0.' : number;
        justPressedOperator = false;
      } else if (displayValue == '0' && number != '.') {
        displayValue = number;
      } else if (number == '.' && displayValue.contains('.')) {
        return;
      } else {
        displayValue += number;
      }
      // Cập nhật expression
      if (currentOperation.isNotEmpty && firstOperand != null) {
        expression =
            '${_formatNumber(firstOperand!)} $currentOperation $displayValue';
      } else {
        expression = '';
      }
    });
  }

  void _onOperatorPressed(String operator) {
    setState(() {
      // Nếu đã có phép tính trước đó, tính kết quả trước
      if (firstOperand != null &&
          currentOperation.isNotEmpty &&
          !justPressedOperator) {
        _calculateResult();
      }

      firstOperand = double.tryParse(displayValue);
      currentOperation = operator;
      justPressedOperator = true;

      // Hiển thị expression: "80 +"
      if (firstOperand != null) {
        expression = '${_formatNumber(firstOperand!)} $operator';
      }
    });
  }

  void _calculateResult() {
    if (firstOperand == null || currentOperation.isEmpty) return;

    double secondOperand = double.tryParse(displayValue) ?? 0;
    double result = 0;

    switch (currentOperation) {
      case '+':
        result = firstOperand! + secondOperand;
        break;
      case '-':
        result = firstOperand! - secondOperand;
        break;
      case '*':
        result = firstOperand! * secondOperand;
        break;
      case '/':
        if (secondOperand != 0) {
          result = firstOperand! / secondOperand;
        }
        break;
    }

    displayValue = result == result.toInt()
        ? result.toInt().toString()
        : result.toStringAsFixed(2);
  }

  String _formatNumber(double number) {
    if (number == number.toInt()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(2);
  }

  void _onEqualsPressed() {
    if (firstOperand == null || currentOperation.isEmpty) return;

    setState(() {
      _calculateResult();
      expression = ''; // Xóa expression sau khi tính xong
      firstOperand = null;
      currentOperation = '';
      justPressedOperator = false;
    });
  }

  void _onClearPressed() {
    setState(() {
      displayValue = '0';
      expression = '';
      firstOperand = null;
      currentOperation = '';
      justPressedOperator = false;
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (displayValue.length > 1) {
        displayValue = displayValue.substring(0, displayValue.length - 1);
      } else {
        displayValue = '0';
      }
      // Cập nhật expression nếu đang trong phép tính
      if (currentOperation.isNotEmpty && firstOperand != null) {
        expression =
            '${_formatNumber(firstOperand!)} $currentOperation ${displayValue == '0' ? '' : displayValue}';
      }
      justPressedOperator = false;
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatShortDate(DateTime date) {
    if (_isToday(date)) {
      return 'Hôm nay';
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Hôm qua';
    }
    return '${date.day}/${date.month}';
  }

  void _showCategoryPicker(
      List<Category> incomeCategories, List<Category> expenseCategories) {
    final categories = isIncome ? incomeCategories : expenseCategories;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'SELECT CATEGORY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            if (categories.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.category_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No categories',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == categories.length) {
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          // Wait for bottom sheet animation to complete before showing dialog
                          await Future.delayed(const Duration(milliseconds: 300));
                          if (mounted) {
                            _showAddCategoryDialog();
                          }
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add,
                                size: 28,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add\nCategory',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final cat = categories[index];
                    final isSelected = selectedCategory?.id == cat.id;
                    final bgColor = _getCategoryColor(index);

                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedCategory = cat);
                        Navigator.pop(context);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isSelected ? operatorPurple : bgColor,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: operatorPurple, width: 3)
                                  : null,
                            ),
                            child: Icon(
                              CategoryIcons.getIcon(cat.iconCode),
                              size: 24,
                              color:
                                  isSelected ? Colors.white : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? operatorPurple
                                  : Colors.grey[700],
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(int index) {
    final colors = [
      const Color(0xFFE8F5E9),
      const Color(0xFFFFF3E0),
      const Color(0xFFE3F2FD),
      const Color(0xFFFCE4EC),
      const Color(0xFFF3E5F5),
      const Color(0xFFFFFDE7),
    ];
    return colors[index % colors.length];
  }

  void _showDatePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildDatePickerSheet(),
    );
  }

  Widget _buildDatePickerSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildQuickDateOption(
                      'Hôm nay', DateTime.now(), setSheetState),
                  const SizedBox(width: 8),
                  _buildQuickDateOption(
                      '7 ngày trước',
                      DateTime.now().subtract(const Duration(days: 7)),
                      setSheetState),
                  const SizedBox(width: 8),
                  _buildQuickDateOption(
                      '30 ngày trước',
                      DateTime.now().subtract(const Duration(days: 30)),
                      setSheetState),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: Builder(
                  builder: (context) {
                    // Ensure initialDate is within valid range
                    final firstDate = DateTime(2000);
                    final lastDate = DateTime(2030);
                    DateTime validInitialDate = selectedDate;
                    if (validInitialDate.isBefore(firstDate)) {
                      validInitialDate = firstDate;
                    }
                    if (validInitialDate.isAfter(lastDate)) {
                      validInitialDate = lastDate;
                    }
                    return CalendarDatePicker(
                      initialDate: validInitialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onDateChanged: (date) {
                        setSheetState(() {
                          selectedDate = date;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Hủy',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: operatorPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Áp dụng',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickDateOption(
      String label, DateTime date, StateSetter setSheetState) {
    final isSelected = selectedDate.day == date.day &&
        selectedDate.month == date.month &&
        selectedDate.year == date.year;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setSheetState(() {
            selectedDate = date;
          });
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
                  )
                : null,
            color: isSelected ? null : const Color(0xFFF0F0F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : const Color(0xFF636E72),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showInsufficientBalanceDialog(double amount, double balance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatter = NumberFormat('#,###', 'vi_VN');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Insufficient Balance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The expense amount exceeds your wallet balance.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildBalanceRow(
                    'Expense Amount',
                    '${formatter.format(amount)} ₫',
                    Colors.red,
                    isDark,
                  ),
                  const Divider(height: 16),
                  _buildBalanceRow(
                    'Wallet Balance',
                    '${formatter.format(balance)} ₫',
                    const Color(0xFF00B894),
                    isDark,
                  ),
                  const Divider(height: 16),
                  _buildBalanceRow(
                    'Exceeds by',
                    '${formatter.format(amount - balance)} ₫',
                    Colors.orange,
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedWithTransaction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save Anyway'),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value, Color valueColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _proceedWithTransaction() {
    setState(() => _isSaving = true);

    final amount = double.tryParse(displayValue) ?? 0;
    
    // Create transaction model with client-generated GUID
    final transaction = TransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      transactionDate: selectedDate,
      categoryId: selectedCategory!.id,
      categoryName: selectedCategory!.name,
      categoryIcon: selectedCategory!.iconCode,
      walletId: selectedWallet!.id,
      walletName: selectedWallet!.name,
      groupId: selectedGroup?.id,
      groupName: selectedGroup?.name,
      receiptUrl: _uploadedImageUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context
        .read<TransactionBloc>()
        .add(TransactionCreateRequested(transaction));
  }

  void _saveTransaction() {
    final amount = double.tryParse(displayValue) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    if (selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a wallet')),
      );
      return;
    }

    // Check if expense amount exceeds wallet balance
    if (!isIncome && amount > selectedWallet!.balance) {
      _showInsufficientBalanceDialog(amount, selectedWallet!.balance);
      return;
    }

    // Check if image is still uploading
    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please wait for image upload to complete')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Create transaction model with client-generated GUID
    final transaction = TransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      transactionDate: selectedDate,
      categoryId: selectedCategory!.id,
      categoryName: selectedCategory!.name,
      categoryIcon: selectedCategory!.iconCode,
      walletId: selectedWallet!.id,
      walletName: selectedWallet!.name,
      groupId: selectedGroup?.id,
      groupName: selectedGroup?.name,
      receiptUrl: _uploadedImageUrl, // Bill image URL
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Dispatch create event
    context
        .read<TransactionBloc>()
        .add(TransactionCreateRequested(transaction));
  }

  void _showAddCategoryDialog() {
    final categoryType = isIncome ? CategoryType.income : CategoryType.expense;

    showDialog(
      context: context,
      builder: (dialogContext) => AddCategoryDialog(
        categoryType: categoryType,
        onSave: (name, iconCode, type) {
          context.read<CategoryBloc>().add(CreateCategory(
                name: name,
                iconCode: iconCode,
                type: type,
              ));
          // Reload categories after creation
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              context.read<CategoryBloc>().add(const LoadCategories());
            }
          });
        },
      ),
    );
  }

  void _showWalletPicker(List<Wallet> wallets) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'SELECT WALLET',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            if (wallets.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Không có ví',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    final isSelected = selectedWallet?.id == wallet.id;

                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? operatorPurple.withValues(alpha: 0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getWalletIcon(wallet.type),
                          color: isSelected ? operatorPurple : Colors.grey[600],
                        ),
                      ),
                      title: Text(
                        wallet.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? operatorPurple : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        '${wallet.balance < 0 ? "-" : ""}${_formatCurrency(wallet.balance.abs())}',
                        style: TextStyle(
                          color: wallet.balance < 0 
                              ? const Color(0xFFE53935)
                              : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: wallet.balance < 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: operatorPurple)
                          : null,
                      onTap: () {
                        setState(() => selectedWallet = wallet);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showGroupPicker(List<Group> groups) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'SELECT GROUP (OPTIONAL)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this transaction with a group',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            // Clear selection option
            if (selectedGroup != null)
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                  ),
                ),
                title: const Text(
                  'No group (personal)',
                  style: TextStyle(fontWeight: FontWeight.normal),
                ),
                onTap: () {
                  setState(() => selectedGroup = null);
                  Navigator.pop(context);
                },
              ),
            if (groups.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.groups_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No groups yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create or join a group in Profile',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final isSelected = selectedGroup?.id == group.id;

                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? operatorPurple.withValues(alpha: 0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: isSelected ? operatorPurple : Colors.grey[600],
                        ),
                      ),
                      title: Text(
                        group.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? operatorPurple : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        '${group.memberCount} members',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: operatorPurple)
                          : null,
                      onTap: () {
                        setState(() => selectedGroup = group);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
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

  void _showNoteInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADD NOTE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter note...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _noteController.clear();
                    Navigator.pop(context);
                  },
                  child:
                      Text('Clear', style: TextStyle(color: Colors.grey[600])),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: operatorPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child:
                      const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== BILL IMAGE METHODS =====

  void _showImageSourcePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.read<AuthBloc>().state;
    final isPremiumUser = authState is Authenticated && authState.user.isPremium;
    final isFreemiumUser = !isPremiumUser;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(18 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ADD BILL IMAGE',
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 16 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.document_scanner_rounded,
                    label: 'Scan Bill',
                    color: const Color(0xFFE17055),
                    badgeText: 'Premium',
                    onTap: () {
                      Navigator.pop(context);
                      _scanBillWithOcr();
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: operatorPurple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF00B894),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                  if (_selectedImageFile != null || _uploadedImageUrl != null)
                    _buildImageSourceOption(
                      icon: Icons.delete_rounded,
                      label: 'Remove',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _removeImage();
                      },
                    ),
                ],
              ),
              SizedBox(height: 14 * scale),
              // OCR Info text
              Container(
                padding: EdgeInsets.all(10 * scale),
                decoration: BoxDecoration(
                  color: const Color(0xFFE17055).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFE17055),
                      size: 18 * scale,
                    ),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: Text(
                        'Use "Scan Bill" to automatically extract amount, date, and merchant from your receipt!',
                        style: TextStyle(
                          fontSize: 11 * scale,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8 * scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? badgeText,
    bool isLocked = false,
  }) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    final button = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(14 * scale),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28 * scale),
            ),
            if (badgeText != null)
              Positioned(
                right: -4,
                top: -6,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6 * scale,
                    vertical: 2 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            if (isLocked)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.lock,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 6 * scale),
        Text(
          label,
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: button,
    );
  }

  Future<void> _pickImageFromCamera() async {
    final file = await _imagePickerService.pickFromCamera(
      maxWidth: 1920,
      maxHeight: 1920,
      quality: 85,
    );
    if (file != null) {
      setState(() {
        _selectedImageFile = file;
        _uploadedImageUrl = null;
      });
      _uploadImage(file);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final file = await _imagePickerService.pickFromGallery(
      maxWidth: 1920,
      maxHeight: 1920,
      quality: 85,
    );
    if (file != null) {
      setState(() {
        _selectedImageFile = file;
        _uploadedImageUrl = null;
      });
      _uploadImage(file);
    }
  }

  Future<void> _uploadImage(File file) async {
    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0;
    });

    final cloudinaryService = sl<CloudinaryService>();
    final result = await cloudinaryService.uploadImage(
      file,
      folder: CloudinaryService.billsFolder,
      onProgress: (sent, total) {
        setState(() {
          _uploadProgress = sent / total;
        });
      },
    );

    setState(() {
      _isUploadingImage = false;
      if (result.success && result.secureUrl != null) {
        _uploadedImageUrl = result.secureUrl;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill image uploaded successfully!'),
            backgroundColor: Color(0xFF00B894),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${result.error ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _uploadedImageUrl = null;
      _uploadProgress = 0;
    });
  }

  // ===== OCR SCAN BILL METHOD =====

  Future<void> _scanBillWithOcr() async {
    // Step 1: Capture image from camera
    final file = await _imagePickerService.pickFromCamera(
      maxWidth: 1920,
      maxHeight: 1920,
      quality: 90,
    );

    if (file == null) return;

    setState(() {
      _selectedImageFile = file;
      _uploadedImageUrl = null;
      _isUploadingImage = true;
      _uploadProgress = 0;
    });

    // Step 2: Upload to Cloudinary
    final cloudinaryService = sl<CloudinaryService>();
    final uploadResult = await cloudinaryService.uploadImage(
      file,
      folder: CloudinaryService.billsFolder,
      onProgress: (sent, total) {
        setState(() {
          _uploadProgress = sent / total * 0.5; // First 50% for upload
        });
      },
    );

    if (!uploadResult.success || uploadResult.secureUrl == null) {
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Upload failed: ${uploadResult.error ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _uploadedImageUrl = uploadResult.secureUrl;
      _uploadProgress = 0.6;
      _isOcrScanning = true;
    });

    // Step 3: Call OCR API
    try {
      final ocrResult = await _ocrService.scanReceipt(uploadResult.secureUrl!);

      setState(() {
        _uploadProgress = 1.0;
        _isUploadingImage = false;
        _isOcrScanning = false;
      });

      if (!mounted) return;

      // Step 4: Get wallets for the bottom sheet
      final walletState = context.read<WalletBloc>().state;
      List<Wallet> wallets = [];
      if (walletState is WalletLoaded) {
        wallets = walletState.wallets;
      } else if (walletState is WalletOperationSuccess) {
        wallets = walletState.wallets;
      }

      // Step 5: Show OCR Result Bottom Sheet
      OcrResultBottomSheet.show(
        context: context,
        scanResult: ocrResult,
        billImageUrl: uploadResult.secureUrl!,
        wallets: wallets,
        onConfirm: (data, category, wallet) {
          _applyOcrData(data, category, wallet);
        },
      );
    } on OcrPremiumRequiredException {
      setState(() {
        _isUploadingImage = false;
        _isOcrScanning = false;
      });
      if (mounted) {
        _showPremiumRequiredDialog();
      }
    } on OcrException catch (e) {
      setState(() {
        _isUploadingImage = false;
        _isOcrScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
        _isOcrScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyOcrData(
      OcrTransactionData data, Category? category, Wallet? wallet) {
    setState(() {
      // Apply amount
      if (data.amount != null) {
        displayValue = data.amount!.toStringAsFixed(0);
        expression = '';
        firstOperand = null;
        currentOperation = '';
      }

      // Apply date
      if (data.date != null) {
        selectedDate = data.date!;
      }

      // Apply category
      if (category != null) {
        selectedCategory = category;
        isIncome = category.type == CategoryType.income;
      }

      // Apply wallet
      if (wallet != null) {
        selectedWallet = wallet;
      }

      // Apply note
      if (data.note != null && data.note!.isNotEmpty) {
        _noteController.text = data.note!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Scan data applied! Review and save your transaction.'),
          ],
        ),
        backgroundColor: Color(0xFF00B894),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showPremiumRequiredDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE17055).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Color(0xFFE17055),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Premium Feature',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Bill Scanning is a premium feature that uses AI to automatically extract transaction details from your receipts.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildPremiumFeatureRow(
                      Icons.auto_awesome, 'Auto-extract amount'),
                  _buildPremiumFeatureRow(
                      Icons.calendar_today, 'Detect transaction date'),
                  _buildPremiumFeatureRow(Icons.store, 'Identify merchant'),
                  _buildPremiumFeatureRow(Icons.category, 'Suggest category'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to premium upgrade screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Premium upgrade coming soon!'),
                  backgroundColor: Color(0xFF6C5CE7),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE17055),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                SizedBox(width: 6 * scale),
                const Text(
                  'Upgrade Now',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureRow(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE17055)),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreview() {
    if (_selectedImageFile == null && _uploadedImageUrl == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: _selectedImageFile != null
                  ? Image.file(
                      _selectedImageFile!,
                      fit: BoxFit.contain,
                      height: MediaQuery.of(context).size.height * 0.5,
                    )
                  : Image.network(
                      _uploadedImageUrl!,
                      fit: BoxFit.contain,
                      height: MediaQuery.of(context).size.height * 0.5,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _removeImage();
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: operatorPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Close',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillImageButton(bool isDark) {
    final hasImage = _selectedImageFile != null || _uploadedImageUrl != null;

    return GestureDetector(
      onTap: hasImage ? _showImagePreview : _showImageSourcePicker,
      onLongPress: hasImage ? _showImageSourcePicker : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasImage
              ? const Color(0xFF00B894).withOpacity(0.1)
              : _isOcrScanning
                  ? const Color(0xFFE17055).withOpacity(0.1)
                  : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage
                ? const Color(0xFF00B894)
                : _isOcrScanning
                    ? const Color(0xFFE17055)
                    : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          ),
        ),
        child: _isUploadingImage || _isOcrScanning
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: _isOcrScanning ? null : _uploadProgress,
                      strokeWidth: 2,
                      color: _isOcrScanning
                          ? const Color(0xFFE17055)
                          : operatorPurple,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOcrScanning
                        ? 'Scanning...'
                        : '${(_uploadProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _isOcrScanning
                          ? const Color(0xFFE17055)
                          : operatorPurple,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImage && _selectedImageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        _selectedImageFile!,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Icon(
                      hasImage
                          ? Icons.receipt_long
                          : Icons.document_scanner_outlined,
                      color:
                          hasImage ? const Color(0xFF00B894) : Colors.grey[500],
                      size: 18,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    hasImage ? 'Bill' : 'Scan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color:
                          hasImage ? const Color(0xFF00B894) : Colors.grey[600],
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00B894),
                      size: 14,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransactionBloc, TransactionState>(
      listener: (context, state) {
        if (state is TransactionCreated) {
          setState(() => _isSaving = false);
          // Refresh wallet balance after transaction created
          context.read<WalletBloc>().add(WalletsLoadRequested());
          Navigator.pop(
              context, true); // Return true to indicate refresh needed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${isIncome ? 'income' : 'expense'}: $displayValue ₫',
              ),
              backgroundColor: isIncome ? incomeGreen : const Color(0xFFE17055),
            ),
          );
        } else if (state is TransactionError) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: isDark ? const Color(0xFF121212) : creamBackground,
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
                  ),
                ),
              ),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Add Transaction',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),
            body: BlocBuilder<CategoryBloc, CategoryState>(
              builder: (context, categoryState) {
                List<Category> incomeCategories = [];
                List<Category> expenseCategories = [];
                bool isCategoryLoading = false;
                String? categoryError;

                if (categoryState is CategoryLoading) {
                  isCategoryLoading = true;
                } else if (categoryState is CategoryLoaded) {
                  incomeCategories = categoryState.incomeCategories;
                  expenseCategories = categoryState.expenseCategories;
                } else if (categoryState is CategoryError) {
                  categoryError = categoryState.message;
                }

                return BlocBuilder<WalletBloc, WalletState>(
                  builder: (context, walletState) {
                    List<Wallet> wallets = [];
                    bool isWalletLoading = false;

                    if (walletState is WalletLoading) {
                      isWalletLoading = true;
                    } else if (walletState is WalletLoaded) {
                      wallets = walletState.wallets;
                    } else if (walletState is WalletOperationSuccess) {
                      wallets = walletState.wallets;
                    }

                    return BlocBuilder<GroupBloc, GroupState>(
                      builder: (context, groupState) {
                        List<Group> groups = [];
                        bool isGroupLoading = false;

                        if (groupState is GroupLoading) {
                          isGroupLoading = true;
                        } else if (groupState is GroupsLoaded) {
                          groups = groupState.groups;
                        }

                        return Column(
                          children: [
                            // Compact Controls Row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  // Income/Expense Toggle (1 button)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isIncome = !isIncome;
                                        selectedCategory = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isIncome
                                              ? [
                                                  const Color(0xFF00B894),
                                                  const Color(0xFF55EFC4)
                                                ]
                                              : [
                                                  const Color(0xFFE17055),
                                                  const Color(0xFFFAB1A0)
                                                ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isIncome
                                                ? Icons.arrow_downward_rounded
                                                : Icons.arrow_upward_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isIncome ? 'Income' : 'Expenses',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Category
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: isCategoryLoading
                                          ? null
                                          : () => _showCategoryPicker(
                                              incomeCategories,
                                              expenseCategories),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF2C2C2E)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selectedCategory != null
                                                ? const Color(0xFF6C5CE7)
                                                : isDark
                                                    ? Colors.grey.shade700
                                                    : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              selectedCategory != null
                                                  ? CategoryIcons.getIcon(
                                                      selectedCategory!
                                                          .iconCode)
                                                  : Icons.category_rounded,
                                              color: const Color(0xFF6C5CE7),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                selectedCategory?.name ??
                                                    'Category',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      selectedCategory != null
                                                          ? (isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF2D3436))
                                                          : Colors.grey[500],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(Icons.keyboard_arrow_down,
                                                color: Colors.grey[400],
                                                size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Date
                                  GestureDetector(
                                    onTap: _showDatePicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF2C2C2E)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: isDark
                                                ? Colors.grey.shade700
                                                : Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.calendar_today_rounded,
                                              color: Color(0xFF6C5CE7),
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatShortDate(selectedDate),
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Row 2: Wallet, Note
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Row(
                                children: [
                                  // Wallet
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: isWalletLoading
                                          ? null
                                          : () => _showWalletPicker(wallets),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF2C2C2E)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selectedWallet != null
                                                ? const Color(0xFF00B894)
                                                : Colors.orange.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              selectedWallet != null
                                                  ? _getWalletIcon(
                                                      selectedWallet!.type)
                                                  : Icons
                                                      .account_balance_wallet_rounded,
                                              color: const Color(0xFF00B894),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                selectedWallet?.name ??
                                                    'Select wallet *',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: selectedWallet != null
                                                      ? (isDark
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF2D3436))
                                                      : Colors.orange[400],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(Icons.keyboard_arrow_down,
                                                color: Colors.grey[400],
                                                size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Note
                                  GestureDetector(
                                    onTap: _showNoteInput,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _noteController.text.isNotEmpty
                                            ? const Color(0xFF6C5CE7)
                                                .withOpacity(0.1)
                                            : (isDark
                                                ? const Color(0xFF2C2C2E)
                                                : Colors.white),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _noteController.text.isNotEmpty
                                              ? const Color(0xFF6C5CE7)
                                              : (isDark
                                                  ? Colors.grey.shade700
                                                  : Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _noteController.text.isNotEmpty
                                                ? Icons.note_alt
                                                : Icons.note_alt_outlined,
                                            color:
                                                _noteController.text.isNotEmpty
                                                    ? const Color(0xFF6C5CE7)
                                                    : Colors.grey[500],
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _noteController.text.isNotEmpty
                                                ? 'Has note'
                                                : 'Note',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: _noteController
                                                      .text.isNotEmpty
                                                  ? const Color(0xFF6C5CE7)
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Bill Image Button
                                  _buildBillImageButton(isDark),
                                ],
                              ),
                            ),
                            // Error message
                            if (categoryError != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.red[400], size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Cannot load categories',
                                          style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.refresh,
                                            color: Colors.red[400], size: 20),
                                        onPressed: () {
                                          context
                                              .read<CategoryBloc>()
                                              .add(const LoadCategories());
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Row 3: Group selector (optional)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Row(
                                children: [
                                  // Group
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: isGroupLoading
                                          ? null
                                          : () => _showGroupPicker(groups),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selectedGroup != null
                                              ? const Color(0xFF00CEC9)
                                                  .withOpacity(0.1)
                                              : (isDark
                                                  ? const Color(0xFF2C2C2E)
                                                  : Colors.white),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selectedGroup != null
                                                ? const Color(0xFF00CEC9)
                                                : (isDark
                                                    ? Colors.grey.shade700
                                                    : Colors.grey.shade300),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              selectedGroup != null
                                                  ? Icons.groups_rounded
                                                  : Icons.groups_outlined,
                                              color: selectedGroup != null
                                                  ? const Color(0xFF00CEC9)
                                                  : Colors.grey[500],
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                selectedGroup?.name ??
                                                    'Personal (no group)',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: selectedGroup != null
                                                      ? const Color(0xFF00CEC9)
                                                      : Colors.grey[500],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (groups.isNotEmpty)
                                              Icon(Icons.keyboard_arrow_down,
                                                  color: Colors.grey[400],
                                                  size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // Amount Display
                            _buildAmountDisplay(),

                            const SizedBox(height: 8),

                            // Calculator Numpad
                            _buildCalculatorNumpad(),

                            const SizedBox(height: 8),

                            // Bottom Navigation Bar
                            _buildBottomNavBar(),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
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
              color: const Color(0xFF6C5CE7).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expression line
            if (expression.isNotEmpty)
              Text(
                expression,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            // Amount value
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '₫',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _formatDisplayValue(displayValue),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Operator indicator
            if (currentOperation.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentOperation == '+'
                      ? 'Adding'
                      : currentOperation == '-'
                          ? 'Subtracting'
                          : currentOperation == '*'
                              ? 'Multiplying'
                              : 'Dividing',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDisplayValue(String value) {
    // Thêm dấu phẩy phân cách hàng nghìn
    if (value.contains('.')) {
      final parts = value.split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '$intPart.${parts[1]}';
    }
    return value.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildCalculatorNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Row 1: C, ÷, ×, -
          Row(
            children: [
              _buildClearButton(),
              const SizedBox(width: 8),
              _buildOperatorButton('÷', () => _onOperatorPressed('/')),
              const SizedBox(width: 8),
              _buildOperatorButton('×', () => _onOperatorPressed('*')),
              const SizedBox(width: 8),
              _buildOperatorButton('-', () => _onOperatorPressed('-')),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: 7, 8, 9, +
          Row(
            children: [
              _buildNumpadButton('7', () => _onNumberPressed('7')),
              const SizedBox(width: 8),
              _buildNumpadButton('8', () => _onNumberPressed('8')),
              const SizedBox(width: 8),
              _buildNumpadButton('9', () => _onNumberPressed('9')),
              const SizedBox(width: 8),
              _buildOperatorButton('+', () => _onOperatorPressed('+')),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: 4, 5, 6, =
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildNumpadButton('4', () => _onNumberPressed('4')),
                        const SizedBox(width: 8),
                        _buildNumpadButton('5', () => _onNumberPressed('5')),
                        const SizedBox(width: 8),
                        _buildNumpadButton('6', () => _onNumberPressed('6')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 4: 1, 2, 3
                    Row(
                      children: [
                        _buildNumpadButton('1', () => _onNumberPressed('1')),
                        const SizedBox(width: 8),
                        _buildNumpadButton('2', () => _onNumberPressed('2')),
                        const SizedBox(width: 8),
                        _buildNumpadButton('3', () => _onNumberPressed('3')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTallOperatorButton('=', _onEqualsPressed),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 5: 0 (wide), ., ⌫
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildWideNumpadButton('0', () => _onNumberPressed('0')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumpadButton('.', () => _onNumberPressed('.')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBackspaceButton(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton() {
    return Expanded(
      child: GestureDetector(
        onTap: _onClearPressed,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE17055), Color(0xFFFAB1A0)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'C',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _onBackspacePressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF636E72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadButton(String text, VoidCallback onPressed) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2D3436),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideNumpadButton(String text, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2D3436),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorButton(String text, VoidCallback onPressed) {
    // Map display symbols to actual operators for active state check
    String actualOp = text == '÷' ? '/' : (text == '×' ? '*' : text);
    final isActive = currentOperation == actualOp;
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? [const Color(0xFF00B894), const Color(0xFF55EFC4)]
                  : [const Color(0xFF6C5CE7), const Color(0xFF8B7CF7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTallOperatorButton(String text, VoidCallback onPressed) {
    final isActive = currentOperation == text;
    final isEquals = text == '=';
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isEquals
                ? [const Color(0xFF00B894), const Color(0xFF55EFC4)]
                : isActive
                    ? [const Color(0xFF00B894), const Color(0xFF55EFC4)]
                    : [const Color(0xFF6C5CE7), const Color(0xFF8B7CF7)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, 'Trang chủ', false, () {
              Navigator.pop(context);
            }),
            _buildNavItem(Icons.swap_horiz, 'Giao dịch', false, () {
              Navigator.pop(context);
            }),
            // FAB - Save Transaction
            GestureDetector(
              onTap: _isSaving ? null : _saveTransaction,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: operatorPurple.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSaving
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 26,
                      ),
              ),
            ),
            _buildNavItem(Icons.bar_chart_outlined, 'Thống kê', false, () {}),
            _buildNavItem(Icons.person_outline, 'Cá nhân', false, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? operatorPurple : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? operatorPurple : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
