class RecurringTransactionModel {
  final String id;
  final String title;
  final double amount;
  final String type; // 'expense' or 'income'
  final String categoryId;
  final String walletId;
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime nextDueDate;
  final bool isActive;
  final String? notes;
  final DateTime? lastProcessedDate;

  RecurringTransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    this.isActive = true,
    this.notes,
    this.lastProcessedDate,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  bool get isDueNow {
    if (!isActive) return false;
    final now = DateTime.now();
    return nextDueDate.isBefore(now) ||
        (nextDueDate.year == now.year &&
            nextDueDate.month == now.month &&
            nextDueDate.day == now.day);
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return 'يومياً';
      case 'weekly':
        return 'أسبوعياً';
      case 'yearly':
        return 'سنوياً';
      case 'monthly':
      default:
        return 'شهرياً';
    }
  }

  DateTime calculateNextDueDate(DateTime fromDate) {
    switch (frequency) {
      case 'daily':
        return fromDate.add(const Duration(days: 1));
      case 'weekly':
        return fromDate.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
      case 'monthly':
      default:
        int nextMonth = fromDate.month + 1;
        int nextYear = fromDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear += 1;
        }
        // Handle varying days in months
        int day = fromDate.day;
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (day > daysInNextMonth) {
          day = daysInNextMonth;
        }
        return DateTime(nextYear, nextMonth, day, fromDate.hour, fromDate.minute);
    }
  }

  RecurringTransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? type,
    String? categoryId,
    String? walletId,
    String? frequency,
    DateTime? startDate,
    DateTime? nextDueDate,
    bool? isActive,
    String? notes,
    DateTime? lastProcessedDate,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
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
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'nextDueDate': nextDueDate.toIso8601String(),
      'isActive': isActive,
      'notes': notes,
      'lastProcessedDate': lastProcessedDate?.toIso8601String(),
    };
  }

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String? ?? 'expense',
      categoryId: json['categoryId'] as String? ?? 'cat_bills',
      walletId: json['walletId'] as String? ?? 'wallet_cash',
      frequency: json['frequency'] as String? ?? 'monthly',
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
      nextDueDate: DateTime.tryParse(json['nextDueDate'] as String? ?? '') ?? DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      lastProcessedDate: json['lastProcessedDate'] != null
          ? DateTime.tryParse(json['lastProcessedDate'] as String)
          : null,
    );
  }
}
