import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/services/storage_service.dart';
import '../models/recurring_transaction_model.dart';
import 'finance_provider.dart';

class RecurringProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<RecurringTransactionModel> _items = [];

  RecurringProvider(this._storage) {
    _loadRecurring();
  }

  List<RecurringTransactionModel> get items => _items;
  List<RecurringTransactionModel> get recurringTransactions => _items;

  List<RecurringTransactionModel> get activeItems => _items.where((i) => i.isActive).toList();

  double get totalMonthlyRecurringExpense {
    return activeItems.where((i) => i.isExpense).fold(0.0, (sum, i) {
      switch (i.frequency) {
        case 'daily':
          return sum + (i.amount * 30);
        case 'weekly':
          return sum + (i.amount * 4.33);
        case 'yearly':
          return sum + (i.amount / 12);
        case 'monthly':
        default:
          return sum + i.amount;
      }
    });
  }

  double get totalMonthlyRecurringIncome {
    return activeItems.where((i) => i.isIncome).fold(0.0, (sum, i) {
      switch (i.frequency) {
        case 'daily':
          return sum + (i.amount * 30);
        case 'weekly':
          return sum + (i.amount * 4.33);
        case 'yearly':
          return sum + (i.amount / 12);
        case 'monthly':
        default:
          return sum + i.amount;
      }
    });
  }

  void _loadRecurring() {
    _items = _storage.loadRecurringTransactions();
  }

  void reload() {
    _loadRecurring();
    notifyListeners();
  }

  Future<void> _save() async {
    await _storage.saveRecurringTransactions(_items);
  }

  Future<void> restoreRecurring(List<RecurringTransactionModel> newItems) async {
    _items = newItems;
    await _save();
    notifyListeners();
  }

  Future<void> addRecurring({
    required String title,
    required double amount,
    required String type,
    required String categoryId,
    required String walletId,
    required String frequency,
    required DateTime startDate,
    String? notes,
  }) async {
    final newItem = RecurringTransactionModel(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      walletId: walletId,
      frequency: frequency,
      startDate: startDate,
      nextDueDate: startDate,
      isActive: true,
      notes: notes,
    );

    _items.insert(0, newItem);
    await _save();
    notifyListeners();
  }

  Future<void> updateRecurring(RecurringTransactionModel updated) async {
    final index = _items.indexWhere((i) => i.id == updated.id);
    if (index != -1) {
      _items[index] = updated;
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteRecurring(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> toggleActive(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final current = _items[index];
      _items[index] = current.copyWith(isActive: !current.isActive);
      await _save();
      notifyListeners();
    }
  }

  /// Automatically checks due recurring transactions and applies them to FinanceProvider
  Future<int> checkAndProcessDueTransactions(FinanceProvider finance) async {
    return checkAndExecuteDue(finance);
  }

  Future<int> checkAndExecuteDue(FinanceProvider finance) async {
    int processedCount = 0;
    bool modified = false;

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isDueNow) {
        // Post transaction
        await finance.addTransaction(
          title: item.title,
          amount: item.amount,
          type: item.type,
          categoryId: item.categoryId,
          walletId: item.walletId,
          date: DateTime.now(),
          notes: 'معاملة دورية مجدولة (${item.frequencyLabel})${item.notes != null ? ' - ${item.notes}' : ''}',
        );

        // Advance to next due date
        final nextDate = item.calculateNextDueDate(item.nextDueDate);
        _items[i] = item.copyWith(
          nextDueDate: nextDate,
          lastProcessedDate: DateTime.now(),
        );

        processedCount++;
        modified = true;
      }
    }

    if (modified) {
      await _save();
      notifyListeners();
    }

    return processedCount;
  }
}
