import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  final String id;
  final String name;
  final double initialBalance; // Số dư ban đầu khi tạo ví
  final double balance; // Số dư hiện tại = initialBalance + income - expense
  final String currency;
  final String type;
  final bool isDeleted;
  final DateTime lastUpdatedAt;
  final bool isSynced;

  const Wallet({
    required this.id,
    required this.name,
    this.initialBalance = 0,
    this.balance = 0,
    this.currency = 'VND',
    this.type = 'CASH',
    this.isDeleted = false,
    required this.lastUpdatedAt,
    this.isSynced = false,
  });

  Wallet copyWith({
    String? id,
    String? name,
    double? initialBalance,
    double? balance,
    String? currency,
    String? type,
    bool? isDeleted,
    DateTime? lastUpdatedAt,
    bool? isSynced,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      initialBalance: initialBalance ?? this.initialBalance,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      isDeleted: isDeleted ?? this.isDeleted,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [id, name, initialBalance, balance, currency, type, isDeleted, lastUpdatedAt, isSynced];
}
