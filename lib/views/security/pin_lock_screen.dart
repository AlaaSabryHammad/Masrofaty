import 'package:flutter/material.dart';
import '../../core/services/security_service.dart';
import '../../core/theme/app_colors.dart';

class PinLockScreen extends StatefulWidget {
  final SecurityService securityService;
  final bool isSettingPin;
  final VoidCallback onUnlocked;

  const PinLockScreen({
    super.key,
    required this.securityService,
    this.isSettingPin = false,
    required this.onUnlocked,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _enteredPin = '';
  String? _firstPin;
  bool _hasError = false;
  String _message = 'أدخل رمز الأمان المكون من 4 أرقام';

  @override
  void initState() {
    super.initState();
    if (widget.isSettingPin) {
      _message = 'عيّن رمز أمان جديد (4 أرقام)';
    }
  }

  void _onNumberTap(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
        _hasError = false;
      });

      if (_enteredPin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _hasError = false;
      });
    }
  }

  void _handlePinComplete() {
    if (widget.isSettingPin) {
      if (_firstPin == null) {
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = '';
          _message = 'أعد إدخال رمز الأمان لتأكيده';
        });
      } else {
        if (_firstPin == _enteredPin) {
          widget.securityService.setPin(_enteredPin);
          widget.onUnlocked();
        } else {
          setState(() {
            _hasError = true;
            _enteredPin = '';
            _firstPin = null;
            _message = 'الرمزان غير متطابقين! أعد المحاولة';
          });
        }
      }
    } else {
      final isValid = widget.securityService.verifyPin(_enteredPin);
      if (isValid) {
        widget.onUnlocked();
      } else {
        setState(() {
          _hasError = true;
          _enteredPin = '';
          _message = 'رمز الأمان غير صحيح! حاول مرة أخرى';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Shield Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (_hasError ? AppColors.danger : AppColors.primary).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasError ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: _hasError ? AppColors.danger : AppColors.primary,
                size: 48,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              widget.isSettingPin ? 'إعداد رمز الحماية' : 'تطبيق مصروفاتي محمي',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _message,
              style: TextStyle(
                fontSize: 14,
                color: _hasError ? AppColors.danger : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                fontWeight: _hasError ? FontWeight.bold : FontWeight.normal,
              ),
            ),

            const SizedBox(height: 36),

            // 4 Pin Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? (_hasError ? AppColors.danger : AppColors.primary)
                        : (isDark ? Colors.white24 : Colors.black12),
                    border: Border.all(
                      color: isFilled
                          ? (_hasError ? AppColors.danger : AppColors.primary)
                          : (isDark ? Colors.white38 : Colors.black26),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const Spacer(flex: 2),

            // Number Keypad (1 - 9, 0, Backspace)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildKey('1'),
                      _buildKey('2'),
                      _buildKey('3'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildKey('4'),
                      _buildKey('5'),
                      _buildKey('6'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildKey('7'),
                      _buildKey('8'),
                      _buildKey('9'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 72, height: 72),
                      _buildKey('0'),
                      _buildActionKey(
                        icon: Icons.backspace_outlined,
                        onTap: _onBackspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onNumberTap(value),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}
