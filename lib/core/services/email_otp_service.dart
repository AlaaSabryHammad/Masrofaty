import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/email_config.dart';

class OtpRecord {
  final String email;
  final String code;
  final DateTime createdAt;
  final DateTime expiresAt;
  int attempts;

  OtpRecord({
    required this.email,
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    this.attempts = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class OtpSendResult {
  final bool isSuccess;
  final String? code;
  final String? errorMessage;
  final int cooldownSeconds;

  const OtpSendResult({
    required this.isSuccess,
    this.code,
    this.errorMessage,
    this.cooldownSeconds = 0,
  });

  factory OtpSendResult.success(String code) =>
      OtpSendResult(isSuccess: true, code: code, cooldownSeconds: 60);

  factory OtpSendResult.failure(String message, [int cooldown = 0]) =>
      OtpSendResult(isSuccess: false, errorMessage: message, cooldownSeconds: cooldown);
}

class OtpVerifyResult {
  final bool isValid;
  final String? errorMessage;

  const OtpVerifyResult({required this.isValid, this.errorMessage});

  factory OtpVerifyResult.success() => const OtpVerifyResult(isValid: true);

  factory OtpVerifyResult.failure(String message) =>
      OtpVerifyResult(isValid: false, errorMessage: message);
}

class EmailOtpService {
  static final EmailOtpService _instance = EmailOtpService._internal();
  factory EmailOtpService() => _instance;
  EmailOtpService._internal();

  // In-memory active OTP records keyed by email (lowercase)
  final Map<String, OtpRecord> _activeOtps = {};

  // Last sent timestamp keyed by email for 60s cooldown
  final Map<String, DateTime> _lastSentTimestamps = {};

  static const Duration otpValidityDuration = Duration(minutes: 10);
  static const Duration resendCooldown = Duration(seconds: 60);
  static const int maxAttempts = 5;

  /// Generate a cryptographically secure 6-digit OTP code
  String _generateOtp() {
    final rnd = Random.secure();
    final code = 100000 + rnd.nextInt(900000);
    return code.toString();
  }

  /// Get remaining seconds before user can request another OTP
  int remainingCooldownSeconds(String email) {
    final cleanEmail = email.trim().toLowerCase();
    final lastSent = _lastSentTimestamps[cleanEmail];
    if (lastSent == null) return 0;

    final elapsed = DateTime.now().difference(lastSent);
    final remaining = resendCooldown.inSeconds - elapsed.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Generate and dispatch OTP email via Gmail SMTP
  Future<OtpSendResult> sendOtp({
    required String email,
    required String userName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = userName.trim().isEmpty ? 'عميلنا العزيز' : userName.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return OtpSendResult.failure('يرجى إدخال بريد إلكتروني صحيح.');
    }

    // Check resend cooldown
    final cooldown = remainingCooldownSeconds(cleanEmail);
    if (cooldown > 0) {
      return OtpSendResult.failure(
        'يرجى الانتظار $cooldown ثانية قبل طلب رمز جديد.',
        cooldown,
      );
    }

    // Verify SMTP is configured
    if (!EmailConfig.isConfigured) {
      return OtpSendResult.failure(
        'لم يتم ضبط بيانات بريد الإرسال (Gmail SMTP) بعد.\nيرجى تعيين البريد وكلمة مرور التطبيقات (App Password).',
      );
    }

    // Generate fresh OTP code
    final code = _generateOtp();
    final now = DateTime.now();

    final record = OtpRecord(
      email: cleanEmail,
      code: code,
      createdAt: now,
      expiresAt: now.add(otpValidityDuration),
      attempts: 0,
    );

    // Build email template
    final subject = 'رمز التحقق الخاص بك في تطبيق مصروفاتي: $code';
    final plainBody = '''
مرحباً $cleanName،

شكراً لانضمامك إلى تطبيق "مصروفاتي"!
رمز التحقق السري (OTP) الخاص بك لتأكيد بريدك الإلكتروني هو:

  $code

صلاحية هذا الرمز هي 10 دقائق فقط.
يرجى عدم مشاركة هذا الرمز مع أي شخص حفاظاً على أمان بياناتك.

مع تحيات،
فريق تطبيق مصروفاتي
''';

    final htmlBody = '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; direction: rtl; text-align: right; }
    .card { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #10B981 0%, #059669 100%); padding: 32px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 26px; font-weight: 800; letter-spacing: -0.5px; }
    .content { padding: 32px 28px; text-align: right; }
    .greeting { font-size: 16px; font-weight: bold; margin-bottom: 12px; color: #0f172a; }
    .text { font-size: 14px; line-height: 1.7; color: #475569; margin-bottom: 24px; }
    .otp-box { background: #f1f5f9; border: 2px dashed #10B981; border-radius: 16px; padding: 20px; text-align: center; margin: 24px 0; }
    .otp-code { font-size: 36px; font-weight: 900; letter-spacing: 8px; color: #059669; font-family: 'Courier New', Courier, monospace; }
    .note { font-size: 12px; color: #64748b; text-align: center; margin-top: 10px; }
    .warning { background: #fef2f2; border-right: 4px solid #ef4444; padding: 12px 16px; border-radius: 8px; font-size: 12px; color: #991b1b; margin-top: 24px; line-height: 1.5; }
    .footer { text-align: center; padding: 20px; font-size: 12px; color: #94a3b8; border-top: 1px solid #f1f5f9; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>مصروفاتي</h1>
      <p style="margin: 6px 0 0 0; opacity: 0.9; font-size: 14px;">تأكيد البريد الإلكتروني</p>
    </div>
    <div class="content">
      <div class="greeting">مرحباً $cleanName 👋</div>
      <div class="text">
        سعداء بانضمامك إلينا! يرجى استخدام رمز التحقق السري (OTP) التالي لتأكيد بريدك الإلكتروني وإكمال إنشاء حسابك:
      </div>
      <div class="otp-box">
        <div class="otp-code">$code</div>
        <div class="note">⏳ صلاحية هذا الرمز لمدة 10 دقائق فقط</div>
      </div>
      <div class="warning">
        🔒 <strong>تنبيه أمان:</strong> لا تشارك هذا الرمز مع أي شخص. فريق تطبيق "مصروفاتي" لن يطلب منك هذا الرمز أبداً.
      </div>
    </div>
    <div class="footer">
      تطبيق مصروفاتي - لإدارة المصاريف والمدخرات الذكية
    </div>
  </div>
</body>
</html>
''';

    try {
      final smtpServer = gmail(
        EmailConfig.senderEmail,
        EmailConfig.appPassword,
      );

      final message = Message()
        ..from = Address(EmailConfig.senderEmail, EmailConfig.senderName)
        ..recipients.add(cleanEmail)
        ..subject = subject
        ..text = plainBody
        ..html = htmlBody;

      debugPrint('[EmailOtpService] Dispatching real email via Gmail SMTP to $cleanEmail...');
      await send(message, smtpServer).timeout(const Duration(seconds: 15));

      _activeOtps[cleanEmail] = record;
      _lastSentTimestamps[cleanEmail] = now;

      debugPrint('[EmailOtpService] Successfully dispatched OTP email to $cleanEmail');
      return OtpSendResult.success(code);
    } on MailerException catch (e) {
      debugPrint('[EmailOtpService] MailerException: ${e.message}');
      for (var p in e.problems) {
        debugPrint('[EmailOtpService] Problem: ${p.code}: ${p.msg}');
      }
      return OtpSendResult.failure(
        'تعذر إرسال رسالة التحقق عبر البريد الإلكتروني: يرجى التأكد من صحة إعدادات Gmail SMTP وكلمة مرور التطبيقات (App Password).',
      );
    } catch (e) {
      debugPrint('[EmailOtpService] Error sending email: $e');
      return OtpSendResult.failure(
        'حدث خطأ أثناء الاتصال بخادم البريد. يرجى التحقق من اتصال الإنترنت أو إعدادات البريد والمحاولة مجدداً.',
      );
    }
  }

  /// Verify entered OTP against active record
  OtpVerifyResult verifyOtp({
    required String email,
    required String inputOtp,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = inputOtp.trim();

    final record = _activeOtps[cleanEmail];
    if (record == null) {
      return OtpVerifyResult.failure(
        'لم يتم العثور على رمز تحقق لهذا البريد أو تم إلغاؤه. يرجى طلب رمز جديد.',
      );
    }

    if (record.isExpired) {
      _activeOtps.remove(cleanEmail);
      return OtpVerifyResult.failure(
        'انتهت صلاحية رمز التحقق (10 دقائق). يرجى الضغط على إعادة إرسال الرمز.',
      );
    }

    if (record.attempts >= maxAttempts) {
      _activeOtps.remove(cleanEmail);
      return OtpVerifyResult.failure(
        'تم تجاوز الحد الأقصى للمحاولات الخاطئة. يرجى طلب رمز تحقق جديد.',
      );
    }

    if (record.code != cleanCode) {
      record.attempts += 1;
      final remainingAttempts = maxAttempts - record.attempts;
      if (remainingAttempts <= 0) {
        _activeOtps.remove(cleanEmail);
        return OtpVerifyResult.failure(
          'تم تجاوز المحاولات المسموحة. يرجى طلب رمز جديد.',
        );
      }
      return OtpVerifyResult.failure(
        'رمز التحقق غير صحيح. تبقى لك $remainingAttempts محاولات.',
      );
    }

    // OTP is valid! Invalidate active code so it cannot be re-used
    _activeOtps.remove(cleanEmail);
    return OtpVerifyResult.success();
  }

  /// Reset/clear memory state
  void clear(String email) {
    _activeOtps.remove(email.trim().toLowerCase());
    _lastSentTimestamps.remove(email.trim().toLowerCase());
  }

  void clearAll() {
    _activeOtps.clear();
    _lastSentTimestamps.clear();
  }
}
