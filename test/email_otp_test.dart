import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masrofaty/core/config/email_config.dart';
import 'package:masrofaty/core/services/email_otp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EmailConfig.init();
    EmailOtpService().clearAll();
  });

  group('EmailConfig Tests', () {
    test('Config retains defaults and detects configured status', () async {
      expect(EmailConfig.senderEmail, isNotEmpty);
      expect(EmailConfig.isConfigured, isTrue);

      await EmailConfig.saveCredentials(
        email: 'test.app@gmail.com',
        appPassword: 'abcd efgh ijkl mnop',
        senderName: 'مصروفاتي',
      );

      expect(EmailConfig.senderEmail, equals('test.app@gmail.com'));
      expect(EmailConfig.appPassword, equals('abcdefghijklmnop')); // Spaces stripped
      expect(EmailConfig.senderName, equals('مصروفاتي'));
      expect(EmailConfig.isConfigured, isTrue);
    });
  });

  group('EmailOtpService Tests', () {
    test('Validation fails for invalid email format', () async {
      final service = EmailOtpService();
      final result = await service.sendOtp(email: 'invalid-email', userName: 'Test');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('صحيح'));
    });

    test('Validation warns if Gmail SMTP is not configured', () async {
      final service = EmailOtpService();
      // Ensure credentials not configured
      await EmailConfig.saveCredentials(email: '', appPassword: '');
      final result = await service.sendOtp(email: 'user@example.com', userName: 'Test');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Gmail SMTP'));
    });

    test('OTP Verification rejects non-existent or wrong codes', () {
      final service = EmailOtpService();
      final result = service.verifyOtp(email: 'test@example.com', inputOtp: '123456');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('لم يتم العثور على رمز'));
    });
  });
}
