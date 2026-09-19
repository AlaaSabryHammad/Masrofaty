import 'package:flutter_test/flutter_test.dart';
import 'package:masrofaty/core/services/firestore_service.dart';
import 'package:masrofaty/core/services/storage_service.dart';
import 'package:masrofaty/models/category_model.dart';
import 'package:masrofaty/models/contact_model.dart';
import 'package:masrofaty/models/debt_model.dart';
import 'package:masrofaty/models/goal_model.dart';
import 'package:masrofaty/models/recurring_transaction_model.dart';
import 'package:masrofaty/models/transaction_model.dart';
import 'package:masrofaty/models/wallet_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirestoreService & StorageService Cloud Persistence Tests', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs);
    });

    test('FirestoreService instance is initialized and singleton', () {
      final s1 = FirestoreService.instance;
      final s2 = FirestoreService();
      expect(s1, isNotNull);
      expect(identical(s1, s2), isTrue);
    });

    test('StorageService persists transactions locally and invokes cloud sync safely', () async {
      storage.setCurrentUserId('user_firebase_123');
      storage.setCurrentWorkspaceId('ws_personal_user_firebase_123');

      final tx = TransactionModel(
        id: 'tx_cloud_1',
        title: 'شراء قهوة',
        amount: 18.5,
        type: 'expense',
        categoryId: 'cat_food',
        walletId: 'wallet_card',
        date: DateTime.now(),
      );

      await storage.saveTransactions([tx]);
      final loaded = storage.loadTransactions();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'tx_cloud_1');
      expect(loaded.first.title, 'شراء قهوة');

      // Test granular deletion
      await storage.deleteSingleTransaction('tx_cloud_1');
    });

    test('StorageService persists wallets and categories with cloud sync', () async {
      storage.setCurrentUserId('user_firebase_123');

      final wallet = WalletModel(
        id: 'wallet_cloud_1',
        name: 'حساب الإنماء',
        type: 'bank',
        balance: 4500.0,
        iconCode: 0xe040,
        colorValue: 0xFF3B82F6,
      );

      await storage.saveWallets([wallet]);
      final loadedWallets = storage.loadWallets();
      expect(loadedWallets.length, 1);
      expect(loadedWallets.first.name, 'حساب الإنماء');
      expect(loadedWallets.first.balance, 4500.0);

      final cat = CategoryModel(
        id: 'cat_cloud_1',
        name: 'تسوق إلكتروني',
        iconCode: 0xe59c,
        colorValue: 0xFF8B5CF6,
        isExpense: true,
      );

      await storage.saveCategories([cat]);
      final loadedCats = storage.loadCategories();
      expect(loadedCats.length, 1);
      expect(loadedCats.first.name, 'تسوق إلكتروني');
    });

    test('StorageService persists debts, goals, recurring, and contacts', () async {
      storage.setCurrentUserId('user_firebase_123');

      // Debts
      final debt = DebtModel(
        id: 'debt_cloud_1',
        personName: 'أحمد',
        totalAmount: 500.0,
        type: 'lent',
        createdDate: DateTime.now(),
      );
      await storage.saveDebts([debt]);
      expect(storage.loadDebts().length, 1);

      // Goals
      final goal = GoalModel(
        id: 'goal_cloud_1',
        title: 'شراء لابتوب',
        targetAmount: 8000.0,
        savedAmount: 2000.0,
        iconCode: 0xe31e,
        colorValue: 0xFF10B981,
      );
      await storage.saveGoals([goal]);
      expect(storage.loadGoals().length, 1);

      // Recurring
      final recurring = RecurringTransactionModel(
        id: 'rec_cloud_1',
        title: 'اشتراك نتفليكس',
        amount: 45.0,
        type: 'expense',
        categoryId: 'cat_ent',
        walletId: 'wallet_card',
        frequency: 'monthly',
        startDate: DateTime.now(),
        nextDueDate: DateTime.now(),
      );
      await storage.saveRecurringTransactions([recurring]);
      expect(storage.loadRecurringTransactions().length, 1);

      // Contacts
      final contact = ContactModel(
        id: 'contact_cloud_1',
        name: 'فيصل',
        phone: '0555555555',
        createdAt: DateTime.now(),
      );
      await storage.saveContacts([contact]);
      expect(storage.loadContacts().length, 1);
    });

    test('Smart auto-migration executes safely without unhandled exceptions', () async {
      storage.setCurrentUserId('user_firebase_123');

      // Should complete without throws even if Firebase is offline/unconfigured in unit test
      await storage.initOrMigrateUser('user_firebase_123');
      await storage.uploadAllLocalToCloud(userId: 'user_firebase_123');
      await storage.syncFromCloud(userId: 'user_firebase_123');
    });
  });
}
