import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../data/models/transaction_model.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository repository;
  
  TransactionFilter _currentFilter = TransactionFilter();
  List<Transaction> _allTransactions = [];

  TransactionBloc({required this.repository}) : super(TransactionInitial()) {
    on<TransactionsLoadRequested>(_onLoadRequested);
    on<TransactionsLoadMoreRequested>(_onLoadMoreRequested);
    on<RecentTransactionsLoadRequested>(_onRecentLoadRequested);
    on<TransactionFilterChanged>(_onFilterChanged);
    on<TransactionCreateRequested>(_onCreateRequested);
    on<TransactionDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    TransactionsLoadRequested event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    try {
      _currentFilter = event.filter;
      final response = await repository.getTransactions(_currentFilter);
      _allTransactions = response.items;
      
      final expenses = _allTransactions
          .where((t) => t.type == TransactionType.expense)
          .toList();
      final incomes = _allTransactions
          .where((t) => t.type == TransactionType.income)
          .toList();

      emit(TransactionLoaded(
        transactions: _allTransactions,
        expenses: expenses,
        incomes: incomes,
        currentFilter: _currentFilter,
        totalCount: response.totalCount,
        totalPages: response.totalPages,
        totalIncome: response.totalIncome,
        totalExpense: response.totalExpense,
        hasMore: response.page < response.totalPages,
      ));
    } catch (e) {
      emit(TransactionError(message: 'Không thể tải giao dịch: ${e.toString()}'));
    }
  }

  Future<void> _onLoadMoreRequested(
    TransactionsLoadMoreRequested event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    if (currentState is TransactionLoaded && currentState.hasMore) {
      emit(TransactionLoadingMore(
        transactions: currentState.transactions,
        expenses: currentState.expenses,
        incomes: currentState.incomes,
        currentFilter: currentState.currentFilter,
        totalCount: currentState.totalCount,
        totalPages: currentState.totalPages,
        totalIncome: currentState.totalIncome,
        totalExpense: currentState.totalExpense,
        hasMore: currentState.hasMore,
      ));

      try {
        final nextFilter = _currentFilter.copyWith(page: _currentFilter.page + 1);
        final response = await repository.getTransactions(nextFilter);
        
        _currentFilter = nextFilter;
        _allTransactions.addAll(response.items);
        
        final expenses = _allTransactions
            .where((t) => t.type == TransactionType.expense)
            .toList();
        final incomes = _allTransactions
            .where((t) => t.type == TransactionType.income)
            .toList();

        emit(TransactionLoaded(
          transactions: _allTransactions,
          expenses: expenses,
          incomes: incomes,
          currentFilter: _currentFilter,
          totalCount: response.totalCount,
          totalPages: response.totalPages,
          totalIncome: response.totalIncome,
          totalExpense: response.totalExpense,
          hasMore: response.page < response.totalPages,
        ));
      } catch (e) {
        emit(TransactionError(
          message: 'Không thể tải thêm giao dịch: ${e.toString()}',
          previousTransactions: _allTransactions,
        ));
      }
    }
  }

  Future<void> _onRecentLoadRequested(
    RecentTransactionsLoadRequested event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());
    try {
      final recentTransactions = await repository.getRecentTransactions(count: event.count);
      emit(RecentTransactionsLoaded(recentTransactions: recentTransactions));
    } catch (e) {
      emit(TransactionError(message: 'Không thể tải giao dịch gần đây: ${e.toString()}'));
    }
  }

  Future<void> _onFilterChanged(
    TransactionFilterChanged event,
    Emitter<TransactionState> emit,
  ) async {
    add(TransactionsLoadRequested(filter: event.filter));
  }

  Future<void> _onCreateRequested(
    TransactionCreateRequested event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      // Convert TransactionModel to Transaction entity for repository
      final transactionModel = event.transaction;
      final newTransaction = Transaction(
        id: transactionModel.id,
        amount: transactionModel.amount,
        type: transactionModel.type,
        categoryId: transactionModel.categoryId,
        categoryName: transactionModel.categoryName,
        categoryIcon: transactionModel.categoryIcon,
        walletId: transactionModel.walletId,
        walletName: transactionModel.walletName,
        note: transactionModel.note,
        transactionDate: transactionModel.transactionDate,
        receiptUrl: transactionModel.receiptUrl,
        groupId: transactionModel.groupId, // Add groupId
        groupName: transactionModel.groupName, // Add groupName
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await repository.createTransaction(newTransaction);
      
      // Emit created state for success feedback
      emit(TransactionCreated(transaction: newTransaction));
    } catch (e) {
      emit(TransactionError(
        message: 'Không thể tạo giao dịch: ${e.toString()}',
        previousTransactions: _allTransactions,
      ));
    }
  }

  Future<void> _onDeleteRequested(
    TransactionDeleteRequested event,
    Emitter<TransactionState> emit,
  ) async {
    final previousTransactions = List<Transaction>.from(_allTransactions);
    emit(TransactionLoading());
    
    try {
      await repository.deleteTransaction(event.id);
      
      // Reload transactions
      final response = await repository.getTransactions(_currentFilter);
      _allTransactions = response.items;
      
      final expenses = _allTransactions
          .where((t) => t.type == TransactionType.expense)
          .toList();
      final incomes = _allTransactions
          .where((t) => t.type == TransactionType.income)
          .toList();

      emit(TransactionOperationSuccess(
        message: 'Xóa giao dịch thành công!',
        transactions: _allTransactions,
      ));
      
      emit(TransactionLoaded(
        transactions: _allTransactions,
        expenses: expenses,
        incomes: incomes,
        currentFilter: _currentFilter,
        totalCount: response.totalCount,
        totalPages: response.totalPages,
        totalIncome: response.totalIncome,
        totalExpense: response.totalExpense,
        hasMore: response.page < response.totalPages,
      ));
    } catch (e) {
      emit(TransactionError(
        message: 'Không thể xóa giao dịch: ${e.toString()}',
        previousTransactions: previousTransactions,
      ));
    }
  }
}
