class AppConstants {
  static const String appName = 'مصروفاتي';
  static const String appTagline = 'إدارتك المالية الذكية لمصاريفك وديونك';

  // Supported Currencies
  static const List<Map<String, String>> currencies = [
    {'code': 'SAR', 'symbol': 'ر.س', 'name': 'ريال سعودي'},
    {'code': 'EGP', 'symbol': 'ج.م', 'name': 'جنيه مصري'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'درهم إماراتي'},
    {'code': 'KWD', 'symbol': 'د.ك', 'name': 'دينار كويتي'},
    {'code': 'USD', 'symbol': '\$', 'name': 'دولار أمريكي'},
    {'code': 'EUR', 'symbol': '€', 'name': 'يورو'},
    {'code': 'QAR', 'symbol': 'ر.ق', 'name': 'ريال قطري'},
    {'code': 'OMR', 'symbol': 'ر.ع', 'name': 'ريال عماني'},
    {'code': 'JOD', 'symbol': 'د.أ', 'name': 'دينار أردني'},
  ];

  static const String defaultCurrencySymbol = 'ر.س';
  static const String defaultCurrencyCode = 'SAR';

  // Storage Keys
  static const String keyTransactions = 'masrofaty_transactions';
  static const String keyCategories = 'masrofaty_categories';
  static const String keyDebts = 'masrofaty_debts';
  static const String keyWallets = 'masrofaty_wallets';
  static const String keyBudgets = 'masrofaty_budgets';
  static const String keyThemeMode = 'masrofaty_theme_mode';
  static const String keyCurrency = 'masrofaty_currency';
  static const String keyHideBalance = 'masrofaty_hide_balance';
  static const String keyNotifications = 'masrofaty_notifications';
  static const String keyFirstRun = 'masrofaty_first_run_completed';
}
