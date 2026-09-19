class AppConstants {
  static const String appName = 'مصروفاتي';
  static const String appTagline = 'إدارتك المالية الذكية لمصاريفك وديونك';

  // Supported Currencies
  static const List<Map<String, String>> currencies = [
    {'code': 'SAR', 'symbol': 'ر.س', 'name': 'ريال سعودي', 'flag': '🇸🇦', 'country': 'المملكة العربية السعودية'},
    {'code': 'EGP', 'symbol': 'ج.م', 'name': 'جنيه مصري', 'flag': '🇪🇬', 'country': 'جمهورية مصر العربية'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'درهم إماراتي', 'flag': '🇦🇪', 'country': 'الإمارات العربية المتحدة'},
    {'code': 'KWD', 'symbol': 'د.ك', 'name': 'دينار كويتي', 'flag': '🇰🇼', 'country': 'دولة الكويت'},
    {'code': 'QAR', 'symbol': 'ر.ق', 'name': 'ريال قطري', 'flag': '🇶🇦', 'country': 'دولة قطر'},
    {'code': 'BHD', 'symbol': 'د.ب', 'name': 'دينار بحريني', 'flag': '🇧🇭', 'country': 'مملكة البحرين'},
    {'code': 'OMR', 'symbol': 'ر.ع', 'name': 'ريال عماني', 'flag': '🇴🇲', 'country': 'سلطنة عمان'},
    {'code': 'JOD', 'symbol': 'د.أ', 'name': 'دينار أردني', 'flag': '🇯🇴', 'country': 'المملكة الأردنية الهاشمية'},
    {'code': 'IQD', 'symbol': 'د.ع', 'name': 'دينار عراقي', 'flag': '🇮🇶', 'country': 'جمهورية العراق'},
    {'code': 'DZD', 'symbol': 'د.ج', 'name': 'دينار جزائري', 'flag': '🇩🇿', 'country': 'الجمهورية الجزائرية'},
    {'code': 'MAD', 'symbol': 'د.م', 'name': 'درهم مغربي', 'flag': '🇲🇦', 'country': 'المملكة المغربية'},
    {'code': 'LYD', 'symbol': 'د.ل', 'name': 'دينار ليبي', 'flag': '🇱🇾', 'country': 'دولة ليبيا'},
    {'code': 'TND', 'symbol': 'د.ت', 'name': 'دينار تونسي', 'flag': '🇹🇳', 'country': 'الجمهورية التونسية'},
    {'code': 'SDG', 'symbol': 'ج.س', 'name': 'جنيه سوداني', 'flag': '🇸🇩', 'country': 'جمهورية السودان'},
    {'code': 'YER', 'symbol': 'ر.ي', 'name': 'ريال يمني', 'flag': '🇾🇪', 'country': 'الجمهورية اليمنية'},
    {'code': 'LBP', 'symbol': 'ل.ل', 'name': 'ليرة لبنانية', 'flag': '🇱🇧', 'country': 'الجمهورية اللبنانية'},
    {'code': 'SYP', 'symbol': 'ل.س', 'name': 'ليرة سورية', 'flag': '🇸🇾', 'country': 'الجمهورية العربية السورية'},
    {'code': 'USD', 'symbol': r'$', 'name': 'دولار أمريكي', 'flag': '🇺🇸', 'country': 'الولايات المتحدة الأمريكية'},
    {'code': 'EUR', 'symbol': '€', 'name': 'يورو', 'flag': '🇪🇺', 'country': 'الاتحاد الأوروبي'},
    {'code': 'GBP', 'symbol': '£', 'name': 'جنيه إسترليني', 'flag': '🇬🇧', 'country': 'المملكة المتحدة'},
    {'code': 'TRY', 'symbol': '₺', 'name': 'ليرة تركية', 'flag': '🇹🇷', 'country': 'الجمهورية التركية'},
    {'code': 'CAD', 'symbol': r'C$', 'name': 'دولار كندي', 'flag': '🇨🇦', 'country': 'كندا'},
  ];

  static Map<String, String> getCurrencyBySymbol(String symbol) {
    return currencies.firstWhere(
      (c) => c['symbol'] == symbol,
      orElse: () => {'code': 'SAR', 'symbol': symbol, 'name': symbol, 'flag': '💰', 'country': ''},
    );
  }

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
