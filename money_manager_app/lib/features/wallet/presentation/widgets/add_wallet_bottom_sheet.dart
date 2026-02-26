import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/wallet.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';

class AddWalletBottomSheet extends StatefulWidget {
  final Wallet? wallet;

  const AddWalletBottomSheet({super.key, this.wallet});

  static Future<void> show(BuildContext context, {Wallet? wallet}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<WalletBloc>(),
        child: AddWalletBottomSheet(wallet: wallet),
      ),
    );
  }

  @override
  State<AddWalletBottomSheet> createState() => _AddWalletBottomSheetState();
}

class _AddWalletBottomSheetState extends State<AddWalletBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  String _selectedType = 'CASH';
  String _selectedCurrency = 'VND';
  int _selectedTypeIndex = 0;

  final List<Map<String, dynamic>> _walletTypes = [
    {
      'value': 'CASH',
      'label': 'Tiền mặt',
      'icon': Icons.payments,
      'colors': [const Color(0xFF6C5CE7), const Color(0xFF8B7CF7)],
    },
    {
      'value': 'BANK',
      'label': 'Ngân hàng',
      'icon': Icons.account_balance,
      'colors': [const Color(0xFF667EEA), const Color(0xFF764BA2)],
    },
    {
      'value': 'E_WALLET',
      'label': 'Ví điện tử',
      'icon': Icons.phone_android,
      'colors': [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    },
    {
      'value': 'CREDIT_CARD',
      'label': 'Thẻ tín dụng',
      'icon': Icons.credit_card,
      'colors': [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
    },
  ];

  final List<Map<String, String>> _currencies = [
    {'value': 'VND', 'label': 'VND', 'symbol': '₫'},
    {'value': 'USD', 'label': 'USD', 'symbol': '\$'},
    {'value': 'EUR', 'label': 'EUR', 'symbol': '€'},
  ];

  bool get isEditing => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wallet?.name ?? '');
    _balanceController = TextEditingController(
      text: widget.wallet?.balance.toStringAsFixed(0) ?? '0',
    );
    if (widget.wallet != null) {
      _selectedType = widget.wallet!.type;
      _selectedCurrency = widget.wallet!.currency;
      _selectedTypeIndex = _walletTypes.indexWhere(
        (t) => t['value'] == widget.wallet!.type,
      );
      if (_selectedTypeIndex < 0) _selectedTypeIndex = 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final balance = double.tryParse(_balanceController.text.replaceAll(',', '')) ?? 0;
      
      if (isEditing) {
        // Không cho phép edit nữa - chỉ show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể chỉnh sửa ví. Hãy xóa và tạo mới.')),
        );
        Navigator.pop(context);
      } else {
        context.read<WalletBloc>().add(WalletCreateRequested(
          name: _nameController.text.trim(),
          initialBalance: balance,
          currency: _selectedCurrency,
          type: _selectedType,
        ));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    
    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 10 * scale),
                  width: 40 * scale,
                  height: 4 * scale,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Title
              Padding(
                padding: EdgeInsets.all(20 * scale),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8 * scale),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _walletTypes[_selectedTypeIndex]['colors'],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _walletTypes[_selectedTypeIndex]['icon'],
                        color: Colors.white,
                        size: 22 * scale,
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Text(
                      isEditing ? 'Sửa ví' : 'Ví mới',
                      style: TextStyle(
                        fontSize: 18 * scale,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Wallet Type Selection
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loại ví',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 10 * scale),
                    Row(
                      children: List.generate(
                        _walletTypes.length,
                        (index) => Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTypeIndex = index;
                                _selectedType = _walletTypes[index]['value'];
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                right: index < _walletTypes.length - 1 ? 6 * scale : 0,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 10 * scale),
                              decoration: BoxDecoration(
                                gradient: _selectedTypeIndex == index
                                    ? LinearGradient(
                                        colors: _walletTypes[index]['colors'],
                                      )
                                    : null,
                                color: _selectedTypeIndex != index
                                    ? (isDark ? const Color(0xFF2D2D2D) : Colors.grey[100])
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedTypeIndex == index
                                      ? Colors.transparent
                                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _walletTypes[index]['icon'],
                                    color: _selectedTypeIndex == index
                                        ? Colors.white
                                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                    size: 22 * scale,
                                  ),
                                  SizedBox(height: 4 * scale),
                                  Text(
                                    _walletTypes[index]['label'],
                                    style: TextStyle(
                                      fontSize: 10 * scale,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedTypeIndex == index
                                          ? Colors.white
                                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 20 * scale),
              
              // Wallet Name
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                child: _buildTextField(
                  controller: _nameController,
                  label: 'Tên ví',
                  hint: 'vd. Ví tiền mặt của tôi',
                  icon: Icons.wallet,
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên ví';
                    }
                    return null;
                  },
                ),
              ),
              
              SizedBox(height: 12 * scale),
              
              // Balance & Currency Row
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _balanceController,
                        label: 'Số dư ban đầu',
                        hint: '0',
                        icon: Icons.attach_money,
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                      ),
                    ),
                    SizedBox(width: 10 * scale),
                    // Currency
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tiền tệ',
                            style: TextStyle(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCurrency,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                                icon: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                items: _currencies.map((currency) {
                                  return DropdownMenuItem<String>(
                                    value: currency['value'],
                                    child: Text(
                                      currency['label']!,
                                      style: TextStyle(
                                        fontSize: 13 * scale,
                                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedCurrency = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24 * scale),
              
              // Action Buttons
              Padding(
                padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 20 * scale),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14 * scale),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                            ),
                          ),
                        ),
                        child: Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * scale),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _walletTypes[_selectedTypeIndex]['colors'],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: (_walletTypes[_selectedTypeIndex]['colors'][0] as Color)
                                  .withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 14 * scale),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'Cập nhật ví' : 'Tạo ví',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Safe area padding
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        SizedBox(height: 8 * scale),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 13 * scale,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            prefixIcon: Icon(
              icon,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              size: 18 * scale,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _walletTypes[_selectedTypeIndex]['colors'][0] as Color,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 12 * scale),
          ),
        ),
      ],
    );
  }
}
