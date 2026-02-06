import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../category/domain/entities/category.dart';
import '../../../category/presentation/bloc/category_bloc.dart';
import '../../../category/presentation/bloc/category_event.dart';
import '../../../category/presentation/bloc/category_state.dart';
import '../../../wallet/domain/entities/wallet.dart';
import '../../../../core/di/injection_container.dart';
import '../screens/add_transaction_screen.dart';

/// Model to hold OCR scan result with user selections
class OcrTransactionData {
  final double? amount;
  final DateTime? date;
  final String? note;
  final String? merchantName;
  final Category? suggestedCategory;
  final String? billImageUrl;

  OcrTransactionData({
    this.amount,
    this.date,
    this.note,
    this.merchantName,
    this.suggestedCategory,
    this.billImageUrl,
  });

  OcrTransactionData copyWith({
    double? amount,
    DateTime? date,
    String? note,
    String? merchantName,
    Category? suggestedCategory,
    String? billImageUrl,
  }) {
    return OcrTransactionData(
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      merchantName: merchantName ?? this.merchantName,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      billImageUrl: billImageUrl ?? this.billImageUrl,
    );
  }
}

/// Bottom sheet to display and edit OCR scan results
class OcrResultBottomSheet extends StatefulWidget {
  final OcrScanResult scanResult;
  final String billImageUrl;
  final List<Wallet> wallets;
  final Function(OcrTransactionData data, Category? category, Wallet? wallet)? onConfirm;
  final VoidCallback? onTransactionSaved;

  const OcrResultBottomSheet({
    super.key,
    required this.scanResult,
    required this.billImageUrl,
    required this.wallets,
    this.onConfirm,
    this.onTransactionSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required OcrScanResult scanResult,
    required String billImageUrl,
    required List<Wallet> wallets,
    Function(OcrTransactionData data, Category? category, Wallet? wallet)? onConfirm,
    VoidCallback? onTransactionSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider(
        create: (_) => sl<CategoryBloc>()..add(LoadCategoriesByType(CategoryType.expense)),
        child: OcrResultBottomSheet(
          scanResult: scanResult,
          billImageUrl: billImageUrl,
          wallets: wallets,
          onConfirm: onConfirm,
          onTransactionSaved: onTransactionSaved,
        ),
      ),
    );
  }

  @override
  State<OcrResultBottomSheet> createState() => _OcrResultBottomSheetState();
}

