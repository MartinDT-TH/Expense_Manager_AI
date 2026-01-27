import '../../domain/entities/transaction.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.amount,
    required super.type,
    required super.categoryId,
    super.categoryName,
    super.categoryIcon,
    required super.walletId,
    super.walletName,
    super.groupId,
    super.groupName,
    super.note,
    super.description,
    required super.transactionDate,
    super.receiptUrl,
    super.location,
    super.isRecurring,
    super.recurringId,
    super.createdByUserId,
    super.createdByUserName,
    required super.createdAt,
    required super.updatedAt,
    super.isSynced,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final categoryType = json['categoryType']?.toString().toUpperCase() ?? 'EXPENSE';
    return TransactionModel(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: categoryType == 'INCOME' ? TransactionType.income : TransactionType.expense,
      categoryId: json['categoryId'] ?? '',
      categoryName: json['categoryName'],
      categoryIcon: json['categoryIcon'],
      walletId: json['walletId'] ?? '',
      walletName: json['walletName'],
      groupId: json['groupId'],
      groupName: json['groupName'],
      note: json['note'],
      description: json['note'], // Map note to description
      transactionDate: json['transactionDate'] != null
          ? DateTime.parse(json['transactionDate'])
          : DateTime.now(),
      receiptUrl: json['billImageUrl'],
      location: null,
      isRecurring: false,
      recurringId: null,
      createdByUserId: json['createdByUserId'],
      createdByUserName: json['createdByUserName'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['lastUpdatedAt'] != null
          ? DateTime.parse(json['lastUpdatedAt'])
          : DateTime.now(),
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'walletId': walletId,
      'groupId': groupId,
      'note': note ?? description,
      'transactionDate': transactionDate.toIso8601String(),
      'billImageUrl': receiptUrl,
    };
  }

  factory TransactionModel.fromDatabase(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] == 'INCOME' ? TransactionType.income : TransactionType.expense,
      categoryId: map['category_id'],
      categoryName: map['category_name'],
      categoryIcon: map['category_icon'],
      walletId: map['wallet_id'],
      walletName: map['wallet_name'],
      groupId: map['group_id'],
      groupName: map['group_name'],
      note: map['note'],
      description: map['note'],
      transactionDate: DateTime.parse(map['transaction_date']),
      receiptUrl: map['receipt_url'],
      location: map['location'],
      isRecurring: map['is_recurring'] == 1,
      recurringId: map['recurring_id'],
      createdByUserId: map['created_by_user_id'],
      createdByUserName: map['created_by_user_name'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      isSynced: map['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'amount': amount,
      'type': type == TransactionType.income ? 'INCOME' : 'EXPENSE',
      'category_id': categoryId,
      'category_name': categoryName,
      'category_icon': categoryIcon,
      'wallet_id': walletId,
      'wallet_name': walletName,
      'group_id': groupId,
      'group_name': groupName,
      'note': note ?? description,
      'transaction_date': transactionDate.toIso8601String(),
      'receipt_url': receiptUrl,
      'location': location,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_id': recurringId,
      'created_by_user_id': createdByUserId,
      'created_by_user_name': createdByUserName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory TransactionModel.fromEntity(Transaction transaction) {
    return TransactionModel(
      id: transaction.id,
      amount: transaction.amount,
      type: transaction.type,
      categoryId: transaction.categoryId,
      categoryName: transaction.categoryName,
      categoryIcon: transaction.categoryIcon,
      walletId: transaction.walletId,
      walletName: transaction.walletName,
      groupId: transaction.groupId,
      groupName: transaction.groupName,
      note: transaction.note,
      description: transaction.description,
      transactionDate: transaction.transactionDate,
      receiptUrl: transaction.receiptUrl,
      location: transaction.location,
      isRecurring: transaction.isRecurring,
      recurringId: transaction.recurringId,
      createdByUserId: transaction.createdByUserId,
      createdByUserName: transaction.createdByUserName,
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
      isSynced: transaction.isSynced,
    );
  }
}

/// Response wrapper for paginated transaction list
class TransactionListResponse {
  final List<TransactionModel> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final double totalIncome;
  final double totalExpense;

  TransactionListResponse({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.totalIncome,
    required this.totalExpense,
  });

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
        ?.map((e) => TransactionModel.fromJson(e))
        .toList() ?? [];
    
    return TransactionListResponse(
      items: itemsList,
      totalCount: json['totalCount'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? 20,
      totalPages: json['totalPages'] ?? 1,
      totalIncome: (json['totalIncome'] ?? 0).toDouble(),
      totalExpense: (json['totalExpense'] ?? 0).toDouble(),
    );
  }
}

/// Filter request for transactions
class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? walletId;
  final String? categoryId;
  final String? type; // EXPENSE, INCOME
  final String? groupId;
  final int page;
  final int pageSize;

  TransactionFilter({
    this.startDate,
    this.endDate,
    this.walletId,
    this.categoryId,
    this.type,
    this.groupId,
    this.page = 1,
    this.pageSize = 20,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (startDate != null) params['startDate'] = startDate!.toIso8601String();
    if (endDate != null) params['endDate'] = endDate!.toIso8601String();
    if (walletId != null) params['walletId'] = walletId;
    if (categoryId != null) params['categoryId'] = categoryId;
    if (type != null) params['type'] = type;
    if (groupId != null) params['groupId'] = groupId;
    params['page'] = page;
    params['pageSize'] = pageSize;
    return params;
  }

  TransactionFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? walletId,
    String? categoryId,
    String? type,
    String? groupId,
    int? page,
    int? pageSize,
  }) {
    return TransactionFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      groupId: groupId ?? this.groupId,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}
