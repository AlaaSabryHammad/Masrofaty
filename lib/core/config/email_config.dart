import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for sending real OTP emails via Gmail SMTP.
/// You can update [defaultSenderEmail] and [defaultAppPassword] below,
/// or configure them dynamically via [saveCredentials].
class EmailConfig {
  // ===========================================================================
  // 🔑 ضع بيانات Gmail هنا أو يمكنك ضبطها ديناميكياً
  // ===========================================================================
  /// عنوان بريد Gmail المرسل (يمكن ضبطه من شاشة الإعدادات داخل التطبيق)
  static const String defaultSenderEmail = '';

  /// اسم المرسل الذي يظهر في صندوق الوارد
  static const String defaultSenderName = 'تطبيق مصروفاتي';

  /// كلمة مرور التطبيقات المكونة من 16 حرفاً من إعدادات أمان Google
  /// احصل عليها من: https://myaccount.google.com/apppasswords
  static const String defaultAppPassword = '';

  // Keys for SharedPreferences storage
  static const String _keySenderEmail = 'email_smtp_sender';
  static const String _keyAppPassword = 'email_smtp_app_password';
  static const String _keySenderName = 'email_smtp_sender_name';

  static String _senderEmail = defaultSenderEmail;
  static String _appPassword = defaultAppPassword;
  static String _senderName = defaultSenderName;
  static bool _isInitialized = false;

  /// Initialize config from SharedPreferences if saved
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _senderEmail = prefs.getString(_keySenderEmail) ?? defaultSenderEmail;
      _appPassword = prefs.getString(_keyAppPassword) ?? defaultAppPassword;
      _senderName = prefs.getString(_keySenderName) ?? defaultSenderName;
      _isInitialized = true;
    } catch (_) {
      _isInitialized = true;
    }
  }

  /// Get current active sender email
  static String get senderEmail => _senderEmail;

  /// Get current active app password
  static String get appPassword => _appPassword;

  /// Get current active sender name
  static String get senderName => _senderName;

  /// Check if SMTP credentials have been set
  static bool get isConfigured =>
      _senderEmail.trim().isNotEmpty &&
      _senderEmail.contains('@') &&
      _appPassword.trim().isNotEmpty;

  /// Save / update SMTP credentials in memory and persistent storage
  static Future<void> saveCredentials({
    required String email,
    required String appPassword,
    String? senderName,
  }) async {
    _senderEmail = email.trim();
    _appPassword = appPassword.trim().replaceAll(' ', '');
    if (senderName != null && senderName.trim().isNotEmpty) {
      _senderName = senderName.trim();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySenderEmail, _senderEmail);
      await prefs.setString(_keyAppPassword, _appPassword);
      await prefs.setString(_keySenderName, _senderName);
    } catch (_) {}
  }
}
