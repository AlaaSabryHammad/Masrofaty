import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/services/storage_service.dart';
import '../models/debt_model.dart';

enum DebtFilterType { all, lent, borrowed }
enum DebtFilterStatus { all, active, settled, overdue }

class DebtProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<DebtModel> _debts = [];
  DebtFilterType _filterType = DebtFilterType.all;
  DebtFilterStatus _filterStatus = DebtFilterStatus.all;
  String _searchQuery = '';

  DebtProvider(this._storage) {
    _initialize();
  }

  List<DebtModel> get debts => _debts;
  DebtFilterType get filterType => _filterType;
  DebtFilterStatus get filterStatus => _filterStatus;
  String get searchQuery => _searchQuery;

  void _initialize() {
    _debts = _storage.loadDebts();
  }

  void reload() {
    _initialize();
    notifyListeners();
  }

  Future<void> resetAllData() async {
    _debts.clear();
    await _storage.saveDebts(_debts);
    notifyListeners();
  }

  Future<void> restoreDebts(List<DebtModel> newDebts) async {
    _debts = newDebts;
    await _storage.saveDebts(_debts);
    notifyListeners();
  }

  void setFilterType(DebtFilterType type) {
    _filterType = type;
    notifyListeners();
  }

  void setFilterStatus(DebtFilterStatus status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<DebtModel> get filteredDebts {
    return _debts.where((debt) {
      // Filter by type
      if (_filterType == DebtFilterType.lent && !debt.isLent) return false;
      if (_filterType == DebtFilterType.borrowed && !debt.isBorrowed) return false;

      // Filter by status
      if (_filterStatus == DebtFilterStatus.active && debt.isSettled) return false;
      if (_filterStatus == DebtFilterStatus.settled && !debt.isSettled) return false;
      if (_filterStatus == DebtFilterStatus.overdue && !debt.isOverdue) return false;

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = debt.personName.toLowerCase().contains(q);
        final matchPhone = debt.phone?.toLowerCase().contains(q) ?? false;
        final matchNotes = debt.notes?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchPhone && !matchNotes) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        // Unsettled first, then closest due date
        if (a.isSettled != b.isSettled) {
          return a.isSettled ? 1 : -1;
        }
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        return b.createdDate.compareTo(a.createdDate);
      });
  }

  // Summary Metrics
  double get totalLent => _debts.where((d) => d.isLent).fold(0.0, (sum, d) => sum + d.totalAmount);
  double get totalLentRemaining => _debts.where((d) => d.isLent).fold(0.0, (sum, d) => sum + d.remainingAmount);

  double get totalBorrowed => _debts.where((d) => d.isBorrowed).fold(0.0, (sum, d) => sum + d.totalAmount);
  double get totalBorrowedRemaining => _debts.where((d) => d.isBorrowed).fold(0.0, (sum, d) => sum + d.remainingAmount);

  int get overdueCount => _debts.where((d) => d.isOverdue).length;
  int get dueSoonCount => _debts.where((d) => d.isDueSoon || d.isDueToday).length;
  int get activeDebtsCount => _debts.where((d) => !d.isSettled).length;
  int get settledDebtsCount => _debts.where((d) => d.isSettled).length;

  // CRUD Operations
  Future<void> addDebt({
    required String personName,
    String? phone,
    required double totalAmount,
    required String type,
    DateTime? dueDate,
    String? notes,
    String? walletId,
    String? walletName,
  }) async {
    final debt = DebtModel(
      id: _uuid.v4(),
      personName: personName,
      phone: phone,
      totalAmount: totalAmount,
      type: type,
      createdDate: DateTime.now(),
      dueDate: dueDate,
      notes: notes,
      walletId: walletId,
      walletName: walletName,
      payments: [],
    );

    _debts.insert(0, debt);
    await _storage.saveDebts(_debts);
    notifyListeners();
  }

  Future<void> updateDebt(DebtModel updated) async {
    final index = _debts.indexWhere((d) => d.id == updated.id);
    if (index != -1) {
      _debts[index] = updated;
      await _storage.saveDebts(_debts);
      notifyListeners();
    }
  }

  Future<void> deleteDebt(String id) async {
    _debts.removeWhere((d) => d.id == id);
    await _storage.saveDebts(_debts);
    await _storage.deleteSingleDebt(id);
    notifyListeners();
  }

  Future<void> addPayment({
    required String debtId,
    required double amount,
    String? notes,
    DateTime? date,
    String? walletId,
    String? walletName,
  }) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      final payment = DebtPayment(
        id: _uuid.v4(),
        amount: amount,
        date: date ?? DateTime.now(),
        notes: notes,
        walletId: walletId,
        walletName: walletName,
      );
      final current = _debts[index];
      final updatedPayments = List<DebtPayment>.from(current.payments)..add(payment);
      _debts[index] = current.copyWith(payments: updatedPayments);
      await _storage.saveDebts(_debts);
      notifyListeners();
    }
  }

  Future<void> settleDebtFully(String debtId, {String? walletId, String? walletName}) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      final current = _debts[index];
      if (current.remainingAmount > 0) {
        await addPayment(
          debtId: debtId,
          amount: current.remainingAmount,
          notes: 'إغلاق وتسوية الدين بالكامل',
          walletId: walletId,
          walletName: walletName,
        );
      }
    }
  }
}
