class DebtPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String? notes;
  final String? walletId;
  final String? walletName;

  DebtPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.notes,
    this.walletId,
    this.walletName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'walletId': walletId,
      'walletName': walletName,
    };
  }

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
      walletId: json['walletId'] as String?,
      walletName: json['walletName'] as String?,
    );
  }
}

class DebtModel {
  final String id;
  final String personName;
  final String? phone;
  final double totalAmount;
  final String type; // 'lent' (أموال لي) or 'borrowed' (أموال علي)
  final DateTime createdDate;
  final DateTime? dueDate;
  final String? notes;
  final String? walletId;
  final String? walletName;
  final List<DebtPayment> payments;

  DebtModel({
    required this.id,
    required this.personName,
    this.phone,
    required this.totalAmount,
    required this.type,
    required this.createdDate,
    this.dueDate,
    this.notes,
    this.walletId,
    this.walletName,
    this.payments = const [],
  });

  bool get isLent => type == 'lent';
  bool get isBorrowed => type == 'borrowed';

  double get paidAmount {
    if (payments.isEmpty) return 0.0;
    return payments.fold(0.0, (sum, item) => sum + item.amount);
  }

  double get remainingAmount {
    final rem = totalAmount - paidAmount;
    return rem < 0 ? 0.0 : rem;
  }

  bool get isSettled => remainingAmount <= 0.001;

  double get progress {
    if (totalAmount <= 0) return 1.0;
    final p = paidAmount / totalAmount;
    return p.clamp(0.0, 1.0);
  }

  bool get isOverdue {
    if (dueDate == null || isSettled) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  bool get isDueToday {
    if (dueDate == null || isSettled) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  bool get isDueSoon {
    if (dueDate == null || isSettled || isOverdue || isDueToday) return false;
    final now = DateTime.now();
    final diff = dueDate!.difference(now).inDays;
    return diff >= 0 && diff <= 3;
  }

  DebtModel copyWith({
    String? id,
    String? personName,
    String? phone,
    double? totalAmount,
    String? type,
    DateTime? createdDate,
    DateTime? dueDate,
    String? notes,
    String? walletId,
    String? walletName,
    List<DebtPayment>? payments,
  }) {
    return DebtModel(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      phone: phone ?? this.phone,
      totalAmount: totalAmount ?? this.totalAmount,
      type: type ?? this.type,
      createdDate: createdDate ?? this.createdDate,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      payments: payments ?? this.payments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'personName': personName,
      'phone': phone,
      'totalAmount': totalAmount,
      'type': type,
      'createdDate': createdDate.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'notes': notes,
      'walletId': walletId,
      'walletName': walletName,
      'payments': payments.map((p) => p.toJson()).toList(),
    };
  }

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    return DebtModel(
      id: json['id'] as String,
      personName: json['personName'] as String,
      phone: json['phone'] as String?,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      type: json['type'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      notes: json['notes'] as String?,
      walletId: json['walletId'] as String?,
      walletName: json['walletName'] as String?,
      payments: (json['payments'] as List<dynamic>?)
              ?.map((p) => DebtPayment.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
