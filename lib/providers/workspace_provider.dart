import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/services/storage_service.dart';
import '../models/workspace_model.dart';
import '../models/saas_plan_model.dart';
import '../models/wallet_model.dart';

class WorkspaceProvider extends ChangeNotifier {
  final StorageService _storage;
  final VoidCallback? _onWorkspaceSwitched;
  final Uuid _uuid = const Uuid();

  String? _currentUserId;
  List<WorkspaceModel> _workspaces = [];
  WorkspaceModel? _activeWorkspace;
  SaaSPlanModel _currentPlan = SaaSPlanModel.starter();
  bool _isLoading = false;

  WorkspaceProvider(this._storage, [this._onWorkspaceSwitched]) {
    final uid = _storage.currentUserId;
    if (uid != null && uid.isNotEmpty) {
      initForUser(uid);
    }
  }

  bool get isLoading => _isLoading;
  List<WorkspaceModel> get workspaces => _workspaces;
  SaaSPlanModel get currentPlan => _currentPlan;
  String? get currentUserId => _currentUserId;

  WorkspaceModel get activeWorkspace {
    if (_activeWorkspace != null) return _activeWorkspace!;
    if (_workspaces.isNotEmpty) return _workspaces.first;
    return WorkspaceModel.defaultWorkspace(userId: _currentUserId ?? 'guest');
  }

  int get maxWorkspaces => _currentPlan.tier.maxWorkspaces;
  bool get canAddWorkspace => _workspaces.length < _currentPlan.tier.maxWorkspaces;
  int get remainingWorkspaces =>
      (_currentPlan.tier.maxWorkspaces - _workspaces.length).clamp(0, 999);
  bool get isPro => _currentPlan.tier != SaaSTier.starter;

