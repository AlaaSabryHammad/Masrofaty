import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class PhoneAuthDialog extends StatefulWidget {
  final VoidCallback? onSuccess;

  const PhoneAuthDialog({super.key, this.onSuccess});

  @override
  State<PhoneAuthDialog> createState() => _PhoneAuthDialogState();
}

class _PhoneAuthDialogState extends State<PhoneAuthDialog> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();

  String _countryCode = '+966';
  String? _verificationId;
  bool _codeSent = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      setState(() => _error = 'يرجى إدخال رقم جوال صحيح');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final fullNumber = '$_countryCode$phone';
    final auth = context.read<AuthProvider>();

    await auth.sendPhoneOtp(
      phone: fullNumber,
      onCodeSent: (vId) {
        if (mounted) {
          setState(() {
            _verificationId = vId;
            _codeSent = true;
            _isLoading = false;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _error = err;
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'أدخل رمز التحقق كاملاً');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyPhoneOtp(
      verificationId: _verificationId ?? 'demo_verif',
      smsCode: code,
      phone: '$_countryCode${_phoneController.text.trim()}',
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();
      } else {
        setState(() => _error = auth.errorMessage ?? 'رمز التحقق غير صحيح');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_android_rounded, color: Color(0xFF0284C7)),
          ),
          const SizedBox(width: 10),
          Text(
            !_codeSent ? 'الدخول برقم الجوال' : 'تأكيد رمز التحقق (OTP)',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_codeSent) ...[
              Text(
                'أدخل رقم هاتفك لتصلك رسالة نصية SMS برمز التحقق للدخول المباشر.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم (اختياري)',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _countryCode,
                        items: const [
                          DropdownMenuItem(value: '+966', child: Text('🇸🇦 +966')),
                          DropdownMenuItem(value: '+20', child: Text('🇪🇬 +20')),
                          DropdownMenuItem(value: '+971', child: Text('🇦🇪 +971')),
                          DropdownMenuItem(value: '+965', child: Text('🇰🇼 +965')),
                          DropdownMenuItem(value: '+968', child: Text('🇴🇲 +968')),
                          DropdownMenuItem(value: '+974', child: Text('🇶🇦 +974')),
                          DropdownMenuItem(value: '+973', child: Text('🇧🇭 +973')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _countryCode = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم الجوال',
                        hintText: '501234567',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'تم إرسال رمز التحقق المكون من 6 أرقام إلى رقمك: $_countryCode${_phoneController.text}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'رمز التحقق',
                  hintText: '123456',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : _sendCode,
                child: const Text('إعادة إرسال الرمز'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : (!_codeSent ? _sendCode : _verifyOtp),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(!_codeSent ? 'إرسال الرمز' : 'تأكيد ودخول'),
        ),
      ],
    );
  }
}
