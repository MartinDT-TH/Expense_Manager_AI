import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/category_icons.dart';
import '../../domain/entities/category.dart';

class AddCategoryDialog extends StatefulWidget {
  final Category? category; // null for create, non-null for edit
  final CategoryType categoryType;
  final void Function(String name, String iconCode, CategoryType type) onSave;

  const AddCategoryDialog({
    super.key,
    this.category,
    required this.categoryType,
    required this.onSave,
  });

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedIconCode;
  late CategoryType _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedIconCode = widget.category?.iconCode ?? 'shopping_cart';
    _selectedType = widget.category?.type ?? widget.categoryType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24, 
                  24, 
                  24, 
                  keyboardHeight > 0 ? 8 : 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Sửa danh mục' : 'Thêm danh mục mới',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên danh mục',
                          hintText: 'vd. Ăn uống',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập tên danh mục';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category type selector (only for new categories)
                      if (!isEditing) ...[  
                        Text(
                          'Loại',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TypeChip(
                                label: 'Chi tiêu',
                                isSelected: _selectedType == CategoryType.expense,
                                color: AppColors.expense,
                                onTap: () => setState(() => _selectedType = CategoryType.expense),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TypeChip(
                                label: 'Thu nhập',
                                isSelected: _selectedType == CategoryType.income,
                                color: AppColors.income,
                                onTap: () => setState(() => _selectedType = CategoryType.income),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Icon selector
                      Text(
                        'Biểu tượng',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: keyboardHeight > 0 ? 100 : 180,
                        child: _IconGrid(
                          selectedIconCode: _selectedIconCode,
                          categoryType: _selectedType,
                          onIconSelected: (iconCode) {
                            setState(() => _selectedIconCode = iconCode);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions - fixed at bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isEditing ? 'Lưu' : 'Thêm'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        _nameController.text.trim(),
        _selectedIconCode,
        _selectedType,
      );
      Navigator.pop(context);
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconGrid extends StatefulWidget {
  final String selectedIconCode;
  final CategoryType categoryType;
  final void Function(String) onIconSelected;

  const _IconGrid({
    required this.selectedIconCode,
    required this.categoryType,
    required this.onIconSelected,
  });

  @override
  State<_IconGrid> createState() => _IconGridState();
}

class _IconGridState extends State<_IconGrid> {
  String _selectedGroup = CategoryIcons.groupNames.first;

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryType == CategoryType.expense
        ? AppColors.expense
        : AppColors.income;
    final groupNames = CategoryIcons.groupNames;
    final iconsInGroup = CategoryIcons.iconGroups[_selectedGroup] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group selector - horizontal scrollable chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groupNames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final groupName = groupNames[index];
              final isSelected = groupName == _selectedGroup;
              return GestureDetector(
                onTap: () => setState(() => _selectedGroup = groupName),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? color : Colors.grey[600],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Icons grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: iconsInGroup.length,
            itemBuilder: (context, index) {
              final iconCode = iconsInGroup[index];
              final isSelected = iconCode == widget.selectedIconCode;

              return GestureDetector(
                onTap: () => widget.onIconSelected(iconCode),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    CategoryIcons.getIcon(iconCode),
                    color: isSelected ? color : Colors.grey[600],
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
