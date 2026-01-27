import '../entities/transaction.dart';
import '../../data/models/transaction_model.dart';

abstract class TransactionRepository {
  Future<TransactionListResponse> getTransactions(TransactionFilter filter);
  Future<List<Transaction>> getRecentTransactions({int count = 5});
  Future<Transaction?> getTransactionById(String id);
  Future<Transaction> createTransaction(Transaction transaction);
  Future<Transaction> updateTransaction(Transaction transaction);
  Future<void> deleteTransaction(String id);
}
