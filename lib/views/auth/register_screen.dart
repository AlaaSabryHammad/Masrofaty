import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart';
import 'email_otp_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _professionController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().resetLoading();
        context.read<AuthProvider>().clearError();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _professionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الموافقة على شروط الاستخدام للمتابعة')),
      );
      return;
    }

    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final profession = _professionController.text.trim();
    final password = _passwordController.text;

    final auth = context.read<AuthProvider>();

    // 1. Check if email already registered locally
    if (auth.isEmailAlreadyRegistered(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا البريد الإلكتروني مسجل بالفعل. يرجى تسجيل الدخول أو استعادة كلمة المرور.'),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 2. Dispatch OTP to email
      final otpResult = await auth.sendEmailOtp(
        email: email,
        name: name,
      );

      if (!mounted) return;

      if (!otpResult.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(otpResult.errorMessage ?? 'تعذر إرسال رمز التحقق إلى بريدك الإلكتروني.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      // 3. Open OTP Verification Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => EmailOtpDialog(
          email: email,
          name: name,
          password: password,
          profession: profession.isNotEmpty ? profession : null,
          onSuccess: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تأكيد بريدك الإلكتروني وإنشاء الحساب بنجاح! مرحباً بك في مصروفاتي'),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 3),
                ),
              );
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AppGate()),
                (route) => false,
              );
            }
          },
          onEditEmail: () {
            // Returned to edit form
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء إرسال رمز التحقق، يرجى المحاولة مجدداً.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button & Title
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'إنشاء حساب جديد',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      'ابدأ رحلتك المالية الذكية وسيطر على مصاريفك وديونك',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل',
                      hintText: 'مثال: سارة خالد',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسمك الكامل';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Profession / Job Field
                  TextFormField(
                    controller: _professionController,
                    decoration: InputDecoration(
                      labelText: 'المهنة أو التخصص',
                      hintText: 'مثال: مهندس برمجيات، طبيب، محاسب، موظف، رائد أعمال...',
                      prefixIcon: const Icon(Icons.work_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال مهنتك أو تخصصك';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      hintText: 'name@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'يرجى إدخال بريد إلكتروني صحيح';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'يرجى إدخال كلمة المرور';
                      }
                      if (val.length < 6) {
                        return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (val) {
                      if (val != _passwordController.text) {
                        return 'كلمتا المرور غير متطابقتين';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // Terms and Privacy Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeTerms,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _agreeTerms = val ?? true),
                      ),
                      Expanded(
                        child: Text(
                          'أوافق على شروط الاستخدام وسياسة الخصوصية وأمان البيانات',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Register Button
                  Builder(
                    builder: (ctx) {
                      final isButtonLoading = _isSubmitting || auth.isLoading;
                      return ElevatedButton(
                        onPressed: isButtonLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: isButtonLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'إنشاء الحساب الآن',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Social / Fast signup divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'أو التسجيل السريع عبر',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Google Sign Up
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await auth.loginWithGoogle();
                        if (mounted) {
                          if (ok) {
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AppGate()),
                              (route) => false,
                            );
                          } else if (auth.errorMessage != null && !auth.errorMessage!.contains('إلغاء')) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(auth.errorMessage!),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
                      icon: Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 18,
                        height: 18,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata_rounded, size: 24),
                      ),
                      label: const Text(
                        'التسجيل باستخدام حساب جوجل',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'لديك حساب بالفعل؟',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'تسجيل الدخول',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
