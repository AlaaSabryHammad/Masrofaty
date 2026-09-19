import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/debt_model.dart';
import '../../models/wallet_model.dart';
import '../../models/contact_model.dart';
import '../../models/goal_model.dart';
import '../../models/app_notification.dart';
import '../../models/workspace_model.dart';
import '../../models/saas_plan_model.dart';
import '../../models/recurring_transaction_model.dart';
import 'firestore_service.dart';

class StorageService {
  final SharedPreferences _prefs;
  final FirestoreService _firestore = FirestoreService.instance;

  SharedPreferences get prefs => _prefs;
  FirestoreService get firestore => _firestore;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String? _currentUserId;
  String? _currentWorkspaceId;

  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  String? get currentUserId => _currentUserId;

  void setCurrentWorkspaceId(String? workspaceId) {
    _currentWorkspaceId = workspaceId;
  }

  String? get currentWorkspaceId => _currentWorkspaceId;

  String _userKey(String baseKey) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return baseKey;
    }
    return '${baseKey}_$_currentUserId';
  }

  /// Workspace-scoped storage key: {baseKey}_{userId}_{workspaceId}
  String _workspaceKey(String baseKey) {
    final uid = (_currentUserId == null || _currentUserId!.isEmpty) ? 'guest' : _currentUserId!;
    final wid = (_currentWorkspaceId == null || _currentWorkspaceId!.isEmpty)
        ? 'ws_personal_$uid'
        : _currentWorkspaceId!;
    return '${baseKey}_${uid}_$wid';
  }

  bool get _canSyncToCloud =>
      _currentUserId != null &&
      _currentUserId!.isNotEmpty &&
      _currentUserId != 'guest';

  String get _effectiveWorkspaceId =>
      (_currentWorkspaceId != null && _currentWorkspaceId!.isNotEmpty)
          ? _currentWorkspaceId!
          : 'ws_personal_${_currentUserId ?? "guest"}';

  // First Run Check
  bool get isFirstRun => _prefs.getBool(AppConstants.keyFirstRun) ?? true;
  Future<void> setFirstRunCompleted() async {
    await _prefs.setBool(AppConstants.keyFirstRun, false);
  }

  // Currency
  String getCurrencySymbol() {
    return _prefs.getString(AppConstants.keyCurrency) ?? AppConstants.defaultCurrencySymbol;
  }

  Future<void> saveCurrencySymbol(String symbol) async {
    await _prefs.setString(AppConstants.keyCurrency, symbol);
    if (_canSyncToCloud) {
      _firestore.savePreferences(_currentUserId!, {'currency': symbol});
    }
  }

  // Theme Mode
  String getThemeMode() {
    return _prefs.getString(AppConstants.keyThemeMode) ?? 'system';
  }

  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(AppConstants.keyThemeMode, mode);
    if (_canSyncToCloud) {
      _firestore.savePreferences(_currentUserId!, {'themeMode': mode});
    }
  }

  // Hide Balance
  bool getHideBalance() {
    return _prefs.getBool(AppConstants.keyHideBalance) ?? false;
  }

  Future<void> saveHideBalance(bool hide) async {
    await _prefs.setBool(AppConstants.keyHideBalance, hide);
    if (_canSyncToCloud) {
      _firestore.savePreferences(_currentUserId!, {'hideBalance': hide});
    }
  }

  // ================= Workspace Management =================

  List<WorkspaceModel> loadWorkspaces(String userId) {
    final key = 'masrofaty_workspaces_$userId';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) {
      final defaultWs = WorkspaceModel.defaultWorkspace(userId: userId);
      return [defaultWs];
    }
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      final workspaces = list
          .map((item) => WorkspaceModel.fromJson(item as Map<String, dynamic>))
          .toList();
      if (workspaces.isEmpty) {
        return [WorkspaceModel.defaultWorkspace(userId: userId)];
      }
      return workspaces;
    } catch (_) {
      return [WorkspaceModel.defaultWorkspace(userId: userId)];
    }
  }

  Future<void> saveWorkspaces(String userId, List<WorkspaceModel> workspaces) async {
    final key = 'masrofaty_workspaces_$userId';
    final list = workspaces.map((w) => w.toJson()).toList();
    await _prefs.setString(key, jsonEncode(list));

    if (userId.isNotEmpty && userId != 'guest') {
      _firestore.batchSaveWorkspaces(userId, workspaces);
    }
  }

  String? getActiveWorkspaceId(String userId) {
    return _prefs.getString('masrofaty_active_workspace_$userId');
  }

  Future<void> setActiveWorkspaceId(String userId, String workspaceId) async {
    await _prefs.setString('masrofaty_active_workspace_$userId', workspaceId);
  }

  SaaSPlanModel loadSaaSPlan(String userId) {
    final key = 'masrofaty_saas_plan_$userId';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) {
      return SaaSPlanModel.starter();
    }
    try {
      return SaaSPlanModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return SaaSPlanModel.starter();
    }
  }

  Future<void> saveSaaSPlan(String userId, SaaSPlanModel plan) async {
    final key = 'masrofaty_saas_plan_$userId';
    await _prefs.setString(key, jsonEncode(plan.toJson()));

    if (userId.isNotEmpty && userId != 'guest') {
      _firestore.saveSaaSPlan(userId, plan);
    }
  }

  // ================= Scoped Transactions =================

  List<TransactionModel> loadTransactions() {
    final scopedKey = _workspaceKey(AppConstants.keyTransactions);
    var jsonStr = _prefs.getString(scopedKey);

    // Backward-compatibility: if scoped key doesn't exist yet, check user key and auto-migrate
    if (jsonStr == null || jsonStr.isEmpty) {
      final legacyKey = _userKey(AppConstants.keyTransactions);
      jsonStr = _prefs.getString(legacyKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _prefs.setString(scopedKey, jsonStr);
      }
    }

    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTransactions(List<TransactionModel> transactions) async {
    final list = transactions.map((t) => t.toJson()).toList();
    await _prefs.setString(_workspaceKey(AppConstants.keyTransactions), jsonEncode(list));

    if (_canSyncToCloud) {
      _firestore.batchSaveTransactions(_currentUserId!, _effectiveWorkspaceId, transactions);
    }
  }

  Future<void> saveSingleTransaction(TransactionModel tx) async {
    if (_canSyncToCloud) {
      _firestore.saveTransaction(_currentUserId!, _effectiveWorkspaceId, tx);
    }
  }

  Future<void> deleteSingleTransaction(String txId) async {
    if (_canSyncToCloud) {
      _firestore.deleteTransaction(_currentUserId!, txId);
    }
  }

  // Categories (shared or scoped)
  List<CategoryModel> loadCategories() {
    final jsonStr = _prefs.getString(AppConstants.keyCategories);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      final seen = <String>{};
      final result = <CategoryModel>[];
      for (final item in list) {
        final c = CategoryModel.fromJson(item as Map<String, dynamic>);
        if (seen.add(c.id)) {
          result.add(c);
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCategories(List<CategoryModel> categories) async {
    final list = categories.map((c) => c.toJson()).toList();
    await _prefs.setString(AppConstants.keyCategories, jsonEncode(list));

    if (_canSyncToCloud) {
      _firestore.batchSaveCategories(_currentUserId!, categories);
    }
  }

  Future<void> saveSingleCategory(CategoryModel category) async {
    if (_canSyncToCloud) {
      _firestore.saveCategory(_currentUserId!, category);
    }
  }

  Future<void> deleteSingleCategory(String categoryId) async {
    if (_canSyncToCloud) {
      _firestore.deleteCategory(_currentUserId!, categoryId);
    }
  }

  // ================= Scoped Wallets =================

  List<WalletModel> loadWallets() {
    final scopedKey = _workspaceKey(AppConstants.keyWallets);
    var jsonStr = _prefs.getString(scopedKey);

    if (jsonStr == null || jsonStr.isEmpty) {
      final legacyKey = _userKey(AppConstants.keyWallets);
      jsonStr = _prefs.getString(legacyKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _prefs.setString(scopedKey, jsonStr);
      }
    }

    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      final seen = <String>{};
      final result = <WalletModel>[];
      for (final item in list) {
        final w = WalletModel.fromJson(item as Map<String, dynamic>);
        if (seen.add(w.id)) {
          result.add(w);
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveWallets(List<WalletModel> wallets) async {
    final list = wallets.map((w) => w.toJson()).toList();
    await _prefs.setString(_workspaceKey(AppConstants.keyWallets), jsonEncode(list));

    if (_canSyncToCloud) {
      _firestore.batchSaveWallets(_currentUserId!, _effectiveWorkspaceId, wallets);
    }
  }

  Future<void> saveSingleWallet(WalletModel wallet) async {
    if (_canSyncToCloud) {
      _firestore.saveWallet(_currentUserId!, _effectiveWorkspaceId, wallet);
    }
  }

  Future<void> deleteSingleWallet(String walletId) async {
    if (_canSyncToCloud) {
      _firestore.deleteWallet(_currentUserId!, walletId);
    }
  }

  // ================= Scoped Debts =================

  List<DebtModel> loadDebts() {
    final scopedKey = _workspaceKey(AppConstants.keyDebts);
    var jsonStr = _prefs.getString(scopedKey);

    if (jsonStr == null || jsonStr.isEmpty) {
      final legacyKey = _userKey(AppConstants.keyDebts);
      jsonStr = _prefs.getString(legacyKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _prefs.setString(scopedKey, jsonStr);
      }
    }

    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => DebtModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDebts(List<DebtModel> debts) async {
    final list = debts.map((d) => d.toJson()).toList();
    await _prefs.setString(_workspaceKey(AppConstants.keyDebts), jsonEncode(list));

    if (_canSyncToCloud) {
      _firestore.batchSaveDebts(_currentUserId!, _effectiveWorkspaceId, debts);
    }
  }

  Future<void> saveSingleDebt(DebtModel debt) async {
    if (_canSyncToCloud) {
      _firestore.saveDebt(_currentUserId!, _effectiveWorkspaceId, debt);
    }
  }

  Future<void> deleteSingleDebt(String debtId) async {
    if (_canSyncToCloud) {
      _firestore.deleteDebt(_currentUserId!, debtId);
    }
  }

  // ================= Scoped Contacts =================

  List<ContactModel> loadContacts() {
    final scopedKey = _workspaceKey('masrofaty_contacts');
    var jsonStr = _prefs.getString(scopedKey);

    if (jsonStr == null || jsonStr.isEmpty) {
      // Legacy un-scoped key
      jsonStr = _prefs.getString('masrofaty_contacts');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _prefs.setString(scopedKey, jsonStr);
      }
    }

    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => ContactModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveContacts(List<ContactModel> contacts) async {
    final list = contacts.map((c) => c.toJson()).toList();
    await _prefs.setString(_workspaceKey('masrofaty_contacts'), jsonEncode(list));

    if (_canSyncToCloud) {
      _firestore.batchSaveContacts(_currentUserId!, contacts);
    }
  }

  Future<void> saveSingleContact(ContactModel contact) async {
    if (_canSyncToCloud) {
      _firestore.saveContact(_currentUserId!, contact);
    }
  }

  Future<void> deleteSingleContact(String contactId) async {
    if (_canSyncToCloud) {
      _firestore.deleteContact(_currentUserId!, contactId);
    }
  }

  // ================= Scoped Goals =================

  List<GoalModel> loadGoals() {
    final scopedKey = _workspaceKey('masrofaty_savings_goals');
    var jsonStr = _prefs.getString(scopedKey);

    if (jsonStr == null || jsonStr.isEmpty) {
      // Legacy un-scoped key
      jsonStr = _prefs.getString('masrofaty_savings_goals');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _prefs.setString(scopedKey, jsonStr);
      }
    }

    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => GoalModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveGoals(List<GoalModel> goals) async {
    final list = goals.map((g) => g.toJson()).toList();
    await _prefs.setString(_workspaceKey('masrofaty_savings_goals'), jsonEncode(list));

    if (_canSyncToCloud) {
      _firestore.batchSaveGoals(_currentUserId!, _effectiveWorkspaceId, goals);
    }
  }

  Future<void> saveSingleGoal(GoalModel goal) async {
    if (_canSyncToCloud) {
      _firestore.saveGoal(_currentUserId!, _effectiveWorkspaceId, goal);
    }
  }

  Future<void> deleteSingleGoal(String goalId) async {
    if (_canSyncToCloud) {
      _firestore.deleteGoal(_currentUserId!, goalId);
    }
  }

  // ================= Scoped Recurring Transactions =================

  List<RecurringTransactionModel> loadRecurringTransactions() {
    final scopedKey = _workspaceKey('masrofaty_recurring_txs');
    final jsonStr = _prefs.getString(scopedKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((item) => RecurringTransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecurringTransactions(List<RecurringTransactionModel> items) async {
    final list = items.map((r) => r.toJson()).toList();
    await _prefs.setString(_workspaceKey('masrofaty_recurring_txs'), jsonEncode(list));

    if (_canSyncToCloud) {
      _firestore.batchSaveRecurring(_currentUserId!, _effectiveWorkspaceId, items);
    }
  }

  Future<void> saveSingleRecurring(RecurringTransactionModel item) async {
    if (_canSyncToCloud) {
      _firestore.saveRecurring(_currentUserId!, _effectiveWorkspaceId, item);
    }
  }

  Future<void> deleteSingleRecurring(String recurringId) async {
    if (_canSyncToCloud) {
      _firestore.deleteRecurring(_currentUserId!, recurringId);
    }
  }

  // ================= Notifications =================

  List<AppNotification> loadNotifications() {
    final jsonStr = _prefs.getString(_userKey(AppConstants.keyNotifications));
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => AppNotification.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotifications(List<AppNotification> notifications) async {
    final list = notifications.map((n) => n.toJson()).toList();
    await _prefs.setString(_userKey(AppConstants.keyNotifications), jsonEncode(list));
  }

  // ================= Comprehensive Cloud Sync & Migration =================

  /// Synchronize all user data from Firestore into local cache
  Future<bool> syncFromCloud({String? userId, String? workspaceId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty || uid == 'guest') return false;
    final wid = workspaceId ?? _effectiveWorkspaceId;

    try {
      // 1. Categories
      final cats = await _firestore.fetchCategories(uid);
      if (cats.isNotEmpty) {
        await _prefs.setString(AppConstants.keyCategories, jsonEncode(cats.map((c) => c.toJson()).toList()));
      }

      // 2. Wallets
      final wallets = await _firestore.fetchWallets(uid, workspaceId: wid);
      if (wallets.isNotEmpty) {
        await _prefs.setString(_workspaceKey(AppConstants.keyWallets), jsonEncode(wallets.map((w) => w.toJson()).toList()));
      }

      // 3. Transactions
      final txs = await _firestore.fetchTransactions(uid, workspaceId: wid);
      if (txs.isNotEmpty) {
        await _prefs.setString(_workspaceKey(AppConstants.keyTransactions), jsonEncode(txs.map((t) => t.toJson()).toList()));
      }

      // 4. Debts
      final debts = await _firestore.fetchDebts(uid, workspaceId: wid);
      if (debts.isNotEmpty) {
        await _prefs.setString(_workspaceKey(AppConstants.keyDebts), jsonEncode(debts.map((d) => d.toJson()).toList()));
      }

      // 5. Goals
      final goals = await _firestore.fetchGoals(uid, workspaceId: wid);
      if (goals.isNotEmpty) {
        await _prefs.setString(_workspaceKey('masrofaty_savings_goals'), jsonEncode(goals.map((g) => g.toJson()).toList()));
      }

      // 6. Recurring
      final recurring = await _firestore.fetchRecurring(uid, workspaceId: wid);
      if (recurring.isNotEmpty) {
        await _prefs.setString(_workspaceKey('masrofaty_recurring_txs'), jsonEncode(recurring.map((r) => r.toJson()).toList()));
      }

      // 7. Contacts
      final contacts = await _firestore.fetchContacts(uid);
      if (contacts.isNotEmpty) {
        await _prefs.setString(_workspaceKey('masrofaty_contacts'), jsonEncode(contacts.map((c) => c.toJson()).toList()));
      }

      // 8. Workspaces
      final workspaces = await _firestore.fetchWorkspaces(uid);
      if (workspaces.isNotEmpty) {
        await _prefs.setString('masrofaty_workspaces_$uid', jsonEncode(workspaces.map((w) => w.toJson()).toList()));
      }

      // 9. SaaS Plan
      final plan = await _firestore.fetchSaaSPlan(uid);
      if (plan != null) {
        await _prefs.setString('masrofaty_saas_plan_$uid', jsonEncode(plan.toJson()));
      }

      // 10. Preferences
      final prefsData = await _firestore.fetchPreferences(uid);
      if (prefsData != null) {
        if (prefsData['currency'] is String) {
          await _prefs.setString(AppConstants.keyCurrency, prefsData['currency'] as String);
        }
        if (prefsData['themeMode'] is String) {
          await _prefs.setString(AppConstants.keyThemeMode, prefsData['themeMode'] as String);
        }
        if (prefsData['hideBalance'] is bool) {
          await _prefs.setBool(AppConstants.keyHideBalance, prefsData['hideBalance'] as bool);
        }
      }

      debugPrint('[StorageService] Successfully synced user $uid data from Firestore');
      return true;
    } catch (e) {
      debugPrint('[StorageService] Error syncing from Firestore: $e');
      return false;
    }
  }

  /// Upload all local records to Firestore
  Future<bool> uploadAllLocalToCloud({String? userId, String? workspaceId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty || uid == 'guest') return false;
    final wid = workspaceId ?? _effectiveWorkspaceId;

    try {
      // 1. Categories
      final cats = loadCategories();
      if (cats.isNotEmpty) {
        await _firestore.batchSaveCategories(uid, cats);
      }

      // 2. Wallets
      final wallets = loadWallets();
      if (wallets.isNotEmpty) {
        await _firestore.batchSaveWallets(uid, wid, wallets);
      }

      // 3. Transactions
      final txs = loadTransactions();
      if (txs.isNotEmpty) {
        await _firestore.batchSaveTransactions(uid, wid, txs);
      }

      // 4. Debts
      final debts = loadDebts();
      if (debts.isNotEmpty) {
        await _firestore.batchSaveDebts(uid, wid, debts);
      }

      // 5. Goals
      final goals = loadGoals();
      if (goals.isNotEmpty) {
        await _firestore.batchSaveGoals(uid, wid, goals);
      }

      // 6. Recurring
      final recurring = loadRecurringTransactions();
      if (recurring.isNotEmpty) {
        await _firestore.batchSaveRecurring(uid, wid, recurring);
      }

      // 7. Contacts
      final contacts = loadContacts();
      if (contacts.isNotEmpty) {
        await _firestore.batchSaveContacts(uid, contacts);
      }

      // 8. Workspaces
      final workspaces = loadWorkspaces(uid);
      if (workspaces.isNotEmpty) {
        await _firestore.batchSaveWorkspaces(uid, workspaces);
      }

      // 9. SaaS Plan
      final plan = loadSaaSPlan(uid);
      await _firestore.saveSaaSPlan(uid, plan);

      // 10. Preferences
      await _firestore.savePreferences(uid, {
        'currency': getCurrencySymbol(),
        'themeMode': getThemeMode(),
        'hideBalance': getHideBalance(),
      });

      debugPrint('[StorageService] Successfully uploaded user $uid data to Firestore');
      return true;
    } catch (e) {
      debugPrint('[StorageService] Error uploading to Firestore: $e');
      return false;
    }
  }

  /// Smart initialization on login: restores from cloud if available, else seeds cloud with initial data
  Future<void> initOrMigrateUser(String userId, {String? workspaceId}) async {
    if (userId.isEmpty || userId == 'guest') return;
    try {
      final hasCloud = await _firestore.hasCloudData(userId);
      if (hasCloud) {
        await syncFromCloud(userId: userId, workspaceId: workspaceId);
      } else {
        await uploadAllLocalToCloud(userId: userId, workspaceId: workspaceId);
      }
    } catch (e) {
      debugPrint('[StorageService] Error during initOrMigrateUser: $e');
    }
  }

  /// Initialize newly registered user with clean, zeroed financial data (0.00 SAR)
  Future<void> migrateGuestDataToUser(String newUserId) async {
    final defaultWsId = 'ws_personal_$newUserId';
    final userTxKey = '${AppConstants.keyTransactions}_${newUserId}_$defaultWsId';
    final userWalletKey = '${AppConstants.keyWallets}_${newUserId}_$defaultWsId';
    final userDebtKey = '${AppConstants.keyDebts}_${newUserId}_$defaultWsId';
    final userGoalsKey = 'masrofaty_savings_goals_${newUserId}_$defaultWsId';

    // Explicitly initialize with zero transactions and zero debts
    if (!_prefs.containsKey(userTxKey)) {
      await _prefs.setString(userTxKey, jsonEncode([]));
    }
    if (!_prefs.containsKey(userDebtKey)) {
      await _prefs.setString(userDebtKey, jsonEncode([]));
    }
    if (!_prefs.containsKey(userGoalsKey)) {
      await _prefs.setString(userGoalsKey, jsonEncode([]));
    }

    // Initialize clean wallets with 0.00 balance
    if (!_prefs.containsKey(userWalletKey)) {
      final zeroWallets = [
        {'id': 'wallet_cash', 'name': 'نقدي (كاش)', 'type': 'cash', 'balance': 0.0, 'iconCode': 0xe481, 'colorValue': 0xFF10B981},
        {'id': 'wallet_bank', 'name': 'الحساب البنكي', 'type': 'bank', 'balance': 0.0, 'iconCode': 0xe040, 'colorValue': 0xFF3B82F6},
        {'id': 'wallet_card', 'name': 'البطاقة الائتمانية', 'type': 'card', 'balance': 0.0, 'iconCode': 0xe19f, 'colorValue': 0xFF8B5CF6},
        {'id': 'wallet_savings', 'name': 'محفظة التوفير', 'type': 'savings', 'balance': 0.0, 'iconCode': 0xe556, 'colorValue': 0xFFF59E0B},
      ];
      await _prefs.setString(userWalletKey, jsonEncode(zeroWallets));
    }

    // Also sync the initialized state into Firestore
    if (newUserId.isNotEmpty && newUserId != 'guest') {
      await uploadAllLocalToCloud(userId: newUserId, workspaceId: defaultWsId);
    }
  }

  /// Zero out all financial data for current session (reset to 0.00 SAR)
  Future<void> zeroCurrentFinancialData() async {
    await saveTransactions([]);
    await saveDebts([]);
    await saveGoals([]);
    final currentWallets = loadWallets();
    final zeroedWallets = currentWallets.map((w) => w.copyWith(balance: 0.0)).toList();
    await saveWallets(zeroedWallets);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
