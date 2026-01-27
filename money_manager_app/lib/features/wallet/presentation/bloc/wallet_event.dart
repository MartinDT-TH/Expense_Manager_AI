import 'package:equatable/equatable.dart';
import '../../domain/entities/wallet.dart';

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class WalletsLoadRequested extends WalletEvent {}

class WalletCreateRequested extends WalletEvent {
  final String name;
  final double initialBalance;
  final String currency;
  final String type;

  const WalletCreateRequested({
    required this.name,
    this.initialBalance = 0,
    this.currency = 'VND',
    this.type = 'CASH',
  });

  @override
  List<Object?> get props => [name, initialBalance, currency, type];
}

class WalletUpdateRequested extends WalletEvent {
  final Wallet wallet;

  const WalletUpdateRequested({required this.wallet});

  @override
  List<Object?> get props => [wallet];
}

class WalletDeleteRequested extends WalletEvent {
  final String id;

  const WalletDeleteRequested({required this.id});

  @override
  List<Object?> get props => [id];
}

class WalletSyncRequested extends WalletEvent {}
