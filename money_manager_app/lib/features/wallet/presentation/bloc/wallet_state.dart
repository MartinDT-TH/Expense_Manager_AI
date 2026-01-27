import 'package:equatable/equatable.dart';
import '../../domain/entities/wallet.dart';

abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final List<Wallet> wallets;
  final double totalBalance;

  const WalletLoaded({
    required this.wallets,
    this.totalBalance = 0,
  });

  @override
  List<Object?> get props => [wallets, totalBalance];
}

class WalletOperationSuccess extends WalletState {
  final String message;
  final List<Wallet> wallets;
  final double totalBalance;

  const WalletOperationSuccess({
    required this.message,
    required this.wallets,
    this.totalBalance = 0,
  });

  @override
  List<Object?> get props => [message, wallets, totalBalance];
}

class WalletError extends WalletState {
  final String message;
  final List<Wallet>? previousWallets;

  const WalletError({required this.message, this.previousWallets});

  @override
  List<Object?> get props => [message, previousWallets];
}
