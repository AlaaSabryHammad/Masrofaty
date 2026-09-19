import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../models/category_model.dart';
import '../../models/contact_model.dart';
import '../../models/debt_model.dart';
import '../../models/goal_model.dart';
import '../../models/recurring_transaction_model.dart';
import '../../models/saas_plan_model.dart';
import '../../models/transaction_model.dart';
import '../../models/user_profile_model.dart';
import '../../models/wallet_model.dart';
import '../../models/workspace_model.dart';
import 'firebase_sync_service.dart';

class FirestoreService {
  static FirestoreService? _instance;
  static FirestoreService get instance => _instance ??= FirestoreService._();

  FirestoreService._() {
    _configureFirestoreSettings();
  }

  factory FirestoreService() => instance;

  FirebaseFirestore? _db;
  FirebaseFirestore get _activeDb => _db ?? FirebaseFirestore.instance;

  void _configureFirestoreSettings() {
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }
      _db = FirebaseFirestore.instance;
      _db!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('[FirestoreService] Firestore settings config warning: $e');
    }
  }

  Future<bool> _ensureReady() async {
    if (_db != null) return true;
    final ready = await FirebaseSyncService.initialize();
    if (ready) {
      _configureFirestoreSettings();
    }
    return _db != null;
  }

  // ================= Path References =================

  CollectionReference<Map<String, dynamic>> _userCol(String userId, String subCollection) {
    return _activeDb.collection('users').doc(userId).collection(subCollection);
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String userId, String subCollection, String docId) {
    return _userCol(userId, subCollection).doc(docId);
  }

  // ================= Transactions =================

  Future<void> saveTransaction(String userId, String workspaceId, TransactionModel tx) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = tx.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'transactions', tx.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving transaction ${tx.id}: $e');
    }
  }

  Future<void> deleteTransaction(String userId, String transactionId) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      await _userDoc(userId, 'transactions', transactionId).delete();
    } catch (e) {
      debugPrint('[FirestoreService] Error deleting transaction $transactionId: $e');
    }
  }

  Future<void> batchSaveTransactions(String userId, String workspaceId, List<TransactionModel> transactions) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final batch = _activeDb.batch();
      final col = _userCol(userId, 'transactions');
      for (final tx in transactions) {
        final data = tx.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(tx.id), data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FirestoreService] Error batch saving transactions: $e');
    }
  }

  Future<List<TransactionModel>> fetchTransactions(String userId, {String? workspaceId}) async {
    if (userId.isEmpty || userId == 'guest') return [];
    try {
      if (!await _ensureReady()) return [];
      Query<Map<String, dynamic>> query = _userCol(userId, 'transactions');
      if (workspaceId != null && workspaceId.isNotEmpty) {
        query = query.where('workspaceId', isEqualTo: workspaceId);
      }
      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => TransactionModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching transactions: $e');
      return [];
    }
  }

  // ================= Wallets =================

  Future<void> saveWallet(String userId, String workspaceId, WalletModel wallet) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = wallet.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'wallets', wallet.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving wallet ${wallet.id}: $e');
    }
  }

  Future<void> deleteWallet(String userId, String walletId) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      await _userDoc(userId, 'wallets', walletId).delete();
    } catch (e) {
      debugPrint('[FirestoreService] Error deleting wallet $walletId: $e');
    }
  }

  Future<void> batchSaveWallets(String userId, String workspaceId, List<WalletModel> wallets) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final batch = _activeDb.batch();
      final col = _userCol(userId, 'wallets');
      for (final wallet in wallets) {
        final data = wallet.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(wallet.id), data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FirestoreService] Error batch saving wallets: $e');
    }
  }

  Future<List<WalletModel>> fetchWallets(String userId, {String? workspaceId}) async {
    if (userId.isEmpty || userId == 'guest') return [];
    try {
      if (!await _ensureReady()) return [];
      Query<Map<String, dynamic>> query = _userCol(userId, 'wallets');
      if (workspaceId != null && workspaceId.isNotEmpty) {
        query = query.where('workspaceId', isEqualTo: workspaceId);
      }
      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => WalletModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching wallets: $e');
      return [];
    }
  }

  // ================= Categories =================

  Future<void> saveCategory(String userId, CategoryModel category) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = category.toJson()..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'categories', category.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving category ${category.id}: $e');
    }
  }

  Future<void> deleteCategory(String userId, String categoryId) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      await _userDoc(userId, 'categories', categoryId).delete();
    } catch (e) {
      debugPrint('[FirestoreService] Error deleting category $categoryId: $e');
    }
  }

  Future<void> batchSaveCategories(String userId, List<CategoryModel> categories) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final batch = _activeDb.batch();
      final col = _userCol(userId, 'categories');
      for (final cat in categories) {
        final data = cat.toJson()..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(cat.id), data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FirestoreService] Error batch saving categories: $e');
    }
  }

  Future<List<CategoryModel>> fetchCategories(String userId) async {
    if (userId.isEmpty || userId == 'guest') return [];
    try {
      if (!await _ensureReady()) return [];
      final snapshot = await _userCol(userId, 'categories').get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => CategoryModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching categories: $e');
      return [];
    }
  }

  // ================= Debts =================

  Future<void> saveDebt(String userId, String workspaceId, DebtModel debt) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = debt.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'debts', debt.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving debt ${debt.id}: $e');
    }
  }

  Future<void> deleteDebt(String userId, String debtId) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      await _userDoc(userId, 'debts', debtId).delete();
    } catch (e) {
      debugPrint('[FirestoreService] Error deleting debt $debtId: $e');
    }
  }

  Future<void> batchSaveDebts(String userId, String workspaceId, List<DebtModel> debts) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final batch = _activeDb.batch();
      final col = _userCol(userId, 'debts');
      for (final debt in debts) {
        final data = debt.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(debt.id), data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FirestoreService] Error batch saving debts: $e');
    }
  }

  Future<List<DebtModel>> fetchDebts(String userId, {String? workspaceId}) async {
    if (userId.isEmpty || userId == 'guest') return [];
    try {
      if (!await _ensureReady()) return [];
      Query<Map<String, dynamic>> query = _userCol(userId, 'debts');
      if (workspaceId != null && workspaceId.isNotEmpty) {
        query = query.where('workspaceId', isEqualTo: workspaceId);
      }
      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => DebtModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching debts: $e');
      return [];
    }
  }

  // ================= Goals =================

  Future<void> saveGoal(String userId, String workspaceId, GoalModel goal) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = goal.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'goals', goal.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving goal ${goal.id}: $e');
    }
  }

  Future<void> deleteGoal(String userId, String goalId) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      await _userDoc(userId, 'goals', goalId).delete();
    } catch (e) {
      debugPrint('[FirestoreService] Error deleting goal $goalId: $e');
    }
  }

  Future<void> batchSaveGoals(String userId, String workspaceId, List<GoalModel> goals) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final batch = _activeDb.batch();
      final col = _userCol(userId, 'goals');
      for (final goal in goals) {
        final data = goal.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(goal.id), data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FirestoreService] Error batch saving goals: $e');
    }
  }

  Future<List<GoalModel>> fetchGoals(String userId, {String? workspaceId}) async {
    if (userId.isEmpty || userId == 'guest') return [];
    try {
      if (!await _ensureReady()) return [];
      Query<Map<String, dynamic>> query = _userCol(userId, 'goals');
      if (workspaceId != null && workspaceId.isNotEmpty) {
        query = query.where('workspaceId', isEqualTo: workspaceId);
      }
      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => GoalModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching goals: $e');
      return [];
    }
  }

  // ================= Recurring Transactions =================

  Future<void> saveRecurring(String userId, String workspaceId, RecurringTransactionModel item) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = item.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'recurring', item.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving recurring ${item.id}: $e');
    }
  }

  Future<void> deleteRecurring(String userId, String recurringId) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      await _userDoc(userId, 'recurring', recurringId).delete();
    } catch (e) {
      debugPrint('[FirestoreService] Error deleting recurring $recurringId: $e');
    }
  }

  Future<void> batchSaveRecurring(String userId, String workspaceId, List<RecurringTransactionModel> items) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final batch = _activeDb.batch();
      final col = _userCol(userId, 'recurring');
      for (final item in items) {
        final data = item.toJson()..['workspaceId'] = workspaceId..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(item.id), data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FirestoreService] Error batch saving recurring: $e');
    }
  }

  Future<List<RecurringTransactionModel>> fetchRecurring(String userId, {String? workspaceId}) async {
    if (userId.isEmpty || userId == 'guest') return [];
    try {
      if (!await _ensureReady()) return [];
      Query<Map<String, dynamic>> query = _userCol(userId, 'recurring');
      if (workspaceId != null && workspaceId.isNotEmpty) {
        query = query.where('workspaceId', isEqualTo: workspaceId);
      }
      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => RecurringTransactionModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching recurring: $e');
      return [];
    }
  }

  // ================= Contacts =================

  Future<void> saveContact(String userId, ContactModel contact) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = contact.toJson()..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'contacts', contact.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving contact ${contact.id}: $e');
    }
  }

  Future<void> deleteContact(String userId, String contactId) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      await _userDoc(userId, 'contacts', contactId).delete();
    } catch (e) {
      debugPrint('[FirestoreService] Error deleting contact $contactId: $e');
    }
  }

  Future<void> batchSaveContacts(String userId, List<ContactModel> contacts) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final batch = _activeDb.batch();
      final col = _userCol(userId, 'contacts');
      for (final c in contacts) {
        final data = c.toJson()..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(c.id), data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FirestoreService] Error batch saving contacts: $e');
    }
  }

  Future<List<ContactModel>> fetchContacts(String userId) async {
    if (userId.isEmpty || userId == 'guest') return [];
    try {
      if (!await _ensureReady()) return [];
      final snapshot = await _userCol(userId, 'contacts').get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => ContactModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching contacts: $e');
      return [];
    }
  }

  // ================= Workspaces & Plans =================

  Future<void> batchSaveWorkspaces(String userId, List<WorkspaceModel> workspaces) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final batch = _activeDb.batch();
      final col = _userCol(userId, 'workspaces');
      for (final ws in workspaces) {
        final data = ws.toJson()..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(ws.id), data, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[FirestoreService] Error saving workspaces: $e');
    }
  }

  Future<List<WorkspaceModel>> fetchWorkspaces(String userId) async {
    if (userId.isEmpty || userId == 'guest') return [];
    try {
      if (!await _ensureReady()) return [];
      final snapshot = await _userCol(userId, 'workspaces').get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs.map((doc) => WorkspaceModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching workspaces: $e');
      return [];
    }
  }

  Future<void> saveSaaSPlan(String userId, SaaSPlanModel plan) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = plan.toJson()..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'subscription', 'plan').set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving SaaS plan: $e');
    }
  }

  Future<SaaSPlanModel?> fetchSaaSPlan(String userId) async {
    if (userId.isEmpty || userId == 'guest') return null;
    try {
      if (!await _ensureReady()) return null;
      final doc = await _userDoc(userId, 'subscription', 'plan').get();
      if (doc.exists && doc.data() != null) {
        return SaaSPlanModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching SaaS plan: $e');
      return null;
    }
  }

  // ================= Profile & Preferences =================

  Future<void> saveProfile(String userId, UserProfileModel profile) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = profile.toJson()..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'profile', 'info').set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving profile: $e');
    }
  }

  Future<UserProfileModel?> fetchProfile(String userId) async {
    if (userId.isEmpty || userId == 'guest') return null;
    try {
      if (!await _ensureReady()) return null;
      final doc = await _userDoc(userId, 'profile', 'info').get();
      if (doc.exists && doc.data() != null) {
        return UserProfileModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching profile: $e');
      return null;
    }
  }

  Future<void> savePreferences(String userId, Map<String, dynamic> preferences) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      if (!await _ensureReady()) return;
      final data = Map<String, dynamic>.from(preferences)
        ..['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(userId, 'settings', 'preferences').set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] Error saving preferences: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchPreferences(String userId) async {
    if (userId.isEmpty || userId == 'guest') return null;
    try {
      if (!await _ensureReady()) return null;
      final doc = await _userDoc(userId, 'settings', 'preferences').get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('[FirestoreService] Error fetching preferences: $e');
      return null;
    }
  }

  // ================= Cloud Status & Auto Migration =================

  /// Checks whether user has existing data stored in Firestore
  Future<bool> hasCloudData(String userId) async {
    if (userId.isEmpty || userId == 'guest') return false;
    try {
      if (!await _ensureReady()) return false;
      // Check wallets or transactions collection
      final txs = await _userCol(userId, 'transactions').limit(1).get();
      if (txs.docs.isNotEmpty) return true;
      final wallets = await _userCol(userId, 'wallets').limit(1).get();
      if (wallets.docs.isNotEmpty) return true;
      final cats = await _userCol(userId, 'categories').limit(1).get();
      if (cats.docs.isNotEmpty) return true;
      return false;
    } catch (e) {
      debugPrint('[FirestoreService] Error checking cloud data presence: $e');
      return false;
    }
  }
}
