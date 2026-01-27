import 'package:uuid/uuid.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_local_datasource.dart';
import '../datasources/wallet_remote_datasource.dart';
import '../models/wallet_model.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;
  final WalletLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  WalletRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<List<Wallet>> getWallets() async {
    if (await networkInfo.checkConnection()) {
      try {
        final remoteWallets = await remoteDataSource.getWallets();
        await localDataSource.saveWallets(remoteWallets);
        return remoteWallets;
      } catch (e) {
        return localDataSource.getWallets();
      }
    }
    return localDataSource.getWallets();
  }

  @override
  Future<Wallet?> getWalletById(String id) async {
    return localDataSource.getWalletById(id);
  }

  @override
  Future<Wallet> createWallet(Wallet wallet) async {
    final now = DateTime.now();
    final newWallet = WalletModel(
      id: wallet.id.isEmpty ? const Uuid().v4() : wallet.id,
      name: wallet.name,
      initialBalance: wallet.initialBalance,
      balance: wallet.balance,
      currency: wallet.currency,
      type: wallet.type,
      isDeleted: false,
      lastUpdatedAt: now,
      isSynced: false,
    );

    // Save locally first
    await localDataSource.saveWallet(newWallet);

    // Try to sync with server
    if (await networkInfo.checkConnection()) {
      try {
        final remoteWallet = await remoteDataSource.createWallet(newWallet);
        await localDataSource.saveWallet(WalletModel.fromEntity(
          remoteWallet.copyWith(isSynced: true),
        ));
        return remoteWallet;
      } catch (e) {
        // Keep local version
      }
    }

    return newWallet;
  }

  @override
  Future<Wallet> updateWallet(Wallet wallet) async {
    final updatedWallet = WalletModel(
      id: wallet.id,
      name: wallet.name,
      initialBalance: wallet.initialBalance,
      balance: wallet.balance,
      currency: wallet.currency,
      type: wallet.type,
      isDeleted: wallet.isDeleted,
      lastUpdatedAt: DateTime.now(),
      isSynced: false,
    );

    await localDataSource.saveWallet(updatedWallet);

    if (await networkInfo.checkConnection()) {
      try {
        final remoteWallet = await remoteDataSource.updateWallet(updatedWallet);
        await localDataSource.markAsSynced(wallet.id);
        return remoteWallet;
      } catch (e) {
        // Keep local version
      }
    }

    return updatedWallet;
  }

  @override
  Future<void> deleteWallet(String id) async {
    await localDataSource.deleteWallet(id);

    if (await networkInfo.checkConnection()) {
      try {
        await remoteDataSource.deleteWallet(id);
        await localDataSource.markAsSynced(id);
      } catch (e) {
        // Will sync later
      }
    }
  }

  @override
  Future<double> getTotalBalance() async {
    return localDataSource.getTotalBalance();
  }

  @override
  Future<void> syncWallets() async {
    if (!await networkInfo.checkConnection()) return;

    final unsyncedWallets = await localDataSource.getUnsyncedWallets();
    for (final wallet in unsyncedWallets) {
      try {
        if (wallet.isDeleted) {
          await remoteDataSource.deleteWallet(wallet.id);
        } else {
          await remoteDataSource.updateWallet(wallet);
        }
        await localDataSource.markAsSynced(wallet.id);
      } catch (e) {
        // Skip this wallet, try again later
      }
    }

    // Pull fresh data from server
    try {
      final remoteWallets = await remoteDataSource.getWallets();
      await localDataSource.saveWallets(remoteWallets);
    } catch (e) {
      // Ignore
    }
  }
}
