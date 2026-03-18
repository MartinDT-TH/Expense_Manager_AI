import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

class NumpadWidget extends StatelessWidget {
  final void Function(String) onNumberPressed;
  final void Function(String) onOperatorPressed;
  final VoidCallback onClearPressed;
  final VoidCallback onEqualsPressed;
  final VoidCallback onApplyPressed;

  const NumpadWidget({
    super.key,
    required this.onNumberPressed,
    required this.onOperatorPressed,
    required this.onClearPressed,
    required this.onEqualsPressed,
    required this.onApplyPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Row 1: AC, /, *, -
          Row(
            children: [
              _buildButton('Xóa', isOperator: true, onTap: onClearPressed),
              _buildButton('÷', isOperator: true, onTap: () => onOperatorPressed('/')),
              _buildButton('×', isOperator: true, onTap: () => onOperatorPressed('*')),
              _buildButton('−', isOperator: true, color: AppColors.expense, onTap: () => onOperatorPressed('-')),
            ],
          ),
          const SizedBox(height: 12),
          
          // Row 2: 7, 8, 9, +
          Row(
            children: [
              _buildButton('7', onTap: () => onNumberPressed('7')),
              _buildButton('8', onTap: () => onNumberPressed('8')),
              _buildButton('9', onTap: () => onNumberPressed('9')),
              _buildButton('+', isOperator: true, color: AppColors.income, onTap: () => onOperatorPressed('+')),
            ],
          ),
          const SizedBox(height: 12),
          
          // Row 3: 4, 5, 6, (part of Apply)
          Row(
            children: [
              _buildButton('4', onTap: () => onNumberPressed('4')),
              _buildButton('5', onTap: () => onNumberPressed('5')),
              _buildButton('6', onTap: () => onNumberPressed('6')),
              _buildApplyButton(isTop: true),
            ],
          ),
          const SizedBox(height: 12),
          
          // Row 4: 1, 2, 3, (part of Apply)
          Row(
            children: [
              _buildButton('1', onTap: () => onNumberPressed('1')),
              _buildButton('2', onTap: () => onNumberPressed('2')),
              _buildButton('3', onTap: () => onNumberPressed('3')),
              _buildApplyButton(isTop: false),
            ],
          ),
          const SizedBox(height: 12),
          
          // Row 5: 0 (wide), ., =
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildWideButton('0', onTap: () => onNumberPressed('0')),
              ),
              const SizedBox(width: 12),
              _buildButton('.', onTap: () => onNumberPressed('.')),
              _buildButton('=', isOperator: true, color: AppColors.numpadEquals, onTap: onEqualsPressed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    String label, {
    bool isOperator = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: color ?? (isOperator ? AppColors.numpadOperator : AppColors.numpadButton),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: isOperator ? Colors.white : Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideButton(String label, {required VoidCallback onTap}) {
    return Material(
      color: AppColors.numpadButton,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton({required bool isTop}) {
    // This creates half of the tall Apply button
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: AppColors.numpadEquals,
          borderRadius: isTop
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: InkWell(
            onTap: isTop ? null : () {
              HapticFeedback.mediumImpact();
              onApplyPressed();
            },
            borderRadius: isTop
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: isTop
                  ? const SizedBox.shrink()
                  : const Text(
                      'Áp dụng',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
