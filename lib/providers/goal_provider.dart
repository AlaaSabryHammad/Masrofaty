import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/services/storage_service.dart';
import '../models/goal_model.dart';
import 'finance_provider.dart';

class GoalProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<GoalModel> _goals = [];

  GoalProvider(this._storage) {
    _loadGoals();
  }

  List<GoalModel> get goals => _goals;

  double get totalSavedInGoals => _goals.fold(0.0, (sum, g) => sum + g.savedAmount);
  double get totalTargetGoals => _goals.fold(0.0, (sum, g) => sum + g.targetAmount);

  void _loadGoals() {
    _goals = _storage.loadGoals();
  }

  void reload() {
    _loadGoals();
    notifyListeners();
  }

  Future<void> resetAllData() async {
    _goals.clear();
    await _saveGoals();
    notifyListeners();
  }

  Future<void> restoreGoals(List<GoalModel> newGoals) async {
    _goals = newGoals;
    await _saveGoals();
    notifyListeners();
  }

  Future<void> _saveGoals() async {
    await _storage.saveGoals(_goals);
  }

  Future<void> addGoal({
    required String title,
    required double targetAmount,
    double initialDeposit = 0.0,
    DateTime? targetDate,
    required int iconCode,
    required int colorValue,
    FinanceProvider? finance,
    String? fromWalletId,
  }) async {
    final goal = GoalModel(
      id: _uuid.v4(),
      title: title,
      targetAmount: targetAmount,
      savedAmount: initialDeposit,
      targetDate: targetDate,
      iconCode: iconCode,
      colorValue: colorValue,
    );

    _goals.insert(0, goal);
    await _saveGoals();

    if (initialDeposit > 0 && finance != null && fromWalletId != null) {
      finance.addTransaction(
        title: 'إيداع في هدف "$title"',
        amount: initialDeposit,
        type: 'expense',
        categoryId: 'cat_investment',
        walletId: fromWalletId,
        date: DateTime.now(),
        notes: 'تغذية صندوق الادخار',
      );
    }

    notifyListeners();
  }

  Future<void> depositToGoal({
    required String goalId,
    required double amount,
    required FinanceProvider finance,
    required String fromWalletId,
  }) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      final goal = _goals[idx];
      _goals[idx] = goal.copyWith(savedAmount: goal.savedAmount + amount);
      await _saveGoals();

      finance.addTransaction(
        title: 'إيداع في هدف "${goal.title}"',
        amount: amount,
        type: 'expense',
        categoryId: 'cat_investment',
        walletId: fromWalletId,
        date: DateTime.now(),
        notes: 'تحويل إلى هدف التوفير',
      );

      notifyListeners();
    }
  }

  Future<bool> withdrawFromGoal({
    required String goalId,
    required double amount,
    required FinanceProvider finance,
    required String toWalletId,
    String? notes,
  }) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx == -1) return false;
    final goal = _goals[idx];
    if (amount <= 0 || amount > goal.savedAmount) return false;

    _goals[idx] = goal.copyWith(savedAmount: goal.savedAmount - amount);
    await _saveGoals();

    finance.addTransaction(
      title: 'سحب من هدف "${goal.title}"',
      amount: amount,
      type: 'income',
      categoryId: 'cat_investment',
      walletId: toWalletId,
      date: DateTime.now(),
      notes: notes ?? 'سحب / استرداد مدخرات من هدف التوفير',
    );

    notifyListeners();
    return true;
  }

  Future<void> updateGoal({
    required String goalId,
    required String title,
    required double targetAmount,
    DateTime? targetDate,
    required int iconCode,
    required int colorValue,
  }) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      final current = _goals[idx];
      _goals[idx] = current.copyWith(
        title: title,
        targetAmount: targetAmount,
        targetDate: targetDate,
        iconCode: iconCode,
        colorValue: colorValue,
      );
      await _saveGoals();
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _saveGoals();
    await _storage.deleteSingleGoal(id);
    notifyListeners();
  }
}
