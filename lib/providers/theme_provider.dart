import 'package:flutter/material.dart';
import '../core/services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storage;

  late ThemeMode _themeMode;
  late String _currencySymbol;
  late bool _hideBalance;

  ThemeProvider(this._storage) {
    _loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  String get currencySymbol => _currencySymbol;
  bool get hideBalance => _hideBalance;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  void _loadSettings() {
    final modeStr = _storage.getThemeMode();
    if (modeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (modeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    _currencySymbol = _storage.getCurrencySymbol();
    _hideBalance = _storage.getHideBalance();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    if (mode == ThemeMode.light) modeStr = 'light';
    await _storage.saveThemeMode(modeStr);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (isDarkMode) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> setCurrency(String symbol) async {
    _currencySymbol = symbol;
    await _storage.saveCurrencySymbol(symbol);
    notifyListeners();
  }

  Future<void> toggleHideBalance() async {
    _hideBalance = !_hideBalance;
    await _storage.saveHideBalance(_hideBalance);
    notifyListeners();
  }

  void refreshCurrency() {
    _currencySymbol = _storage.getCurrencySymbol();
    notifyListeners();
  }
}
