import 'package:equatable/equatable.dart';
import '../../data/models/budget_model.dart';

abstract class BudgetEvent extends Equatable {
  const BudgetEvent();

  @override
  List<Object?> get props => [];
}

class BudgetsLoadRequested extends BudgetEvent {
  const BudgetsLoadRequested();
}

class ActiveBudgetsLoadRequested extends BudgetEvent {
  const ActiveBudgetsLoadRequested();
}

class CurrentMonthBudgetLoadRequested extends BudgetEvent {
  const CurrentMonthBudgetLoadRequested();
}

class BudgetWarningsLoadRequested extends BudgetEvent {
  const BudgetWarningsLoadRequested();
}

class BudgetCreateRequested extends BudgetEvent {
  final CreateBudgetRequest request;

  const BudgetCreateRequested({required this.request});

  @override
  List<Object?> get props => [request];
}

class BudgetUpdateRequested extends BudgetEvent {
  final String id;
  final UpdateBudgetRequest request;

  const BudgetUpdateRequested({required this.id, required this.request});

  @override
  List<Object?> get props => [id, request];
}

class BudgetDeleteRequested extends BudgetEvent {
  final String id;

  const BudgetDeleteRequested({required this.id});

  @override
  List<Object?> get props => [id];
}
