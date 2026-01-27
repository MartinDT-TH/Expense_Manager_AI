import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;

  TransactionRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<TransactionListResponse> getTransactions(TransactionFilter filter) async {
    return await remoteDataSource.getTransactions(filter);
  }

  @override
  Future<List<Transaction>> getRecentTransactions({int count = 5}) async {
    return await remoteDataSource.getRecentTransactions(count: count);
  }

  @override
  Future<Transaction?> getTransactionById(String id) async {
    try {
      return await remoteDataSource.getTransactionById(id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    final model = TransactionModel.fromEntity(transaction);
    return await remoteDataSource.createTransaction(model);
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    final model = TransactionModel.fromEntity(transaction);
    return await remoteDataSource.updateTransaction(model);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await remoteDataSource.deleteTransaction(id);
  }
}
