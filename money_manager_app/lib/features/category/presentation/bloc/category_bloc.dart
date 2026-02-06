import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/category.dart';
import '../../domain/usecases/category_usecases.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final GetCategoriesUseCase getCategoriesUseCase;
  final GetExpenseCategoriesUseCase getExpenseCategoriesUseCase;
  final GetIncomeCategoriesUseCase getIncomeCategoriesUseCase;
  final CreateCategoryUseCase createCategoryUseCase;
  final UpdateCategoryUseCase updateCategoryUseCase;
  final DeleteCategoryUseCase deleteCategoryUseCase;

  CategoryBloc({
    required this.getCategoriesUseCase,
    required this.getExpenseCategoriesUseCase,
    required this.getIncomeCategoriesUseCase,
    required this.createCategoryUseCase,
    required this.updateCategoryUseCase,
    required this.deleteCategoryUseCase,
  }) : super(const CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<LoadCategoriesByType>(_onLoadCategoriesByType);
    on<CreateCategory>(_onCreateCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<CategoryState> emit,
  ) async {
    emit(const CategoryLoading());

    final result = await getCategoriesUseCase();
    
    result.fold(
      (failure) => emit(CategoryError(failure.message)),
      (categories) {
        final income = categories
            .where((c) => c.type == CategoryType.income)
            .toList();
        final expense = categories
            .where((c) => c.type == CategoryType.expense)
            .toList();
        
        emit(CategoryLoaded(
          categories: categories,
          incomeCategories: income,
          expenseCategories: expense,
        ));
      },
    );
  }

  Future<void> _onLoadCategoriesByType(
    LoadCategoriesByType event,
    Emitter<CategoryState> emit,
  ) async {
    emit(const CategoryLoading());

    final allResult = await getCategoriesUseCase();
    
    allResult.fold(
      (failure) => emit(CategoryError(failure.message)),
      (categories) {
        final income = categories
            .where((c) => c.type == CategoryType.income)
            .toList();
        final expense = categories
            .where((c) => c.type == CategoryType.expense)
            .toList();
        
        emit(CategoryLoaded(
          categories: event.type == CategoryType.income ? income : expense,
          incomeCategories: income,
          expenseCategories: expense,
        ));
      },
    );
  }

  Future<void> _onCreateCategory(
    CreateCategory event,
    Emitter<CategoryState> emit,
  ) async {
    emit(const CategoryLoading());

    final now = DateTime.now();
    final category = Category(
      id: '',
      name: event.name,
      iconCode: event.iconCode,
      type: event.type,
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    );

    final result = await createCategoryUseCase(category);

    result.fold(
      (failure) => emit(CategoryError(failure.message)),
      (createdCategory) {
        emit(CategoryOperationSuccess(
          message: 'Đã tạo danh mục "${createdCategory.name}"',
          category: createdCategory,
        ));
        // Reload categories
        add(const LoadCategories());
      },
    );
  }

  Future<void> _onUpdateCategory(
    UpdateCategory event,
    Emitter<CategoryState> emit,
  ) async {
    emit(const CategoryLoading());

    final result = await updateCategoryUseCase(event.category);

    result.fold(
      (failure) => emit(CategoryError(failure.message)),
      (updatedCategory) {
        emit(CategoryOperationSuccess(
          message: 'Đã cập nhật danh mục "${updatedCategory.name}"',
          category: updatedCategory,
        ));
        // Reload categories
        add(const LoadCategories());
      },
    );
  }

  Future<void> _onDeleteCategory(
    DeleteCategory event,
    Emitter<CategoryState> emit,
  ) async {
    emit(const CategoryLoading());

    final result = await deleteCategoryUseCase(event.id);

    result.fold(
      (failure) => emit(CategoryError(failure.message)),
      (_) {
        emit(const CategoryOperationSuccess(
          message: 'Đã xóa danh mục',
        ));
        // Reload categories
        add(const LoadCategories());
      },
    );
  }
}
