import '../../../../core/network/api_client.dart';
import '../models/transaction_model.dart';

abstract class TransactionRemoteDataSource {
  Future<TransactionListResponse> getTransactions(TransactionFilter filter);
  Future<List<TransactionModel>> getRecentTransactions({int count = 5});
  Future<TransactionModel> getTransactionById(String id);
  Future<TransactionModel> createTransaction(TransactionModel transaction);
  Future<TransactionModel> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final ApiClient apiClient;

  TransactionRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<TransactionListResponse> getTransactions(TransactionFilter filter) async {
    final response = await apiClient.get(
      '/Transaction',
      queryParameters: filter.toQueryParams(),
    );
    return TransactionListResponse.fromJson(response.data);
  }

  @override
  Future<List<TransactionModel>> getRecentTransactions({int count = 5}) async {
    final response = await apiClient.get(
      '/Transaction/recent',
      queryParameters: {'count': count},
    );
    final List<dynamic> data = response.data ?? [];
    return data.map((json) => TransactionModel.fromJson(json)).toList();
  }

  @override
  Future<TransactionModel> getTransactionById(String id) async {
    final response = await apiClient.get('/Transaction/$id');
    return TransactionModel.fromJson(response.data);
  }

  @override
  Future<TransactionModel> createTransaction(TransactionModel transaction) async {
    final response = await apiClient.post(
      '/Transaction',
      data: transaction.toJson(),
    );
    return TransactionModel.fromJson(response.data);
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) async {
    final response = await apiClient.put(
      '/Transaction/${transaction.id}',
      data: transaction.toJson(),
    );
    return TransactionModel.fromJson(response.data);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await apiClient.delete('/Transaction/$id');
  }
}
