import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class EmailOtpDialog extends StatefulWidget {
  final String email;
  final String name;
  final String password;
  final String? profession;
  final VoidCallback onSuccess;
  final VoidCallback onEditEmail;

  const EmailOtpDialog({
    super.key,
    required this.email,
    required this.name,
    required this.password,
    this.profession,
    required this.onSuccess,
    required this.onEditEmail,
  });

  @override
  State<EmailOtpDialog> createState() => _EmailOtpDialogState();
}

class _EmailOtpDialogState extends State<EmailOtpDialog> {
  // 6 digit controllers and focus nodes
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendCountdown = 60;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _devPreviewCode;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _fetchDevPreviewCode();
  }

  void _fetchDevPreviewCode() {
    final auth = context.read<AuthProvider>();
    _devPreviewCode = auth.emailOtpService.getActiveCodeForTesting(widget.email);
  }

  void _startTimer() {
    final auth = context.read<AuthProvider>();
    final remaining = auth.emailOtpService.remainingCooldownSeconds(widget.email);
    _resendCountdown = remaining > 0 ? remaining : 60;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  Future<void> _handleResend() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final result = await auth.sendEmailOtp(
      email: widget.email,
      name: widget.name,
    );

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (result.isSuccess) {
        _devPreviewCode = result.code;
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني بنجاح.'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        _errorMessage = result.errorMessage ?? 'تعذر إرسال الرمز، يرجى المحاولة لاحقاً.';
      }
    });
  }

  void _autoFillDevCode() {
    if (_devPreviewCode != null && _devPreviewCode!.length == 6) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = _devPreviewCode![i];
      }
      for (var f in _focusNodes) {
        f.unfocus();
      }
      setState(() {
        _errorMessage = null;
      });
      _verifyAndRegister();
    }
  }

  Future<void> _verifyAndRegister() async {
    final otp = _currentOtp;
    if (otp.length < 6) {
      setState(() => _errorMessage = 'يرجى إدخال رمز التحقق كاملاً (6 أرقام).');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final verifyResult = auth.verifyEmailOtp(
      email: widget.email,
      otp: otp,
    );

    if (!verifyResult.isValid) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = verifyResult.errorMessage ?? 'رمز التحقق غير صحيح.';
        });
      }
      return;
    }

    // OTP is valid! Proceed to register account marked as verified
    final registered = await auth.registerWithEmail(
      name: widget.name,
      email: widget.email,
      password: widget.password,
      profession: widget.profession,
      isEmailVerified: true,
    );

    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (registered) {
      Navigator.of(context).pop(); // Close dialog
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage = auth.errorMessage ?? 'فشل إتمام إنشاء الحساب، يرجى المحاولة.';
      });
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted multiple characters (e.g. 6 digits)
      final clean = value.replaceAll(RegExp(r'\D'), '');
      if (clean.length == 6) {
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = clean[i];
        }
        _focusNodes[5].requestFocus();
        _verifyAndRegister();
        return;
      }
      _controllers[index].text = value.characters.last;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_currentOtp.length == 6) {
          _verifyAndRegister();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mail Icon with luminous gradient ring
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.primary,
                  size: 38,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Title
            const Text(
              'تأكيد البريد الإلكتروني',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              'أدخل رمز التحقق (OTP) المكون من 6 أرقام المرسل إلى:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),

            const SizedBox(height: 10),

            // Email Chip with Edit button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onEditEmail();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Error banner if any
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // 6 OTP Digit Input Boxes (RTL direction preserved)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 44,
                    height: 54,
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace &&
                            _controllers[index].text.isEmpty &&
                            index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (val) => _onDigitChanged(index, val),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Dev / Quick Testing Helper (allows instant verification on device)
            if (_devPreviewCode != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _autoFillDevCode,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mark_email_unread_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'كود التحقق: $_devPreviewCode',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'تعبئة وتأكيد',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Resend Timer Row
            Center(
              child: _resendCountdown > 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.lightTextMuted),
                        const SizedBox(width: 6),
                        Text(
                          'إعادة إرسال الرمز خلال $_resendCountdown ثانية',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    )
                  : TextButton.icon(
                      onPressed: _isResending ? null : _handleResend,
                      icon: _isResending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'إعادة إرسال رمز جديد',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyAndRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
              ),
              child: _isVerifying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'تأكيد وإنشاء الحساب',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
