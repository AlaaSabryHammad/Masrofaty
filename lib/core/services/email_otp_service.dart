import 'dart:math';
import 'package:flutter/foundation.dart';

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

  /// Generate and dispatch OTP email
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

    _activeOtps[cleanEmail] = record;
    _lastSentTimestamps[cleanEmail] = now;

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
فريق مصروفاتي
''';

    debugPrint('====================================================');
    debugPrint('[EmailOtpService] Sending OTP Email:');
    debugPrint('To: $cleanEmail');
    debugPrint('Subject: $subject');
    debugPrint('Code: $code');
    debugPrint('Content Preview:\n$plainBody');
    debugPrint('====================================================');

    // Simulate network latency gracefully
    await Future.delayed(const Duration(milliseconds: 600));

    return OtpSendResult.success(code);
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

  /// Retrieve the active code for development / test inspection
  String? getActiveCodeForTesting(String email) {
    final record = _activeOtps[email.trim().toLowerCase()];
    if (record != null && !record.isExpired) {
      return record.code;
    }
    return null;
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
