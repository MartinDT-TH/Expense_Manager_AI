import 'package:equatable/equatable.dart';
import '../../domain/entities/transaction.dart';
import '../../data/models/transaction_model.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionLoaded extends TransactionState {
  final List<Transaction> transactions;
  final List<Transaction> expenses;
  final List<Transaction> incomes;
  final TransactionFilter currentFilter;
  final int totalCount;
  final int totalPages;
  final double totalIncome;
  final double totalExpense;
  final bool hasMore;

  const TransactionLoaded({
    required this.transactions,
    required this.expenses,
    required this.incomes,
    required this.currentFilter,
    required this.totalCount,
    required this.totalPages,
    required this.totalIncome,
    required this.totalExpense,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [
    transactions, 
    expenses, 
    incomes, 
    currentFilter, 
    totalCount,
    totalPages,
    totalIncome,
    totalExpense,
    hasMore,
  ];
}

class TransactionLoadingMore extends TransactionLoaded {
  const TransactionLoadingMore({
    required super.transactions,
    required super.expenses,
    required super.incomes,
    required super.currentFilter,
    required super.totalCount,
    required super.totalPages,
    required super.totalIncome,
    required super.totalExpense,
    super.hasMore,
  });
}

class TransactionOperationSuccess extends TransactionState {
  final String message;
  final List<Transaction> transactions;

  const TransactionOperationSuccess({
    required this.message,
    required this.transactions,
  });

  @override
  List<Object?> get props => [message, transactions];
}

class TransactionCreated extends TransactionState {
  final Transaction transaction;
  final String message;

  const TransactionCreated({
    required this.transaction,
    this.message = 'Transaction created successfully',
  });

  @override
  List<Object?> get props => [transaction, message];
}

class TransactionError extends TransactionState {
  final String message;
  final List<Transaction>? previousTransactions;

  const TransactionError({
    required this.message,
    this.previousTransactions,
  });

  @override
  List<Object?> get props => [message, previousTransactions];
}

/// State for recent transactions (dashboard)
class RecentTransactionsLoaded extends TransactionState {
  final List<Transaction> recentTransactions;

  const RecentTransactionsLoaded({required this.recentTransactions});

  @override
  List<Object?> get props => [recentTransactions];
}
