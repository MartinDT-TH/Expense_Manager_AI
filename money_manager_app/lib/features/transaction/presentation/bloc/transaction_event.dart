import 'package:equatable/equatable.dart';
import '../../data/models/transaction_model.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

/// Load transactions with filter
class TransactionsLoadRequested extends TransactionEvent {
  final TransactionFilter filter;

  const TransactionsLoadRequested({required this.filter});

  @override
  List<Object?> get props => [filter];
}

/// Load more transactions (pagination)
class TransactionsLoadMoreRequested extends TransactionEvent {
  const TransactionsLoadMoreRequested();
}

/// Load recent transactions (for dashboard)
class RecentTransactionsLoadRequested extends TransactionEvent {
  final int count;

  const RecentTransactionsLoadRequested({this.count = 5});

  @override
  List<Object?> get props => [count];
}

/// Update filter (wallet, date, type)
class TransactionFilterChanged extends TransactionEvent {
  final TransactionFilter filter;

  const TransactionFilterChanged({required this.filter});

  @override
  List<Object?> get props => [filter];
}

/// Create new transaction
class TransactionCreateRequested extends TransactionEvent {
  final TransactionModel transaction;

  const TransactionCreateRequested(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

/// Delete transaction
class TransactionDeleteRequested extends TransactionEvent {
  final String id;

  const TransactionDeleteRequested({required this.id});

  @override
  List<Object?> get props => [id];
}
