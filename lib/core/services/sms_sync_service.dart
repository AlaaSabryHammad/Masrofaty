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

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIos => !kIsWeb && Platform.isIOS;
  static bool get isSupported => isAndroid;

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

  /// Read text from system clipboard and parse it if it is a bank transaction
  static Future<ParsedBankTransaction?> parseFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return null;
      return parseRawText(text, sender: 'الحافظة');
    } catch (e) {
      debugPrint('Error reading from clipboard: $e');
      return null;
    }
  }

  /// Parse a single text string as a bank transaction
  static ParsedBankTransaction? parseRawText(String text, {String sender = 'إدخال يدوي'}) {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    final parsed = BillParserService.parse(clean);
    if ((parsed.amount ?? 0) <= 0) return null;
    return ParsedBankTransaction(
      sender: parsed.bankName ?? sender,
      body: clean,
      timestamp: DateTime.now(),
      parsed: parsed,
    );
  }

  /// Parse multiple messages separated by double newlines, dashes, or individual lines
  static List<ParsedBankTransaction> parseMultipleMessages(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    // Split either by double newline or delimiter like ---
    final blocks = clean.split(RegExp(r'\n{2,}|\r\n\r\n|---'));
    final results = <ParsedBankTransaction>[];

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;
      final tx = parseRawText(trimmed, sender: 'رسالة ملصوقة');
      if (tx != null) {
        results.add(tx);
      }
    }

    // If no multi-block was split but whole text might have 1 transaction
    if (results.isEmpty) {
      final single = parseRawText(clean, sender: 'رسالة ملصوقة');
      if (single != null) results.add(single);
    }

    return results;
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
    FinanceProvider finance, {
    String? targetWalletId,
    String? targetCategoryId,
  }) async {
    final amount = tx.amount ?? 0.0;
    if (amount <= 0) return;

    // 1. Identify bank wallet
    String bankWalletId = targetWalletId ?? '';
    if (bankWalletId.isEmpty) {
      final wallets = finance.wallets;
      final bankWallet = wallets.firstWhere(
        (w) => w.type == 'bank' || w.type == 'card',
        orElse: () => wallets.isNotEmpty ? wallets.first : finance.wallets.first,
      );
      bankWalletId = bankWallet.id;
    }

    // 2. Identify cash wallet for ATM withdrawals
    String cashWalletId = '';
    final wallets = finance.wallets;
    final cashWallet = wallets.firstWhere(
      (w) => w.type == 'cash',
      orElse: () => wallets.isNotEmpty ? wallets.first : finance.wallets.first,
    );
    cashWalletId = cashWallet.id;

    final catId = (targetCategoryId != null && targetCategoryId.isNotEmpty)
        ? targetCategoryId
        : tx.categoryId;

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
        categoryId: catId,
        walletId: bankWalletId,
        date: tx.timestamp,
        notes: 'عملية بنكية: ${tx.bankName ?? tx.sender}',
      );
    } else {
      // Deposit / Income
      await finance.addTransaction(
        title: tx.merchant,
        amount: amount,
        type: 'income',
        categoryId: catId,
        walletId: bankWalletId,
        date: tx.timestamp,
        notes: 'إيداع بنكي: ${tx.bankName ?? tx.sender}',
      );
    }
  }
}
