import 'dart:convert';
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

class StorageService {
  final SharedPreferences _prefs;

  SharedPreferences get prefs => _prefs;

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
  }

  // Theme Mode
  String getThemeMode() {
    return _prefs.getString(AppConstants.keyThemeMode) ?? 'system';
  }

  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(AppConstants.keyThemeMode, mode);
  }

  // Hide Balance
  bool getHideBalance() {
    return _prefs.getBool(AppConstants.keyHideBalance) ?? false;
  }

  Future<void> saveHideBalance(bool hide) async {
    await _prefs.setBool(AppConstants.keyHideBalance, hide);
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
  }

  // Categories (shared or scoped)
  List<CategoryModel> loadCategories() {
    final jsonStr = _prefs.getString(AppConstants.keyCategories);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => CategoryModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCategories(List<CategoryModel> categories) async {
    final list = categories.map((c) => c.toJson()).toList();
    await _prefs.setString(AppConstants.keyCategories, jsonEncode(list));
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
      return list.map((item) => WalletModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveWallets(List<WalletModel> wallets) async {
    final list = wallets.map((w) => w.toJson()).toList();
    await _prefs.setString(_workspaceKey(AppConstants.keyWallets), jsonEncode(list));
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
