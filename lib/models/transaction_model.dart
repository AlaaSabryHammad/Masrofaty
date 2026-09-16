class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final String type; // 'expense', 'income', 'transfer'
  final String categoryId;
  final String walletId;
  final String? toWalletId; // only if type == 'transfer'
  final DateTime date;
  final String? notes;
  final String? personName;
  final String? contactId;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    this.toWalletId,
    required this.date,
    this.notes,
    this.personName,
    this.contactId,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isTransfer => type == 'transfer';

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? type,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    DateTime? date,
    String? notes,
    String? personName,
    String? contactId,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      toWalletId: toWalletId ?? this.toWalletId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      personName: personName ?? this.personName,
      contactId: contactId ?? this.contactId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'walletId': walletId,
      'toWalletId': toWalletId,
      'date': date.toIso8601String(),
      'notes': notes,
      'personName': personName,
      'contactId': contactId,
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      categoryId: json['categoryId'] as String,
      walletId: json['walletId'] as String,
      toWalletId: json['toWalletId'] as String?,
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
      personName: json['personName'] as String?,
      contactId: json['contactId'] as String?,
    );
  }
}
