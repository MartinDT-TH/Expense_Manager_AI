import '../entities/wallet.dart';
import '../repositories/wallet_repository.dart';

class GetWalletsUseCase {
  final WalletRepository repository;

  GetWalletsUseCase(this.repository);

  Future<List<Wallet>> call() {
    return repository.getWallets();
  }
}

class GetWalletByIdUseCase {
  final WalletRepository repository;

  GetWalletByIdUseCase(this.repository);

  Future<Wallet?> call(String id) {
    return repository.getWalletById(id);
  }
}

class CreateWalletUseCase {
  final WalletRepository repository;

  CreateWalletUseCase(this.repository);

  Future<Wallet> call(Wallet wallet) {
    return repository.createWallet(wallet);
  }
}

class UpdateWalletUseCase {
  final WalletRepository repository;

  UpdateWalletUseCase(this.repository);

  Future<Wallet> call(Wallet wallet) {
    return repository.updateWallet(wallet);
  }
}

class DeleteWalletUseCase {
  final WalletRepository repository;

  DeleteWalletUseCase(this.repository);

  Future<void> call(String id) {
    return repository.deleteWallet(id);
  }
}

class GetTotalBalanceUseCase {
  final WalletRepository repository;

  GetTotalBalanceUseCase(this.repository);

  Future<double> call() {
    return repository.getTotalBalance();
  }
}
