import 'package:equatable/equatable.dart';
import '../../data/models/budget_model.dart';

abstract class BudgetState extends Equatable {
  const BudgetState();

  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {
  const BudgetInitial();
}

class BudgetLoading extends BudgetState {
  const BudgetLoading();
}

class BudgetLoaded extends BudgetState {
  final List<BudgetModel> budgets;
  final List<BudgetModel> activeBudgets;
  final BudgetModel? currentMonthBudget;
  final BudgetWarningResponse? warnings;

  const BudgetLoaded({
    this.budgets = const [],
    this.activeBudgets = const [],
    this.currentMonthBudget,
    this.warnings,
  });

  @override
  List<Object?> get props => [budgets, activeBudgets, currentMonthBudget, warnings];

  BudgetLoaded copyWith({
    List<BudgetModel>? budgets,
    List<BudgetModel>? activeBudgets,
    BudgetModel? currentMonthBudget,
    BudgetWarningResponse? warnings,
    bool clearCurrentMonthBudget = false,
  }) {
    return BudgetLoaded(
      budgets: budgets ?? this.budgets,
      activeBudgets: activeBudgets ?? this.activeBudgets,
      currentMonthBudget: clearCurrentMonthBudget ? null : (currentMonthBudget ?? this.currentMonthBudget),
      warnings: warnings ?? this.warnings,
    );
  }
}

class CurrentMonthBudgetLoaded extends BudgetState {
  final BudgetModel? budget;
  final bool hasBudget;

  const CurrentMonthBudgetLoaded({this.budget, this.hasBudget = false});

  @override
  List<Object?> get props => [budget, hasBudget];
}

class BudgetOperationSuccess extends BudgetState {
  final String message;
  final BudgetModel? budget;

  const BudgetOperationSuccess({required this.message, this.budget});

  @override
  List<Object?> get props => [message, budget];
}

class BudgetError extends BudgetState {
  final String message;

  const BudgetError({required this.message});

  @override
  List<Object?> get props => [message];
}
