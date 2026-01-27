import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/budget_repository.dart';
import 'budget_event.dart';
import 'budget_state.dart';

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final BudgetRepository _repository;

  BudgetBloc({required BudgetRepository repository})
      : _repository = repository,
        super(const BudgetInitial()) {
    on<BudgetsLoadRequested>(_onBudgetsLoadRequested);
    on<ActiveBudgetsLoadRequested>(_onActiveBudgetsLoadRequested);
    on<CurrentMonthBudgetLoadRequested>(_onCurrentMonthBudgetLoadRequested);
    on<BudgetWarningsLoadRequested>(_onBudgetWarningsLoadRequested);
    on<BudgetCreateRequested>(_onBudgetCreateRequested);
    on<BudgetUpdateRequested>(_onBudgetUpdateRequested);
    on<BudgetDeleteRequested>(_onBudgetDeleteRequested);
  }

  Future<void> _onBudgetsLoadRequested(
    BudgetsLoadRequested event,
    Emitter<BudgetState> emit,
  ) async {
    emit(const BudgetLoading());
    try {
      final budgets = await _repository.getBudgets();
      final activeBudgets = await _repository.getActiveBudgets();
      final currentMonthBudget = await _repository.getCurrentMonthBudget();
      emit(BudgetLoaded(
        budgets: budgets, 
        activeBudgets: activeBudgets,
        currentMonthBudget: currentMonthBudget,
      ));
    } catch (e) {
      emit(BudgetError(message: e.toString()));
    }
  }

  Future<void> _onActiveBudgetsLoadRequested(
    ActiveBudgetsLoadRequested event,
    Emitter<BudgetState> emit,
  ) async {
    emit(const BudgetLoading());
    try {
      final activeBudgets = await _repository.getActiveBudgets();
      emit(BudgetLoaded(activeBudgets: activeBudgets));
    } catch (e) {
      emit(BudgetError(message: e.toString()));
    }
  }

  Future<void> _onCurrentMonthBudgetLoadRequested(
    CurrentMonthBudgetLoadRequested event,
    Emitter<BudgetState> emit,
  ) async {
    try {
      final budget = await _repository.getCurrentMonthBudget();
      emit(CurrentMonthBudgetLoaded(budget: budget, hasBudget: budget != null));
    } catch (e) {
      emit(CurrentMonthBudgetLoaded(budget: null, hasBudget: false));
    }
  }

  Future<void> _onBudgetWarningsLoadRequested(
    BudgetWarningsLoadRequested event,
    Emitter<BudgetState> emit,
  ) async {
    try {
      final warnings = await _repository.getBudgetWarnings();
      if (state is BudgetLoaded) {
        emit((state as BudgetLoaded).copyWith(warnings: warnings));
      } else {
        emit(BudgetLoaded(warnings: warnings));
      }
    } catch (e) {
      emit(BudgetError(message: e.toString()));
    }
  }

  Future<void> _onBudgetCreateRequested(
    BudgetCreateRequested event,
    Emitter<BudgetState> emit,
  ) async {
    emit(const BudgetLoading());
    try {
      final budget = await _repository.createBudget(event.request);
      emit(BudgetOperationSuccess(message: 'Budget created successfully!', budget: budget));
      // Reload budgets
      add(const BudgetsLoadRequested());
    } catch (e) {
      emit(BudgetError(message: e.toString()));
    }
  }

  Future<void> _onBudgetUpdateRequested(
    BudgetUpdateRequested event,
    Emitter<BudgetState> emit,
  ) async {
    emit(const BudgetLoading());
    try {
      final budget = await _repository.updateBudget(event.id, event.request);
      emit(BudgetOperationSuccess(message: 'Budget updated successfully!', budget: budget));
      // Reload budgets
      add(const BudgetsLoadRequested());
    } catch (e) {
      emit(BudgetError(message: e.toString()));
    }
  }

  Future<void> _onBudgetDeleteRequested(
    BudgetDeleteRequested event,
    Emitter<BudgetState> emit,
  ) async {
    emit(const BudgetLoading());
    try {
      await _repository.deleteBudget(event.id);
      emit(const BudgetOperationSuccess(message: 'Budget deleted successfully!'));
      // Reload budgets
      add(const BudgetsLoadRequested());
    } catch (e) {
      emit(BudgetError(message: e.toString()));
    }
  }
}
