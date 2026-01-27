import '../../domain/entities/wallet.dart';

class WalletModel extends Wallet {
  const WalletModel({
    required super.id,
    required super.name,
    super.initialBalance,
    super.balance,
    super.currency,
    super.type,
    super.isDeleted,
    required super.lastUpdatedAt,
    super.isSynced,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      initialBalance: (json['initialBalance'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'VND',
      type: json['type'] ?? 'CASH',
      isDeleted: json['isDeleted'] ?? false,
      lastUpdatedAt: json['lastUpdatedAt'] != null 
          ? DateTime.parse(json['lastUpdatedAt']) 
          : DateTime.now(),
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'initialBalance': initialBalance,
      'balance': balance,
      'currency': currency,
      'type': type,
    };
  }

  factory WalletModel.fromDatabase(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'],
      name: map['name'],
      initialBalance: map['initial_balance']?.toDouble() ?? 0,
      balance: map['balance']?.toDouble() ?? 0,
      currency: map['currency'] ?? 'VND',
      type: map['type'] ?? 'CASH',
      isDeleted: map['is_deleted'] == 1,
      lastUpdatedAt: DateTime.parse(map['last_updated_at']),
      isSynced: map['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'initial_balance': initialBalance,
      'balance': balance,
      'currency': currency,
      'type': type,
      'is_deleted': isDeleted ? 1 : 0,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory WalletModel.fromEntity(Wallet wallet) {
    return WalletModel(
      id: wallet.id,
      name: wallet.name,
      initialBalance: wallet.initialBalance,
      balance: wallet.balance,
      currency: wallet.currency,
      type: wallet.type,
      isDeleted: wallet.isDeleted,
      lastUpdatedAt: wallet.lastUpdatedAt,
      isSynced: wallet.isSynced,
    );
  }
}
