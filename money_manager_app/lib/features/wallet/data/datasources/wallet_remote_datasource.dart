import '../../../../core/network/api_client.dart';
import '../models/wallet_model.dart';

abstract class WalletRemoteDataSource {
  Future<List<WalletModel>> getWallets();
  Future<WalletModel> createWallet(WalletModel wallet);
  Future<WalletModel> updateWallet(WalletModel wallet);
  Future<void> deleteWallet(String id);
  Future<double> getTotalBalance();
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final ApiClient apiClient;

  WalletRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<WalletModel>> getWallets() async {
    final response = await apiClient.get('/Wallet');
    final List<dynamic> data = response.data ?? [];
    return data.map((json) => WalletModel.fromJson(json)).toList();
  }

  @override
  Future<WalletModel> createWallet(WalletModel wallet) async {
    final response = await apiClient.post('/Wallet', data: wallet.toJson());
    return WalletModel.fromJson(response.data);
  }

  @override
  Future<WalletModel> updateWallet(WalletModel wallet) async {
    final response = await apiClient.put('/Wallet/${wallet.id}', data: wallet.toJson());
    return WalletModel.fromJson(response.data);
  }

  @override
  Future<void> deleteWallet(String id) async {
    await apiClient.delete('/Wallet/$id');
  }

  @override
  Future<double> getTotalBalance() async {
    final response = await apiClient.get('/Wallet/total-balance');
    return (response.data['totalBalance'] as num?)?.toDouble() ?? 0;
  }
}
