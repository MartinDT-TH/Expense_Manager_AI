import 'package:equatable/equatable.dart';

enum TransactionType { income, expense }

class Transaction extends Equatable {
  final String id;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String walletId;
  final String? walletName;
  final String? groupId;
  final String? groupName;
  final String? note;
  final String? description;
  final DateTime transactionDate;
  final String? receiptUrl; // Cloudinary URL
  final String? location;
  final bool isRecurring;
  final String? recurringId;
  final String? createdByUserId;
  final String? createdByUserName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    required this.walletId,
    this.walletName,
    this.groupId,
    this.groupName,
    this.note,
    this.description,
    required this.transactionDate,
    this.receiptUrl,
    this.location,
    this.isRecurring = false,
    this.recurringId,
    this.createdByUserId,
    this.createdByUserName,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? walletId,
    String? walletName,
    String? groupId,
    String? groupName,
    String? note,
    String? description,
    DateTime? transactionDate,
    String? receiptUrl,
    String? location,
    bool? isRecurring,
    String? recurringId,
    String? createdByUserId,
    String? createdByUserName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      note: note ?? this.note,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      location: location ?? this.location,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringId: recurringId ?? this.recurringId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  List<Object?> get props => [
        id,
        amount,
        type,
        categoryId,
        categoryName,
        categoryIcon,
        walletId,
        walletName,
        groupId,
        groupName,
        note,
        description,
        transactionDate,
        receiptUrl,
        location,
        isRecurring,
        recurringId,
        createdByUserId,
        createdByUserName,
        createdAt,
        updatedAt,
        isSynced,
      ];
}
