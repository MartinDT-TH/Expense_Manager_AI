import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../category/domain/entities/category.dart';

class CategoryPickerSheet extends StatefulWidget {
  final bool isIncome;
  final void Function(Category) onCategorySelected;

  const CategoryPickerSheet({
    super.key,
    required this.isIncome,
    required this.onCategorySelected,
  });

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  String? selectedCategoryId;

  // Mock categories for now - will be loaded from Bloc
  List<Category> get categories => widget.isIncome
      ? _incomeCategories
      : _expenseCategories;

  final List<Category> _incomeCategories = [
    Category(
      id: '1',
      name: 'Salary',
      iconCode: 'attach_money',
      type: CategoryType.income,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '2',
      name: 'Gifts',
      iconCode: 'card_giftcard',
      type: CategoryType.income,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '3',
      name: 'Wages',
      iconCode: 'account_balance_wallet',
      type: CategoryType.income,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '4',
      name: 'Interest',
      iconCode: 'trending_up',
      type: CategoryType.income,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '5',
      name: 'Savings',
      iconCode: 'savings',
      type: CategoryType.income,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final List<Category> _expenseCategories = [
    Category(
      id: '10',
      name: 'Food',
      iconCode: 'restaurant',
      type: CategoryType.expense,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '11',
      name: 'Transport',
      iconCode: 'directions_car',
      type: CategoryType.expense,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '12',
      name: 'Shopping',
      iconCode: 'shopping_bag',
      type: CategoryType.expense,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '13',
      name: 'Health',
      iconCode: 'local_hospital',
      type: CategoryType.expense,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '14',
      name: 'Entertainment',
      iconCode: 'sports_esports',
      type: CategoryType.expense,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Category(
      id: '15',
      name: 'Bills',
      iconCode: 'receipt',
      type: CategoryType.expense,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[600] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Title
          Text(
            'CHOOSE CATEGORY',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Category grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: categories.length + 1, // +1 for Add button
              itemBuilder: (context, index) {
                if (index == categories.length) {
                  return _buildAddCategoryButton();
                }
                return _buildCategoryItem(categories[index]);
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Add new category button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showAddCategoryDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add new category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Category category) {
    final isSelected = selectedCategoryId == category.id;
    final color = widget.isIncome ? AppColors.income : AppColors.expense;
    
    return GestureDetector(
      onTap: () {
        setState(() => selectedCategoryId = category.id);
        widget.onCategorySelected(category);
        Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: Icon(
              CategoryIcons.getIcon(category.iconCode),
              color: isSelected ? color : Colors.grey[600],
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAddCategoryButton() {
    return GestureDetector(
      onTap: _showAddCategoryDialog,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(
              Icons.add,
              color: Colors.grey[500],
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add\nCategory',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    // TODO: Show add category dialog
    Navigator.pop(context);
  }
}
