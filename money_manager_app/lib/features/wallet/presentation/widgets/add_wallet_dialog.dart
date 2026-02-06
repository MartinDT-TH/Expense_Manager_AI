import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/wallet.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';

class AddWalletDialog extends StatefulWidget {
  final Wallet? wallet;

  const AddWalletDialog({super.key, this.wallet});

  @override
  State<AddWalletDialog> createState() => _AddWalletDialogState();
}

class _AddWalletDialogState extends State<AddWalletDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  String _selectedType = 'CASH';
  String _selectedCurrency = 'VND';

  final List<Map<String, dynamic>> _walletTypes = [
    {'value': 'CASH', 'label': 'Cash', 'icon': Icons.wallet},
    {'value': 'BANK', 'label': 'Bank Account', 'icon': Icons.account_balance},
    {'value': 'E_WALLET', 'label': 'E-Wallet', 'icon': Icons.phone_android},
    {'value': 'CREDIT_CARD', 'label': 'Credit Card', 'icon': Icons.credit_card},
  ];

  final List<Map<String, String>> _currencies = [
    {'value': 'VND', 'label': 'VND - Vietnamese Dong'},
    {'value': 'USD', 'label': 'USD - US Dollar'},
    {'value': 'EUR', 'label': 'EUR - Euro'},
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
        context.read<WalletBloc>().add(WalletUpdateRequested(
          wallet: widget.wallet!.copyWith(
            name: _nameController.text.trim(),
            balance: balance,
            currency: _selectedCurrency,
            type: _selectedType,
          ),
        ));
      } else {
        context.read<WalletBloc>().add(WalletCreateRequested(
          name: _nameController.text.trim(),
          initialBalance: balance,
          currency: _selectedCurrency,
          type: _selectedType,
        ));
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Wallet' : 'Create New Wallet'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: 'e.g. Cash Wallet',
                  prefixIcon: Icon(Icons.wallet),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter wallet name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: 'Initial Balance',
                  hintText: '0',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Wallet Type',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _walletTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Row(
                      children: [
                        Icon(type['icon'], size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(type['label']),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  prefixIcon: Icon(Icons.currency_exchange),
                ),
                items: _currencies.map((currency) {
                  return DropdownMenuItem<String>(
                    value: currency['value'],
                    child: Text(currency['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCurrency = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
