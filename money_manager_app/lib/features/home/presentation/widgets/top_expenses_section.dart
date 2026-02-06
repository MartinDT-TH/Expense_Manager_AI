import 'package:flutter/material.dart';

class TopExpenseItem {
  final String category;
  final int percentage;
  final double amount;
  final IconData icon;
  final Color color;

  const TopExpenseItem({
    required this.category,
    required this.percentage,
    required this.amount,
    required this.icon,
    required this.color,
  });
}

class TopExpensesSection extends StatelessWidget {
  final List<TopExpenseItem> expenses;

  const TopExpensesSection({
    super.key,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chi tiêu nhiều nhất',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 16),

        // Colored bar indicator
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: expenses.map((expense) {
              return Expanded(
                flex: expense.percentage,
                child: Container(
                  height: 6,
                  color: expense.color,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Expense items
        ...expenses.map((expense) => _buildExpenseItem(expense, isDark)),
      ],
    );
  }

  Widget _buildExpenseItem(TopExpenseItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Category info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.percentage}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '-₫${_formatNumber(item.amount.abs())}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE17055),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    return number.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
