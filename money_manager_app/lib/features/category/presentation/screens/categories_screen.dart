import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/category.dart';
import '../bloc/category_bloc.dart';
import '../bloc/category_event.dart';
import '../bloc/category_state.dart';
import '../widgets/category_tile.dart';
import '../widgets/add_category_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<CategoryBloc>().add(const LoadCategories());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
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
        title: const Text(
          'Categories',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_upward, size: 18),
                  SizedBox(width: 4),
                  Text('Expense'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_downward, size: 18),
                  SizedBox(width: 4),
                  Text('Income'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () => _showAddCategoryDialog(context),
            tooltip: 'Add Category',
          ),
        ],
      ),
      body: BlocConsumer<CategoryBloc, CategoryState>(
        listener: (context, state) {
          if (state is CategoryOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is CategoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CategoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CategoryLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(state.expenseCategories, CategoryType.expense),
                _buildCategoryList(state.incomeCategories, CategoryType.income),
              ],
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No categories available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        backgroundColor: const Color(0xFF6C5CE7),
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, CategoryType type) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (type == CategoryType.expense
                        ? AppColors.expense
                        : AppColors.income)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == CategoryType.expense
                    ? Icons.shopping_cart_outlined
                    : Icons.account_balance_wallet_outlined,
                size: 48,
                color: type == CategoryType.expense
                    ? AppColors.expense
                    : AppColors.income,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              type == CategoryType.expense
                  ? 'No expense categories yet'
                  : 'No income categories yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create one',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    // Separate system and custom categories
    final systemCategories = categories.where((c) => c.isSystem).toList();
    final customCategories = categories.where((c) => !c.isSystem).toList();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CategoryBloc>().add(const LoadCategories());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // System Categories Section
          if (systemCategories.isNotEmpty) ...[
            _buildSectionHeader(
              'Default Categories',
              Icons.lock_outline,
              'System categories cannot be edited',
              systemCategories.length,
            ),
            const SizedBox(height: 8),
            ...systemCategories.map(
              (category) => CategoryTile(
                category: category,
                onTap: () => _showCategoryOptions(context, category),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Custom Categories Section
          if (customCategories.isNotEmpty) ...[
            _buildSectionHeader(
              'My Categories',
              Icons.person_outline,
              'Custom categories created by you',
              customCategories.length,
            ),
            const SizedBox(height: 8),
            ...customCategories.map(
              (category) => CategoryTile(
                category: category,
                onTap: () => _showCategoryOptions(context, category),
              ),
            ),
          ],
          
          // Empty custom section with hint
          if (customCategories.isEmpty && systemCategories.isNotEmpty) ...[
            _buildSectionHeader(
              'My Categories',
              Icons.person_outline,
              'Create your own custom categories',
              0,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No custom categories yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the + button to create one',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, 
    IconData icon, 
    String subtitle,
    int count,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFF6C5CE7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final categoryType = _tabController.index == 0
        ? CategoryType.expense
        : CategoryType.income;
    
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
        },
      ),
    );
  }

  void _showCategoryOptions(BuildContext context, Category category) {
    if (category.isSystem) {
      // System categories cannot be edited
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit system categories'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showEditCategoryDialog(context, category);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _confirmDeleteCategory(context, category);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddCategoryDialog(
        category: category,
        categoryType: category.type,
        onSave: (name, iconCode, type) {
          context.read<CategoryBloc>().add(UpdateCategory(
                category.copyWith(
                  name: name,
                  iconCode: iconCode,
                ),
              ));
        },
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CategoryBloc>().add(DeleteCategory(category.id));
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
