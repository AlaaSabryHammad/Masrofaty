import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/default_categories.dart';
import '../core/services/storage_service.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';

enum TimeFilter { today, week, month, all, custom }

class FinanceProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  List<WalletModel> _wallets = [];

  // Filter state
  TimeFilter _currentTimeFilter = TimeFilter.month;
  String? _selectedCategoryId;
  String? _selectedWalletId;
  String _searchQuery = '';
  DateTimeRange? _customDateRange;

  FinanceProvider(this._storage) {
    _initialize();
  }

  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get categories => _categories;
  List<WalletModel> get wallets => _wallets;

  TimeFilter get currentTimeFilter => _currentTimeFilter;
  String? get selectedCategoryId => _selectedCategoryId;
  String? get selectedWalletId => _selectedWalletId;
  String get searchQuery => _searchQuery;
  DateTimeRange? get customDateRange => _customDateRange;

  void _initialize() {
    _categories = _storage.loadCategories();
    if (_categories.isEmpty) {
      _categories = DefaultData.categories;
      _storage.saveCategories(_categories);
    }

    _wallets = _storage.loadWallets();
    if (_wallets.isEmpty) {
      _wallets = DefaultData.defaultWallets;
      _storage.saveWallets(_wallets);
    }

    _transactions = _storage.loadTransactions();
  }

  void reload() {
    _initialize();
    notifyListeners();
  }

  Future<void> resetAllData() async {
    _transactions.clear();
    _wallets = _wallets.map((w) => w.copyWith(balance: 0.0)).toList();
    await _storage.saveTransactions(_transactions);
    await _storage.saveWallets(_wallets);
    notifyListeners();
  }

  Future<void> restoreData({
    List<TransactionModel>? transactions,
    List<WalletModel>? wallets,
    List<CategoryModel>? categories,
  }) async {
    if (categories != null && categories.isNotEmpty) {
      _categories = categories;
      await _storage.saveCategories(_categories);
    }
    if (wallets != null && wallets.isNotEmpty) {
      _wallets = wallets;
      await _storage.saveWallets(_wallets);
    }
    if (transactions != null) {
      _transactions = transactions;
      await _storage.saveTransactions(_transactions);
    }
    notifyListeners();
  }

  // Setters for filters
  void setTimeFilter(TimeFilter filter, {DateTimeRange? customRange}) {
    _currentTimeFilter = filter;
    _customDateRange = customRange;
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setWalletFilter(String? walletId) {
    _selectedWalletId = walletId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Filtered Transactions
  List<TransactionModel> get filteredTransactions {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_currentTimeFilter) {
      case TimeFilter.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case TimeFilter.week:
        startDate = now.subtract(Duration(days: now.weekday % 7));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case TimeFilter.month:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case TimeFilter.custom:
        if (_customDateRange != null) {
          startDate = _customDateRange!.start;
          endDate = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
            23,
            59,
            59,
          );
        } else {
          startDate = DateTime(now.year, now.month, 1);
        }
        break;
      case TimeFilter.all:
        startDate = DateTime(2000);
        break;
    }

    return _transactions.where((t) {
      final matchesDate = t.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(endDate.add(const Duration(seconds: 1)));
      if (!matchesDate) return false;

      if (_selectedCategoryId != null && t.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_selectedWalletId != null && t.walletId != _selectedWalletId) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = t.title.toLowerCase().contains(q);
        final matchesNotes = t.notes?.toLowerCase().contains(q) ?? false;
        if (!matchesTitle && !matchesNotes) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Balance & Financial Metrics
  double get totalBalance {
    return _wallets.fold(0.0, (sum, w) => sum + w.balance);
  }

  double get totalBankBalance => _wallets
      .where((w) => w.type == 'bank' || w.type == 'card')
      .fold(0.0, (sum, w) => sum + w.balance);

  double get totalCashBalance => _wallets
      .where((w) => w.type == 'cash')
      .fold(0.0, (sum, w) => sum + w.balance);

  double get totalSavingsBalance => _wallets
      .where((w) => w.type == 'savings' || w.type == 'digital')
      .fold(0.0, (sum, w) => sum + w.balance);

  double get totalLiquidBalance => totalBalance;

  Future<void> adjustWalletBalance(String walletId, double delta) async {
    final idx = _wallets.indexWhere((w) => w.id == walletId);
    if (idx != -1) {
      final current = _wallets[idx];
      _wallets[idx] = current.copyWith(balance: current.balance + delta);
      await _storage.saveWallets(_wallets);
      notifyListeners();
    }
  }

  double get monthlyIncome {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return _transactions
        .where((t) => t.isIncome && t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlyExpense {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return _transactions
        .where((t) => t.isExpense && t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlySavings => monthlyIncome - monthlyExpense;

  double getCategoryMonthlySpent(String categoryId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return _transactions
        .where((t) =>
            t.categoryId == categoryId &&
            t.isExpense &&
            t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Category & Wallet lookups
  CategoryModel? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  WalletModel? getWalletById(String id) {
    try {
      return _wallets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  // CRUD Transactions
  Future<void> addTransaction({
    required String title,
    required double amount,
    required String type,
    required String categoryId,
    required String walletId,
    String? toWalletId,
    required DateTime date,
    String? notes,
    String? personName,
    String? contactId,
  }) async {
    final newTransaction = TransactionModel(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      toWalletId: toWalletId,
      date: date,
      notes: notes,
      personName: personName,
      contactId: contactId,
    );

    _transactions.insert(0, newTransaction);
    _updateWalletBalanceForNewTx(newTransaction);

    await _storage.saveTransactions(_transactions);
    await _storage.saveWallets(_wallets);
    notifyListeners();
  }

  Future<void> updateTransaction(TransactionModel updated) async {
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;

    final oldTx = _transactions[index];
    _revertWalletBalanceForTx(oldTx);

    _transactions[index] = updated;
    _updateWalletBalanceForNewTx(updated);

    await _storage.saveTransactions(_transactions);
    await _storage.saveWallets(_wallets);
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final tx = _transactions[index];
    _revertWalletBalanceForTx(tx);
    _transactions.removeAt(index);

    await _storage.saveTransactions(_transactions);
    await _storage.saveWallets(_wallets);
    notifyListeners();
  }

  void _updateWalletBalanceForNewTx(TransactionModel tx) {
    final walletIdx = _wallets.indexWhere((w) => w.id == tx.walletId);
    if (walletIdx != -1) {
      final current = _wallets[walletIdx];
      double newBalance = current.balance;

      if (tx.isExpense) {
        newBalance -= tx.amount;
      } else if (tx.isIncome) {
        newBalance += tx.amount;
      } else if (tx.isTransfer && tx.toWalletId != null) {
        newBalance -= tx.amount;
        final targetIdx = _wallets.indexWhere((w) => w.id == tx.toWalletId);
        if (targetIdx != -1) {
          _wallets[targetIdx] = _wallets[targetIdx].copyWith(
            balance: _wallets[targetIdx].balance + tx.amount,
          );
        }
      }
      _wallets[walletIdx] = current.copyWith(balance: newBalance);
    }
  }

  void _revertWalletBalanceForTx(TransactionModel tx) {
    final walletIdx = _wallets.indexWhere((w) => w.id == tx.walletId);
    if (walletIdx != -1) {
      final current = _wallets[walletIdx];
      double newBalance = current.balance;

      if (tx.isExpense) {
        newBalance += tx.amount;
      } else if (tx.isIncome) {
        newBalance -= tx.amount;
      } else if (tx.isTransfer && tx.toWalletId != null) {
        newBalance += tx.amount;
        final targetIdx = _wallets.indexWhere((w) => w.id == tx.toWalletId);
        if (targetIdx != -1) {
          _wallets[targetIdx] = _wallets[targetIdx].copyWith(
            balance: _wallets[targetIdx].balance - tx.amount,
          );
        }
      }
      _wallets[walletIdx] = current.copyWith(balance: newBalance);
    }
  }

  // Wallets management
  Future<void> addWallet({
    required String name,
    required String type,
    required double initialBalance,
    required int iconCode,
    required int colorValue,
  }) async {
    final newWallet = WalletModel(
      id: _uuid.v4(),
      name: name,
      type: type,
      balance: initialBalance,
      iconCode: iconCode,
      colorValue: colorValue,
    );
    _wallets.add(newWallet);
    await _storage.saveWallets(_wallets);
    notifyListeners();
  }

  Future<void> updateWallet(WalletModel updated) async {
    final index = _wallets.indexWhere((w) => w.id == updated.id);
    if (index != -1) {
      _wallets[index] = updated;
      await _storage.saveWallets(_wallets);
      notifyListeners();
    }
  }

  Future<bool> deleteWallet(String walletId) async {
    if (_wallets.length <= 1) return false;
    final index = _wallets.indexWhere((w) => w.id == walletId);
    if (index == -1) return false;

    _wallets.removeAt(index);
    await _storage.saveWallets(_wallets);
    notifyListeners();
    return true;
  }

  Future<void> transferBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    String? notes,
  }) async {
    await addTransaction(
      title: 'تحويل بين الحسابات',
      amount: amount,
      type: 'transfer',
      categoryId: 'cat_other_exp',
      walletId: fromWalletId,
      toWalletId: toWalletId,
      date: DateTime.now(),
      notes: notes,
    );
  }

  // Category management
  Future<void> addCategory({
    required String name,
    required bool isExpense,
    required int iconCode,
    required int colorValue,
    double budgetLimit = 0.0,
  }) async {
    final newCat = CategoryModel(
      id: 'cat_custom_${_uuid.v4().substring(0, 8)}',
      name: name,
      iconCode: iconCode,
      colorValue: colorValue,
      isExpense: isExpense,
      budgetLimit: budgetLimit,
    );
    _categories.add(newCat);
    await _storage.saveCategories(_categories);
    notifyListeners();
  }

  Future<void> updateCategory(CategoryModel updated) async {
    final index = _categories.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _categories[index] = updated;
      await _storage.saveCategories(_categories);
      notifyListeners();
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    // Keep at least one expense and one income category
    final cat = getCategoryById(categoryId);
    if (cat == null) return false;

    final sameTypeCount = _categories.where((c) => c.isExpense == cat.isExpense).length;
    if (sameTypeCount <= 1) return false;

    // Re-assign transactions with this category to a fallback category
    final fallbackCat = _categories.firstWhere(
      (c) => c.isExpense == cat.isExpense && c.id != categoryId,
    );

    bool txModified = false;
    for (int i = 0; i < _transactions.length; i++) {
      if (_transactions[i].categoryId == categoryId) {
        _transactions[i] = _transactions[i].copyWith(categoryId: fallbackCat.id);
        txModified = true;
      }
    }

    _categories.removeWhere((c) => c.id == categoryId);
    await _storage.saveCategories(_categories);
    if (txModified) {
      await _storage.saveTransactions(_transactions);
    }
    notifyListeners();
    return true;
  }

  Future<void> updateCategoryBudget(String categoryId, double newLimit) async {
    final idx = _categories.indexWhere((c) => c.id == categoryId);
    if (idx != -1) {
      _categories[idx] = _categories[idx].copyWith(budgetLimit: newLimit);
      await _storage.saveCategories(_categories);
      notifyListeners();
    }
  }

  // Analytics Helpers
  Map<String, double> getExpenseDistribution() {
    final distribution = <String, double>{};
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    for (final tx in _transactions) {
      if (tx.isExpense && tx.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))) {
        distribution[tx.categoryId] = (distribution[tx.categoryId] ?? 0.0) + tx.amount;
      }
    }
    return distribution;
  }

  double getIncomeForMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return _transactions
        .where((t) => t.isIncome && !t.date.isBefore(start) && !t.date.isAfter(end))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getExpenseForMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return _transactions
        .where((t) => t.isExpense && !t.date.isBefore(start) && !t.date.isAfter(end))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> getExpenseDistributionForMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final map = <String, double>{};
    for (final t in _transactions) {
      if (t.isExpense && !t.date.isBefore(start) && !t.date.isAfter(end)) {
        map[t.categoryId] = (map[t.categoryId] ?? 0.0) + t.amount;
      }
    }
    return map;
  }

  double getCategorySpentForMonth(String categoryId, int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return _transactions
        .where((t) =>
            t.categoryId == categoryId &&
            t.isExpense &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(end))
        .fold(0.0, (sum, t) => sum + t.amount);
  }
}
