import 'dart:convert';
import 'package:flutter/services.dart';
import '../../core/utils/date_helper.dart';
import '../../providers/finance_provider.dart';
import '../../core/services/storage_service.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/debt_model.dart';
import '../../models/goal_model.dart';
import '../../models/recurring_transaction_model.dart';
import '../../models/contact_model.dart';

class BackupService {
  static String exportTransactionsToCsv(FinanceProvider finance, String currency) {
    final buffer = StringBuffer();
    // CSV Header (BOM for Arabic Excel support)
    buffer.write('\uFEFF');
    buffer.writeln('التاريخ,الوصف,النوع,التصنيف,المحفظة,المبلغ,العملة,الملاحظات');

    for (final tx in finance.transactions) {
      final date = DateHelper.formatShort(tx.date);
      final title = '"${tx.title.replaceAll('"', '""')}"';
      final type = tx.isExpense ? 'مصروف' : (tx.isIncome ? 'إيراد' : 'تحويل');
      final cat = finance.getCategoryById(tx.categoryId)?.name ?? 'أخرى';
      final wallet = finance.getWalletById(tx.walletId)?.name ?? 'كاش';
      final notes = tx.notes != null ? '"${tx.notes!.replaceAll('"', '""')}"' : '""';

      buffer.writeln('$date,$title,$type,$cat,$wallet,${tx.amount},$currency,$notes');
    }

    return buffer.toString();
  }

  static String exportAllDataToJson(StorageService storage) {
    final data = {
      'version': '1.1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'transactions': storage.loadTransactions().map((t) => t.toJson()).toList(),
      'categories': storage.loadCategories().map((c) => c.toJson()).toList(),
      'wallets': storage.loadWallets().map((w) => w.toJson()).toList(),
      'debts': storage.loadDebts().map((d) => d.toJson()).toList(),
      'goals': storage.loadGoals().map((g) => g.toJson()).toList(),
      'recurringTransactions': storage.loadRecurringTransactions().map((r) => r.toJson()).toList(),
      'contacts': storage.loadContacts().map((c) => c.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<bool> importAllDataFromJson(StorageService storage, String jsonString) async {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return false;

      if (decoded['categories'] != null && decoded['categories'] is List) {
        final list = (decoded['categories'] as List)
            .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) await storage.saveCategories(list);
      }

      if (decoded['wallets'] != null && decoded['wallets'] is List) {
        final list = (decoded['wallets'] as List)
            .map((w) => WalletModel.fromJson(w as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) await storage.saveWallets(list);
      }

      if (decoded['transactions'] != null && decoded['transactions'] is List) {
        final list = (decoded['transactions'] as List)
            .map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
            .toList();
        await storage.saveTransactions(list);
      }

      if (decoded['debts'] != null && decoded['debts'] is List) {
        final list = (decoded['debts'] as List)
            .map((d) => DebtModel.fromJson(d as Map<String, dynamic>))
            .toList();
        await storage.saveDebts(list);
      }

      if (decoded['goals'] != null && decoded['goals'] is List) {
        final list = (decoded['goals'] as List)
            .map((g) => GoalModel.fromJson(g as Map<String, dynamic>))
            .toList();
        await storage.saveGoals(list);
      }

      if (decoded['recurringTransactions'] != null && decoded['recurringTransactions'] is List) {
        final list = (decoded['recurringTransactions'] as List)
            .map((r) => RecurringTransactionModel.fromJson(r as Map<String, dynamic>))
            .toList();
        await storage.saveRecurringTransactions(list);
      }

      if (decoded['contacts'] != null && decoded['contacts'] is List) {
        final list = (decoded['contacts'] as List)
            .map((c) => ContactModel.fromJson(c as Map<String, dynamic>))
            .toList();
        await storage.saveContacts(list);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> copyBackupToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
  }
}
