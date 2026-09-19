import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/email_config.dart';
import '../../core/services/email_otp_service.dart';
import '../../core/theme/app_colors.dart';

class EmailSmtpSettingsDialog extends StatefulWidget {
  const EmailSmtpSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const EmailSmtpSettingsDialog(),
    );
  }

  @override
  State<EmailSmtpSettingsDialog> createState() => _EmailSmtpSettingsDialogState();
}

class _EmailSmtpSettingsDialogState extends State<EmailSmtpSettingsDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  late final TextEditingController _appPasswordController;
  final TextEditingController _testEmailController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _statusMessage;
  bool _isStatusError = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: EmailConfig.senderEmail);
    _nameController = TextEditingController(text: EmailConfig.senderName);
    _appPasswordController = TextEditingController(text: EmailConfig.appPassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _appPasswordController.dispose();
    _testEmailController.dispose();
    super.dispose();
  }

  Future<void> _openGoogleAppPasswordsUrl() async {
    final uri = Uri.parse('https://myaccount.google.com/apppasswords');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _saveCredentials() async {
    final email = _emailController.text.trim();
    final password = _appPasswordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _isStatusError = true;
        _statusMessage = 'يرجى إدخال بريد Gmail صحيح.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _isStatusError = true;
        _statusMessage = 'يرجى إدخال كلمة مرور التطبيقات (App Password).';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    await EmailConfig.saveCredentials(
      email: email,
      appPassword: password,
      senderName: name.isEmpty ? null : name,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _isStatusError = false;
      _statusMessage = 'تم حفظ إعدادات بريد الإرسال بنجاح ✅';
    });
  }

  Future<void> _sendTestEmail() async {
    final targetEmail = _testEmailController.text.trim();
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      setState(() {
        _isStatusError = true;
        _statusMessage = 'يرجى إدخال بريد تجريبي صحيح لاستقبال الرسالة.';
      });
      return;
    }

    // First save current inputs
    await _saveCredentials();

    if (!EmailConfig.isConfigured) {
      setState(() {
        _isStatusError = true;
        _statusMessage = 'يرجى ملء كافة البيانات أولاً قبل الإرسال التجريبي.';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = 'جارٍ الاتصال بخادم Gmail SMTP وإرسال الرسالة...';
      _isStatusError = false;
    });

    final otpService = EmailOtpService();
    final result = await otpService.sendOtp(
      email: targetEmail,
      userName: 'مستخدم تجريبي',
    );

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      if (result.isSuccess) {
        _isStatusError = false;
        _statusMessage = 'تم إرسال رسالة التحقق بنجاح إلى $targetEmail 🎉\nيرجى التحقق من صندوق الوارد لديك.';
      } else {
        _isStatusError = true;
        _statusMessage = result.errorMessage ?? 'فشل الإرسال. تأكد من كلمة مرور التطبيقات.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعدادات بريد الإرسال (SMTP)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'إرسال رموز التحقق الحقيقية عبر Gmail',
                        style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Google Guide Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'كيفية توليد كلمة مرور التطبيقات (App Password):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '1. تأكد من تفعيل التحقق بخطوتين في حساب Google الخاص بك.\n'
                    '2. افتح قسم كلمات مرور التطبيقات (App passwords).\n'
                    '3. أنشئ كلمة مرور جديدة للتطبيق وانسخ الـ 16 حرفاً وضعها في الخانة بالأسفل.',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _openGoogleAppPasswordsUrl,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'فتح صفحة App Passwords في Google',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Sender Email Field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'بريد Gmail المرسل',
                hintText: 'yourname@gmail.com',
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 12),

            // Sender Name Field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'اسم المرسل (الذي يظهر للمستخدم)',
                hintText: 'تطبيق مصروفاتي',
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 12),

            // App Password Field
            TextField(
              controller: _appPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'كلمة مرور التطبيقات (16 حرفاً)',
                hintText: 'abcd efgh ijkl mnop',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 16),

            // Status feedback banner
            if (_statusMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isStatusError
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isStatusError
                        ? AppColors.danger.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isStatusError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                      color: _isStatusError ? AppColors.danger : AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isStatusError ? AppColors.danger : AppColors.primary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveCredentials,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('حفظ إعدادات البريد', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Test Email section
            const Text(
              'تجربة الإرسال السريع:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _testEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'اكتب بريدك لاستلام تجربة...',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isTesting ? null : _sendTestEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isTesting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('إرسال الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