class _OcrResultBottomSheetState extends State<OcrResultBottomSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  Category? _selectedCategory;
  Wallet? _selectedWallet;
  List<Category> _categories = [];
  bool _isExpense = true;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.scanResult.amount?.toStringAsFixed(0) ?? '',
    );
    _noteController = TextEditingController(
      text: widget.scanResult.description ?? 
            widget.scanResult.merchantName ?? '',
    );
    _selectedDate = widget.scanResult.date ?? DateTime.now();
    _selectedWallet = widget.wallets.isNotEmpty ? widget.wallets.first : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onCategoriesLoaded(List<Category> categories) {
    _categories = categories;
    
    // Try to find suggested category
    if (widget.scanResult.suggestedCategoryId != null) {
      try {
        _selectedCategory = categories.firstWhere(
          (c) => c.id == widget.scanResult.suggestedCategoryId,
        );
      } catch (_) {
        if (categories.isNotEmpty) {
          _selectedCategory = categories.first;
        }
      }
    } else if (categories.isNotEmpty) {
      // Select first category by default
      _selectedCategory = categories.first;
    }
    
    if (mounted) setState(() {});
  }

  void _toggleTransactionType() {
    setState(() {
      _isExpense = !_isExpense;
    });
    
    // Reload categories for new type
    if (_isExpense) {
      context.read<CategoryBloc>().add(LoadCategoriesByType(CategoryType.expense));
    } else {
      context.read<CategoryBloc>().add(LoadCategoriesByType(CategoryType.income));
    }
  }

  Future<void> _selectDate() async {
    // Ensure initialDate is within valid range
    final firstDate = DateTime(2000);
    final lastDate = DateTime.now().add(const Duration(days: 365));
    DateTime validInitialDate = _selectedDate;
    if (validInitialDate.isBefore(firstDate)) {
      validInitialDate = firstDate;
    }
    if (validInitialDate.isAfter(lastDate)) {
      validInitialDate = lastDate;
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: validInitialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C5CE7),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCategoryPickerSheet(),
    );
  }

  void _showWalletPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildWalletPickerSheet(),
    );
  }

  void _onConfirm() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục')),
      );
      return;
    }

    if (_selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví')),
      );
      return;
    }

    final data = OcrTransactionData(
      amount: amount,
      date: _selectedDate,
      note: _noteController.text.trim(),
      merchantName: widget.scanResult.merchantName,
      suggestedCategory: _selectedCategory,
      billImageUrl: widget.billImageUrl,
    );

    // Close the bottom sheet first
    Navigator.pop(context);

    // If onConfirm callback is provided, use it (legacy behavior)
    if (widget.onConfirm != null) {
      widget.onConfirm!(data, _selectedCategory, _selectedWallet);
      return;
    }

    // Navigate directly to AddTransactionScreen
    final navigatorContext = context;
    if (!mounted) return;
    
    final result = await Navigator.push<bool>(
      navigatorContext,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          initialAmount: data.amount,
          initialDate: data.date,
          initialNote: data.note,
          initialCategory: _selectedCategory,
          initialWallet: _selectedWallet,
          initialBillImageUrl: widget.billImageUrl,
        ),
      ),
    );

    // Notify parent that transaction was saved
    if (result == true && widget.onTransactionSaved != null) {
      widget.onTransactionSaved!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.document_scanner,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kết quả quét',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF2D3436),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.scanResult.hasData 
                            ? 'Xem lại và xác nhận thông tin' 
                            : 'Nhập thông tin giao dịch thủ công',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),

          // Content
          Expanded(
            child: BlocConsumer<CategoryBloc, CategoryState>(
              listener: (context, state) {
                if (state is CategoryLoaded) {
                  final categories = _isExpense 
                      ? state.expenseCategories 
                      : state.incomeCategories;
                  _onCategoriesLoaded(categories);
                }
              },
              builder: (context, state) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bill Image Preview
                      _buildBillPreview(isDark),
                      
                      const SizedBox(height: 24),

                      // Transaction Type Toggle
                      _buildTypeToggle(isDark),

                      const SizedBox(height: 20),

                      // Amount Field
                      _buildAmountField(isDark),

                      const SizedBox(height: 20),

                      // Category Selection
                      _buildCategoryField(isDark),

                      const SizedBox(height: 20),

                      // Wallet Selection
                      _buildWalletField(isDark),

                      const SizedBox(height: 20),

                      // Date Selection
                      _buildDateField(isDark),

                      const SizedBox(height: 20),

                      // Note Field
                      _buildNoteField(isDark),

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Xác nhận & Lưu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillPreview(bool isDark) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          // Image thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
            child: Image.network(
              widget.billImageUrl,
              width: 100,
              height: 120,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 100,
                  height: 120,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                width: 100,
                height: 120,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Icon(
                  Icons.broken_image,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
            ),
          ),

          // Extracted info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.scanResult.merchantName != null) ...[
                    Row(
                      children: [
                        Icon(Icons.store, size: 16, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.scanResult.merchantName!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF2D3436),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.scanResult.suggestedCategoryName != null) ...[
                    Row(
                      children: [
                        Icon(Icons.category, size: 16, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.scanResult.suggestedCategoryName!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6C5CE7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        widget.scanResult.hasData 
                            ? Icons.check_circle 
                            : Icons.info_outline,
                        size: 16,
                        color: widget.scanResult.hasData 
                            ? const Color(0xFF00B894) 
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.scanResult.hasData 
                            ? 'Đã trích xuất dữ liệu' 
                            : 'Cần nhập thủ công',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.scanResult.hasData 
                              ? const Color(0xFF00B894) 
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isExpense ? null : _toggleTransactionType,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isExpense ? const Color(0xFFE17055) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 18,
                      color: _isExpense 
                          ? Colors.white 
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chi tiêu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isExpense 
                            ? Colors.white 
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: !_isExpense ? null : _toggleTransactionType,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isExpense ? const Color(0xFF00B894) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: 18,
                      color: !_isExpense 
                          ? Colors.white 
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Thu nhập',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: !_isExpense 
                            ? Colors.white 
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Số tiền', isDark),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.scanResult.amount != null 
                  ? const Color(0xFF6C5CE7).withOpacity(0.3) 
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _isExpense ? const Color(0xFFE17055) : const Color(0xFF00B894),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.attach_money,
                color: _isExpense ? const Color(0xFFE17055) : const Color(0xFF00B894),
              ),
              suffixText: '₫',
              suffixStyle: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintText: '0',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ),
        ),
        if (widget.scanResult.amount != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 4),
                Text(
                  'Tự động nhận từ hóa đơn',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Danh mục', isDark),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showCategoryPicker,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.scanResult.suggestedCategoryId != null 
                    ? const Color(0xFF6C5CE7).withOpacity(0.3) 
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(_selectedCategory?.iconCode),
                    color: const Color(0xFF6C5CE7),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCategory?.name ?? 'Chọn danh mục',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _selectedCategory != null 
                          ? (isDark ? Colors.white : const Color(0xFF2D3436))
                          : (isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (widget.scanResult.suggestedCategoryName != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 4),
                Text(
                  'Gợi ý: ${widget.scanResult.suggestedCategoryName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWalletField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Ví', isDark),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showWalletPicker,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFF00B894),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedWallet?.name ?? 'Chọn ví',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _selectedWallet != null 
                              ? (isDark ? Colors.white : const Color(0xFF2D3436))
                              : (isDark ? Colors.grey[500] : Colors.grey[600]),
                        ),
                      ),
                      if (_selectedWallet != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_formatCurrency(_selectedWallet!.balance)} ₫',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Ngày', isDark),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.scanResult.date != null 
                    ? const Color(0xFF6C5CE7).withOpacity(0.3) 
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE17055).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFFE17055),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatDate(_selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF2D3436),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        if (widget.scanResult.date != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 4),
                Text(
                  'Tự động nhận từ hóa đơn',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNoteField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Ghi chú', isDark),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF2D3436),
            ),
            decoration: InputDecoration(
              hintText: 'Thêm ghi chú...',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
      ),
    );
  }

  Widget _buildCategoryPickerSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
              'Chọn danh mục',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category.id == _selectedCategory?.id;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF6C5CE7).withOpacity(0.1)
                          : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getCategoryIcon(category.iconCode),
                            color: const Color(0xFF6C5CE7),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF2D3436),
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF6C5CE7),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletPickerSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
              'Chọn ví',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.wallets.length,
              itemBuilder: (context, index) {
                final wallet = widget.wallets[index];
                final isSelected = wallet.id == _selectedWallet?.id;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWallet = wallet;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF00B894).withOpacity(0.1)
                          : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00B894) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B894).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Color(0xFF00B894),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                                ),
                              ),
                              Text(
                                '${_formatCurrency(wallet.balance)} ₫',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF00B894),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? iconCode) {
    // Map icon codes to Icons
    final iconMap = <String, IconData>{
      'food': Icons.restaurant,
      'transport': Icons.directions_car,
      'shopping': Icons.shopping_bag,
      'entertainment': Icons.movie,
      'health': Icons.local_hospital,
      'bills': Icons.receipt,
      'education': Icons.school,
      'travel': Icons.flight,
      'groceries': Icons.shopping_cart,
      'salary': Icons.attach_money,
      'bonus': Icons.card_giftcard,
      'investment': Icons.trending_up,
      'other': Icons.more_horiz,
    };

    return iconMap[iconCode?.toLowerCase()] ?? Icons.category;
  }

  String _formatDate(DateTime date) {
    const months = ['Thg 1', 'Thg 2', 'Thg 3', 'Thg 4', 'Thg 5', 'Thg 6', 
                    'Thg 7', 'Thg 8', 'Thg 9', 'Thg 10', 'Thg 11', 'Thg 12'];
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Hôm nay, ${date.day} ${months[date.month - 1]}';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Hôm qua, ${date.day} ${months[date.month - 1]}';
    }
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
