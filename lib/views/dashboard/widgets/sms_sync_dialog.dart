import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final TextEditingController _textController = TextEditingController();

  bool _isLoading = true;
  bool _hasPermission = false;
  final bool _isIos = !kIsWeb && (Platform.isIOS || !Platform.isAndroid);
  bool _showShortcutsGuide = false;
  String? _selectedWalletId;

  List<ParsedBankTransaction> _detectedMessages = [];
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initFlow() async {
    setState(() => _isLoading = true);

    if (_isIos) {
      // On iOS: Check clipboard automatically for bank messages
      try {
        final tx = await SmsSyncService.parseFromClipboard();
        if (mounted && tx != null) {
          setState(() {
            _detectedMessages = [tx];
            _selectedIndices.add(0);
            _hasPermission = true;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _hasPermission = true;
          _isLoading = false;
        });
      }
      return;
    }

    // Android: Check native permissions
    final granted = await _smsService.checkPermissions();
    if (!mounted) return;

    setState(() => _hasPermission = granted);

    if (granted) {
      await _scanMessages();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestAndroidPermission() async {
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
      final pending = await _smsService.getPendingSms();
      final recent = await _smsService.scanRecentBankSms(days: 30, limit: 50);

      final combined = <ParsedBankTransaction>[...pending, ...recent];
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

  Future<void> _pasteFromClipboard() async {
    final tx = await SmsSyncService.parseFromClipboard();
    if (!mounted) return;

    if (tx != null) {
      setState(() {
        final exists = _detectedMessages.any((m) => m.body == tx.body);
        if (!exists) {
          _detectedMessages.insert(0, tx);
        }
        _selectedIndices.clear();
        for (int i = 0; i < _detectedMessages.length; i++) {
          _selectedIndices.add(i);
        }
        _textController.text = tx.body;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم استخراج عملية من ${tx.merchant} بمبلغ ${tx.amount}!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على رسالة بنكية صالحة في الحافظة. انسخ رسالة البنك أولاً.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _parseManualText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final list = SmsSyncService.parseMultipleMessages(text);
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر استخراج بيانات بنكية من النص. تأكد من احتواء النص على المبلغ وتفاصيل البنك.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      final seen = _detectedMessages.map((m) => m.body).toSet();
      for (final tx in list) {
        if (!seen.contains(tx.body)) {
          _detectedMessages.insert(0, tx);
          seen.add(tx.body);
        }
      }
      _selectedIndices.clear();
      for (int i = 0; i < _detectedMessages.length; i++) {
        _selectedIndices.add(i);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم استخراج ${list.length} عملية بنكية بنجاح!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _applySelected() async {
    if (_selectedIndices.isEmpty) return;

    final finance = context.read<FinanceProvider>();
    int count = 0;

    for (final idx in _selectedIndices) {
      if (idx < _detectedMessages.length) {
        final tx = _detectedMessages[idx];
        await SmsSyncService.applyTransactionToFinance(
          tx,
          finance,
          targetWalletId: _selectedWalletId,
        );
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
    final financeProv = context.watch<FinanceProvider>();
    final isDark = themeProv.isDarkMode;
    final currency = themeProv.currencySymbol;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
          const SizedBox(height: 14),

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
                        Row(
                          children: [
                            const Text(
                              'القارئ الذكي لرسائل البنوك',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (_isIos) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'iOS 🍏',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _isIos
                              ? 'تحليل ولصق رسائل البنوك وأتمتة الاختصارات'
                              : 'قراءة عمليات الخصم والإيداع المصرفية',
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
          const Divider(height: 20),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0284C7)),
                        SizedBox(height: 16),
                        Text('جارِ فحص الرسائل البنكية...'),
                      ],
                    ),
                  )
                : !_isIos && !_hasPermission
                    ? _buildAndroidPermissionRequest(isDark)
                    : _buildMainContent(isDark, currency, financeProv),
          ),

          // Bottom Action Button
          if (_detectedMessages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _selectedIndices.isEmpty ? null : _applySelected,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  'تسجيل العمليات المحددة (${_selectedIndices.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

  Widget _buildMainContent(bool isDark, String currency, FinanceProvider financeProv) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // iOS Privacy Info & Quick Paste Box
          if (_isIos) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.privacy_tip_rounded, color: Color(0xFF0284C7), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'خصوصية نظام Apple (iOS)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تمنع آبل التطبيقات من الوصول المباشر لرسائل SMS في الخلفية. يمكنك تسجيل رسائلك بنقرة واحدة عبر الحافظة أو عبر أتمتة اختصارات آبل.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Quick Action: 1-Tap Paste from Clipboard
          ElevatedButton.icon(
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste_rounded, size: 20),
            label: const Text(
              '📋 قراءة الرسالة المنسوخة من الحافظة (لصق فوري)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),

          const SizedBox(height: 14),

          // Manual Paste / Batch SMS Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textController,
                  maxLines: 3,
                  minLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'أو الصق نص رسالة البنك هنا (يدعم رسائل متعددة)...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    suffixIcon: _textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _textController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _textController.text.trim().isEmpty ? null : _parseManualText,
                      icon: const Icon(Icons.bolt_rounded, size: 16),
                      label: const Text('تحليل الرسالة', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Target Wallet Selection
          if (financeProv.wallets.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'المحفظة المستهدفة:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedWalletId ??
                          financeProv.wallets
                              .firstWhere(
                                (w) => w.type == 'bank' || w.type == 'card',
                                orElse: () => financeProv.wallets.first,
                              )
                              .id,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                      items: financeProv.wallets.map((w) {
                        return DropdownMenuItem<String>(
                          value: w.id,
                          child: Text(
                            w.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedWalletId = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
          ],

          // Detected Messages Section
          if (_detectedMessages.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'العمليات المكتشفة (${_detectedMessages.length})',
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
            const SizedBox(height: 6),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
                  typeLabel = 'سحب صراف (كاش)';
                } else if (!tx.isExpense) {
                  typeColor = AppColors.income;
                  typeIcon = Icons.arrow_upward_rounded;
                  typeLabel = 'إيداع بنكي';
                }

                return Material(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
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
          ] else ...[
            _buildEmptyState(isDark),
          ],

          const SizedBox(height: 16),

          // Apple Shortcuts Automation Guide (Expandable)
          if (_isIos) ...[
            Material(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _showShortcutsGuide,
                  onExpansionChanged: (val) => setState(() => _showShortcutsGuide = val),
                  leading: const Icon(Icons.flash_on_rounded, color: Colors.orange, size: 22),
                  title: const Text(
                    '⚡ تفعيل الأتمتة التلقائية عبر اختصارات آبل',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'خطوات جعل الآيفون ينسخ رسائل البنك تلقائياً',
                    style: TextStyle(fontSize: 11),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _buildStep(
                            number: '1',
                            title: 'افتح تطبيق "الاختصارات" (Shortcuts) في الآيفون.',
                          ),
                          _buildStep(
                            number: '2',
                            title: 'اضغط على تبويب "أتمتة" (Automation) بالأسفل ثم (+).',
                          ),
                          _buildStep(
                            number: '3',
                            title: 'اختر مشغل "الرسائل" (Message) وضع في خانة الرسالة:',
                            trailing: Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'خصم ، شراء ، إيداع ، مدى ، صراف',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          _buildStep(
                            number: '4',
                            title: 'أضف إجراء "نسخ إلى الحافظة" (Copy to Clipboard) أو فتح تطبيق مصروفاتي.',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'بمجرد وصول الرسالة ستكون في الحافظة وتظهر بمصروفاتي بلمسة واحدة!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
                ?trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mark_email_read_rounded,
            size: 54,
            color: Colors.grey.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'لم يتم العثور على رسائل بنكية بعد',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _isIos
                ? 'انسخ أي رسالة نصية من تطبيق الرسائل ثم اضغط على زر "قراءة الرسالة المنسوخة" بالأعلى.'
                : 'بمجرد أن تصلك رسالة بنكية (خصم، شراء مدى، سحب صراف)، سيلتقطها التطبيق تلقائياً.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidPermissionRequest(bool isDark) {
    return SingleChildScrollView(
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
            onPressed: _requestAndroidPermission,
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
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() => _hasPermission = true);
            },
            icon: const Icon(Icons.paste_rounded, size: 18),
            label: const Text('أو لصق الرسائل يدوياً بدون إذن'),
          ),
        ],
      ),
    );
  }
}
