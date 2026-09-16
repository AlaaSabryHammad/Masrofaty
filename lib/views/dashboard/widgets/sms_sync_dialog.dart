import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/sms_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_helper.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/theme_provider.dart';

class SmsSyncDialog extends StatefulWidget {
  const SmsSyncDialog({super.key});

  @override
  State<SmsSyncDialog> createState() => _SmsSyncDialogState();
}

class _SmsSyncDialogState extends State<SmsSyncDialog> {
  final SmsSyncService _smsService = SmsSyncService();
  bool _isLoading = true;
  bool _hasPermission = false;
  List<ParsedBankTransaction> _detectedMessages = [];
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _checkAndScan();
  }

  Future<void> _checkAndScan() async {
    setState(() => _isLoading = true);
    final granted = await _smsService.checkPermissions();
    if (!mounted) return;

    setState(() => _hasPermission = granted);

    if (granted) {
      await _scanMessages();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);
    final granted = await _smsService.requestPermissions();
    if (!mounted) return;

    setState(() => _hasPermission = granted);
    if (granted) {
      await _scanMessages();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanMessages() async {
    setState(() => _isLoading = true);
    try {
      // 1. Check any pending background SMS
      final pending = await _smsService.getPendingSms();
      // 2. Scan recent bank inbox
      final recent = await _smsService.scanRecentBankSms(days: 30, limit: 50);

      final combined = <ParsedBankTransaction>[...pending, ...recent];
      // Deduplicate by body and timestamp
      final seen = <String>{};
      final uniqueList = <ParsedBankTransaction>[];
      for (final item in combined) {
        final key = '${item.body}_${item.timestamp.millisecondsSinceEpoch}';
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueList.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _detectedMessages = uniqueList;
          _selectedIndices.clear();
          for (int i = 0; i < uniqueList.length; i++) {
            _selectedIndices.add(i);
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applySelected() async {
    if (_selectedIndices.isEmpty) return;

    final finance = context.read<FinanceProvider>();
    int count = 0;

    for (final idx in _selectedIndices) {
      if (idx < _detectedMessages.length) {
        final tx = _detectedMessages[idx];
        await SmsSyncService.applyTransactionToFinance(tx, finance);
        count++;
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل $count عملية بنكية في حساباتك بنجاح!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final isDark = themeProv.isDarkMode;
    final currency = themeProv.currencySymbol;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sms_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'المزامنة التلقائية للرسائل البنكية',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'قراءة عمليات الخصم والإيداع المصرفية',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0284C7)),
                        SizedBox(height: 16),
                        Text('جارِ فحص الرسائل البنكية الحديثة...'),
                      ],
                    ),
                  )
                : !_hasPermission
                    ? _buildPermissionRequest(isDark)
                    : _detectedMessages.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildTransactionsList(isDark, currency),
          ),

          // Bottom Action Button
          if (_hasPermission && _detectedMessages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: _selectedIndices.isEmpty ? null : _applySelected,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  'تسجيل العمليات المحددة (${_selectedIndices.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequest(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security_rounded,
              color: Color(0xFF0284C7),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'السماح بقراءة الرسائل البنكية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'يتطلب تطبيق "مصروفاتي" إذن قراءة الرسائل الواردة لاكتشاف إشعارات الشراء والسحب والإيداع من بنوكك وتسجيلها في حساباتك ومحافظك تلقائياً.\n\n🔒 خصوصيتك أولويتنا: لا يتم إرسال أي رسائل خارج جهازك نهائياً والبيانات تبقى على هاتفك 100%.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _requestPermission,
            icon: const Icon(Icons.verified_user_rounded),
            label: const Text(
              'منح الإذن وتفعيل المزامنة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mark_email_read_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'لم يتم العثور على رسائل بنكية حديثة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'بمجرد أن تصلك أي رسالة نصية من البنك (خصم، شراء مدى، سحب صراف، إيداع راتب)، سيلتقطها التطبيق تلقائياً في الخلفية.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _scanMessages,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة الفحص الآن'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(bool isDark, String currency) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تم اكتشاف ${_detectedMessages.length} عملية بنكية',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedIndices.length == _detectedMessages.length) {
                      _selectedIndices.clear();
                    } else {
                      _selectedIndices.clear();
                      for (int i = 0; i < _detectedMessages.length; i++) {
                        _selectedIndices.add(i);
                      }
                    }
                  });
                },
                child: Text(
                  _selectedIndices.length == _detectedMessages.length
                      ? 'إلغاء تحديد الكل'
                      : 'تحديد الكل',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _detectedMessages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final tx = _detectedMessages[index];
              final isSelected = _selectedIndices.contains(index);

              Color typeColor = AppColors.expense;
              IconData typeIcon = Icons.arrow_downward_rounded;
              String typeLabel = 'خصم / شراء';

              if (tx.isAtmWithdrawal) {
                typeColor = const Color(0xFF8B5CF6);
                typeIcon = Icons.local_atm_rounded;
                typeLabel = 'سحب صراف (تحويل للكاش)';
              } else if (!tx.isExpense) {
                typeColor = AppColors.income;
                typeIcon = Icons.arrow_upward_rounded;
                typeLabel = 'إيداع بنكي';
              }

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIndices.add(index);
                      } else {
                        _selectedIndices.remove(index);
                      }
                    });
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          tx.merchant,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(tx.amount ?? 0, symbol: currency),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 9,
                                color: typeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (tx.bankName != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              tx.bankName!,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateHelper.formatDate(tx.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
