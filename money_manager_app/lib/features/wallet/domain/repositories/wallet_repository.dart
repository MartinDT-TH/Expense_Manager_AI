import '../entities/wallet.dart';

abstract class WalletRepository {
  Future<List<Wallet>> getWallets();
  Future<Wallet?> getWalletById(String id);
  Future<Wallet> createWallet(Wallet wallet);
  Future<Wallet> updateWallet(Wallet wallet);
  Future<void> deleteWallet(String id);
  Future<double> getTotalBalance();
  Future<void> syncWallets();
}
