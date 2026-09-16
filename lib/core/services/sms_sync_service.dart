import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'bill_parser_service.dart';
import '../../providers/finance_provider.dart';

class ParsedBankTransaction {
  final String sender;
  final String body;
  final DateTime timestamp;
  final ParsedBillResult parsed;

  ParsedBankTransaction({
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.parsed,
  });

  double? get amount => parsed.amount;
  String get merchant => parsed.merchant ?? 'عملية مصرفية';
  String get categoryId => parsed.categoryId;
  bool get isExpense => parsed.isExpense;
  bool get isAtmWithdrawal => parsed.isAtmWithdrawal;
  String? get bankName => parsed.bankName;
  String? get cardLastDigits => parsed.cardLastDigits;
}

class SmsSyncService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.masrofaty.app/bank_sms');
  static const EventChannel _eventChannel =
      EventChannel('com.masrofaty.app/bank_sms_stream');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  StreamSubscription? _subscription;
  final _smsStreamController =
      StreamController<ParsedBankTransaction>.broadcast();

  Stream<ParsedBankTransaction> get smsStream => _smsStreamController.stream;

  void initialize(FinanceProvider? financeProvider) {
    if (!isSupported) return;

    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final sender = event['sender']?.toString() ?? '';
          final body = event['body']?.toString() ?? '';
          final timestamp = event['timestamp'] is int
              ? DateTime.fromMillisecondsSinceEpoch(event['timestamp'] as int)
              : DateTime.now();

          final parsed = BillParserService.parse(body);
          final tx = ParsedBankTransaction(
            sender: sender,
            body: body,
            timestamp: timestamp,
            parsed: parsed,
          );

          _smsStreamController.add(tx);

          // Auto-apply if financeProvider is supplied and amount > 0
          if (financeProvider != null && (tx.amount ?? 0) > 0) {
            applyTransactionToFinance(tx, financeProvider);
          }
        }
      },
      onError: (err) {
        debugPrint('SMS Stream Error: $err');
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
    _smsStreamController.close();
  }

  Future<bool> checkPermissions() async {
    if (!isSupported) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('checkPermissions');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestPermissions');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<ParsedBankTransaction>> getPendingSms() async {
    if (!isSupported) return [];
    try {
      final res = await _methodChannel.invokeListMethod<dynamic>('getPendingSms');
      if (res == null) return [];

      return res.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final sender = map['sender']?.toString() ?? '';
        final body = map['body']?.toString() ?? '';
        final ts = map['timestamp'] is int
            ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
            : DateTime.now();
        final parsed = BillParserService.parse(body);
        return ParsedBankTransaction(
          sender: sender,
          body: body,
          timestamp: ts,
          parsed: parsed,
        );
      }).where((tx) => (tx.amount ?? 0) > 0).toList();
    } catch (e) {
      debugPrint('Error getting pending SMS: $e');
      return [];
    }
  }

  Future<List<ParsedBankTransaction>> scanRecentBankSms({
    int days = 14,
    int limit = 50,
  }) async {
    if (!isSupported) return [];
    try {
      final res = await _methodChannel.invokeListMethod<dynamic>(
        'readRecentBankSms',
        {'days': days, 'limit': limit},
      );
      if (res == null) return [];

      return res.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final sender = map['sender']?.toString() ?? '';
        final body = map['body']?.toString() ?? '';
        final ts = map['timestamp'] is int
            ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
            : DateTime.now();
        final parsed = BillParserService.parse(body);
        return ParsedBankTransaction(
          sender: sender,
          body: body,
          timestamp: ts,
          parsed: parsed,
        );
      }).where((tx) => (tx.amount ?? 0) > 0).toList();
    } catch (e) {
      debugPrint('Error scanning recent bank SMS: $e');
      return [];
    }
  }

  /// Automatically applies transaction to FinanceProvider
  static Future<void> applyTransactionToFinance(
    ParsedBankTransaction tx,
    FinanceProvider finance,
  ) async {
    final amount = tx.amount ?? 0.0;
    if (amount <= 0) return;

    // 1. Identify bank wallet
    String bankWalletId = '';
    final wallets = finance.wallets;
    final bankWallet = wallets.firstWhere(
      (w) => w.type == 'bank' || w.type == 'card',
      orElse: () => wallets.isNotEmpty ? wallets.first : finance.wallets.first,
    );
    bankWalletId = bankWallet.id;

    // 2. Identify cash wallet
    String cashWalletId = '';
    final cashWallet = wallets.firstWhere(
      (w) => w.type == 'cash',
      orElse: () => bankWallet,
    );
    cashWalletId = cashWallet.id;

    if (tx.isAtmWithdrawal) {
      // ATM Cash Withdrawal: internal transfer from Bank to Cash wallet!
      await finance.transferBetweenWallets(
        fromWalletId: bankWalletId,
        toWalletId: cashWalletId,
        amount: amount,
        notes: 'سحب نقدي من الصراف الآلي (${tx.merchant}) - تم تحويله إلى الكاش تلقائياً',
      );
    } else if (tx.isExpense) {
      // Purchase / Debit
      await finance.addTransaction(
        title: tx.merchant,
        amount: amount,
        type: 'expense',
        categoryId: tx.categoryId,
        walletId: bankWalletId,
        date: tx.timestamp,
        notes: 'عملية بنكية تلقائية: ${tx.bankName ?? tx.sender}',
      );
    } else {
      // Deposit / Income
      await finance.addTransaction(
        title: tx.merchant,
        amount: amount,
        type: 'income',
        categoryId: tx.categoryId,
        walletId: bankWalletId,
        date: tx.timestamp,
        notes: 'إيداع بنكي تلقائي: ${tx.bankName ?? tx.sender}',
      );
    }
  }
}
