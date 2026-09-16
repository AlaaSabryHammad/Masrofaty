import 'package:flutter/material.dart';
import '../core/services/storage_service.dart';
import '../core/services/notification_service.dart';
import '../models/app_notification.dart';
import '../models/debt_model.dart';
import '../models/category_model.dart';

class NotificationProvider extends ChangeNotifier {
  final StorageService _storage;
  List<AppNotification> _notifications = [];

  NotificationProvider(this._storage) {
    _initialize();
  }

  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _initialize() {
    _notifications = _storage.loadNotifications();
  }

  void checkSystemAlerts({
    required List<DebtModel> debts,
    required List<CategoryModel> categories,
    required double Function(String categoryId) getSpentForCategory,
  }) {
    final debtAlerts = NotificationService.checkDebtAlerts(debts);
    bool addedNew = false;

    for (final alert in debtAlerts) {
      // Check if similar alert already exists within the last 24 hours
      final exists = _notifications.any((n) =>
          n.title == alert.title &&
          n.message == alert.message &&
          n.date.difference(alert.date).inHours.abs() < 24);
      if (!exists) {
        _notifications.insert(0, alert);
        addedNew = true;
      }
    }

    for (final cat in categories) {
      final spent = getSpentForCategory(cat.id);
      final budgetAlert = NotificationService.checkBudgetThreshold(cat, spent);
      if (budgetAlert != null) {
        final exists = _notifications.any((n) =>
            n.title == budgetAlert.title &&
            n.message == budgetAlert.message &&
            n.date.difference(budgetAlert.date).inHours.abs() < 24);
        if (!exists) {
          _notifications.insert(0, budgetAlert);
          addedNew = true;
        }
      }
    }

    if (addedNew) {
      _storage.saveNotifications(_notifications);
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      await _storage.saveNotifications(_notifications);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _storage.saveNotifications(_notifications);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _storage.saveNotifications(_notifications);
    notifyListeners();
  }
}
