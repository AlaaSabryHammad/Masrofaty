import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../../models/debt_model.dart';
import '../../models/goal_model.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/recurring_transaction_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/recurring_provider.dart';

class FirebaseSyncService {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      // Guard against placeholder keys to prevent native iOS FIRInstallations validation crash
      if (options.apiKey.startsWith('YOUR_') || options.apiKey.length != 39 || !options.apiKey.startsWith('A')) {
        _isInitialized = false;
        return false;
      }

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: options,
        );
      }
      _isInitialized = true;
      return true;
    } catch (_) {
      _isInitialized = false;
      return false;
    }
  }

  static Future<bool> syncToCloud({
    required FinanceProvider finance,
    required DebtProvider debts,
    required GoalProvider goals,
    RecurringProvider? recurring,
    String userId = 'default_user',
  }) async {
    final ready = await initialize();
    if (!ready) return false;

    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('users').doc(userId).collection('backup').doc('latest');

      final data = {
        'lastSynced': DateTime.now().toIso8601String(),
        'transactions': finance.transactions.map((t) => t.toJson()).toList(),
        'categories': finance.categories.map((c) => c.toJson()).toList(),
        'wallets': finance.wallets.map((w) => w.toJson()).toList(),
        'debts': debts.debts.map((d) => d.toJson()).toList(),
        'goals': goals.goals.map((g) => g.toJson()).toList(),
        if (recurring != null)
          'recurring': recurring.recurringTransactions.map((r) => r.toJson()).toList(),
      };

      await docRef.set(data, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> restoreFromCloud({
    required FinanceProvider finance,
    required DebtProvider debts,
    required GoalProvider goals,
    RecurringProvider? recurring,
    String userId = 'default_user',
  }) async {
    final ready = await initialize();
    if (!ready) return false;

    try {
      final db = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(userId).collection('backup').doc('latest').get();

      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data()!;

      List<CategoryModel>? categories;
      if (data['categories'] != null) {
        categories = (data['categories'] as List<dynamic>)
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      List<WalletModel>? wallets;
      if (data['wallets'] != null) {
        wallets = (data['wallets'] as List<dynamic>)
            .map((e) => WalletModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      List<TransactionModel>? transactions;
      if (data['transactions'] != null) {
        transactions = (data['transactions'] as List<dynamic>)
            .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      await finance.restoreData(
        categories: categories,
        wallets: wallets,
        transactions: transactions,
      );

      // Restore debts
      if (data['debts'] != null) {
        final debtList = (data['debts'] as List<dynamic>)
            .map((e) => DebtModel.fromJson(e as Map<String, dynamic>))
            .toList();
        await debts.restoreDebts(debtList);
      }

      // Restore goals
      if (data['goals'] != null) {
        final goalList = (data['goals'] as List<dynamic>)
            .map((e) => GoalModel.fromJson(e as Map<String, dynamic>))
            .toList();
        await goals.restoreGoals(goalList);
      }

      // Restore recurring
      if (recurring != null && data['recurring'] != null) {
        final recurringList = (data['recurring'] as List<dynamic>)
            .map((e) => RecurringTransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        await recurring.restoreRecurring(recurringList);
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