  void initForUser(String userId) {
    _currentUserId = userId;
    _isLoading = true;
    notifyListeners();

    _workspaces = _storage.loadWorkspaces(userId);
    _currentPlan = _storage.loadSaaSPlan(userId);

    final activeId = _storage.getActiveWorkspaceId(userId);
    if (activeId != null) {
      try {
        _activeWorkspace = _workspaces.firstWhere((w) => w.id == activeId);
      } catch (_) {
        _activeWorkspace = _workspaces.first;
      }
    } else {
      _activeWorkspace = _workspaces.first;
    }

    _storage.setCurrentWorkspaceId(_activeWorkspace?.id);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> switchWorkspace(String workspaceId) async {
    if (_activeWorkspace?.id == workspaceId) return;

    try {
      final target = _workspaces.firstWhere((w) => w.id == workspaceId);
      _activeWorkspace = target;
      _storage.setCurrentWorkspaceId(workspaceId);

      if (_currentUserId != null) {
        await _storage.setActiveWorkspaceId(_currentUserId!, workspaceId);
      }

      // Sync active currency symbol
      await _storage.saveCurrencySymbol(target.currencySymbol);

      _onWorkspaceSwitched?.call();
      notifyListeners();
    } catch (_) {}
  }

  Future<WorkspaceModel?> createWorkspace({
    required String name,
    required WorkspaceType type,
    String currency = 'SAR',
    String currencySymbol = 'ر.س',
    String? description,
    String? taxNumber,
    int? iconCode,
    int? colorValue,
  }) async {
    if (!canAddWorkspace) return null;

    final userId = _currentUserId ?? 'guest';
    final newWsId = 'ws_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 6)}';

    final newWs = WorkspaceModel(
      id: newWsId,
      userId: userId,
      name: name.trim(),
      type: type,
      currency: currency,
      currencySymbol: currencySymbol,
      iconCode: iconCode ?? type.icon.codePoint,
      colorValue: colorValue ?? type.defaultColor.toARGB32(),
      isDefault: false,
      createdAt: DateTime.now(),
      description: description?.trim(),
      taxNumber: taxNumber?.trim(),
    );

    _workspaces.add(newWs);
    await _storage.saveWorkspaces(userId, _workspaces);

    // Auto-generate smart initial wallets tailored for this workspace type
    final initialWallets = _generateDefaultWalletsForType(type, newWsId);
    final previousWsId = _storage.currentWorkspaceId;
    _storage.setCurrentWorkspaceId(newWsId);
    await _storage.saveWallets(initialWallets);
    _storage.setCurrentWorkspaceId(previousWsId);

    // Switch to new workspace immediately
    await switchWorkspace(newWsId);

    return newWs;
  }

  Future<void> updateWorkspace(WorkspaceModel updated) async {
    final idx = _workspaces.indexWhere((w) => w.id == updated.id);
    if (idx != -1) {
      _workspaces[idx] = updated;
      if (_activeWorkspace?.id == updated.id) {
        _activeWorkspace = updated;
      }
      if (_currentUserId != null) {
        await _storage.saveWorkspaces(_currentUserId!, _workspaces);
      }
      notifyListeners();
    }
  }

  Future<bool> deleteWorkspace(String workspaceId) async {
    // Cannot delete default personal workspace or if it's the only one
    if (_workspaces.length <= 1) return false;

    final target = _workspaces.firstWhere((w) => w.id == workspaceId, orElse: () => _workspaces.first);
    if (target.isDefault) return false;

    _workspaces.removeWhere((w) => w.id == workspaceId);

    // If active was deleted, fallback to default or first
    if (_activeWorkspace?.id == workspaceId) {
      final fallback = _workspaces.firstWhere((w) => w.isDefault, orElse: () => _workspaces.first);
      await switchWorkspace(fallback.id);
    }

    if (_currentUserId != null) {
      await _storage.saveWorkspaces(_currentUserId!, _workspaces);
    }
    notifyListeners();
    return true;
  }

  Future<void> upgradePlan(SaaSTier tier) async {
    final newPlan = SaaSPlanModel(
      tier: tier,
      subscribedAt: DateTime.now(),
      expiresAt: tier == SaaSTier.starter ? null : DateTime.now().add(const Duration(days: 365)),
      isActive: true,
    );
    _currentPlan = newPlan;
    if (_currentUserId != null) {
      await _storage.saveSaaSPlan(_currentUserId!, newPlan);
    }
    notifyListeners();
  }

  List<WalletModel> _generateDefaultWalletsForType(WorkspaceType type, String workspaceId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (type) {
      case WorkspaceType.business:
        return [
          WalletModel(
            id: 'w_biz_bank_$now',
            name: 'حساب بنكي تجاري',
            type: 'bank',
            balance: 0.0,
            colorValue: const Color(0xFF2563EB).toARGB32(),
            iconCode: Icons.account_balance_rounded.codePoint,
          ),
          WalletModel(
            id: 'w_biz_cash_$now',
            name: 'عهدة نقدية / صندوق',
            type: 'cash',
            balance: 0.0,
            colorValue: const Color(0xFFD97706).toARGB32(),
            iconCode: Icons.payments_rounded.codePoint,
          ),
          WalletModel(
            id: 'w_biz_visa_$now',
            name: 'بطاقة مشتريات الشركة',
            type: 'card',
            balance: 0.0,
            colorValue: const Color(0xFF7C3AED).toARGB32(),
            iconCode: Icons.credit_card_rounded.codePoint,
          ),
        ];
      case WorkspaceType.store:
        return [
          WalletModel(
            id: 'w_store_sales_$now',
            name: 'حساب مبيعات المتجر',
            type: 'bank',
            balance: 0.0,
            colorValue: const Color(0xFFE11D48).toARGB32(),
            iconCode: Icons.storefront_rounded.codePoint,
          ),
          WalletModel(
            id: 'w_store_gateway_$now',
            name: 'بوابة دفع إلكتروني (Pay / Mada)',
            type: 'digital',
            balance: 0.0,
            colorValue: const Color(0xFF0D9488).toARGB32(),
            iconCode: Icons.qr_code_2_rounded.codePoint,
          ),
          WalletModel(
            id: 'w_store_cashier_$now',
            name: 'صندوق الكاشير',
            type: 'cash',
            balance: 0.0,
            colorValue: const Color(0xFF059669).toARGB32(),
            iconCode: Icons.point_of_sale_rounded.codePoint,
          ),
        ];
      case WorkspaceType.freelance:
        return [
          WalletModel(
            id: 'w_free_acc_$now',
            name: 'حساب استقبال المستحقات',
            type: 'bank',
            balance: 0.0,
            colorValue: const Color(0xFF4F46E5).toARGB32(),
            iconCode: Icons.account_balance_wallet_rounded.codePoint,
          ),
          WalletModel(
            id: 'w_free_digital_$now',
            name: 'محفظة رقمية / PayPal',
            type: 'digital',
            balance: 0.0,
            colorValue: const Color(0xFF0284C7).toARGB32(),
            iconCode: Icons.language_rounded.codePoint,
          ),
        ];
      case WorkspaceType.family:
        return [
          WalletModel(
            id: 'w_fam_cash_$now',
            name: 'مصروف البيت والأسرة',
            type: 'cash',
            balance: 0.0,
            colorValue: const Color(0xFFD97706).toARGB32(),
            iconCode: Icons.home_rounded.codePoint,
          ),
          WalletModel(
            id: 'w_fam_card_$now',
            name: 'بطاقة المشتريات والسوبرماركت',
            type: 'card',
            balance: 0.0,
            colorValue: const Color(0xFFDB2777).toARGB32(),
            iconCode: Icons.shopping_cart_rounded.codePoint,
          ),
        ];
      case WorkspaceType.investment:
        return [
          WalletModel(
            id: 'w_inv_portfolio_$now',
            name: 'محفظة تداول وأسهم',
            type: 'savings',
            balance: 0.0,
            colorValue: const Color(0xFF059669).toARGB32(),
            iconCode: Icons.show_chart_rounded.codePoint,
          ),
          WalletModel(
            id: 'w_inv_income_$now',
            name: 'عوائد وأرباح',
            type: 'bank',
            balance: 0.0,
            colorValue: const Color(0xFF2563EB).toARGB32(),
            iconCode: Icons.account_balance_rounded.codePoint,
          ),
        ];
      case WorkspaceType.personal:
        return [
          WalletModel(
            id: 'w_per_cash_$now',
            name: 'نقدي (كاش)',
            type: 'cash',
            balance: 0.0,
            colorValue: const Color(0xFF0D9488).toARGB32(),
            iconCode: Icons.payments_rounded.codePoint,
          ),
          WalletModel(
            id: 'w_per_bank_$now',
            name: 'حساب بنكي جاري',
            type: 'bank',
            balance: 0.0,
            colorValue: const Color(0xFF2563EB).toARGB32(),
            iconCode: Icons.account_balance_rounded.codePoint,
          ),
        ];
    }
  }
}
