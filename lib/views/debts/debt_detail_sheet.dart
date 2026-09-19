import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/debt_communication_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/debt_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';

class DebtDetailSheet extends StatefulWidget {
  final String debtId;

  const DebtDetailSheet({super.key, required this.debtId});

  @override
  State<DebtDetailSheet> createState() => _DebtDetailSheetState();
}

class _DebtDetailSheetState extends State<DebtDetailSheet> {
  final _paymentAmountController = TextEditingController();
  final _paymentNotesController = TextEditingController();

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  void _showAddPaymentDialog(BuildContext context, DebtModel debt, String currency) {
    _paymentAmountController.text = debt.remainingAmount.toStringAsFixed(2);
    _paymentNotesController.clear();
    String? selectedWalletId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final finance = context.watch<FinanceProvider>();
          final wallets = finance.wallets;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(debt.isLent ? 'تسجيل استلام دفعة سداد' : 'تسجيل سداد دفعة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المبلغ المتبقي: ${CurrencyFormatter.format(debt.remainingAmount, symbol: currency)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _paymentAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'مبلغ الدفعة',
                      suffixText: currency,
                      prefixIcon: const Icon(Icons.payments_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Wallet linking dropdown
                  DropdownButtonFormField<String?>(
                    initialValue: selectedWalletId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: debt.isLent ? 'إيداع الدفعة في محفظة:' : 'خصم الدفعة من محفظة:',
                      prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('بدون ربط بالمحافظ'),
                      ),
                      ...wallets.map(
                        (w) => DropdownMenuItem<String?>(
                          value: w.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(w.icon, size: 18, color: w.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${w.name} (${w.balance.toStringAsFixed(0)} $currency)',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setDlgState(() => selectedWalletId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _paymentNotesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                      hintText: 'دفعة نقدية / تحويل بنكي...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(_paymentAmountController.text.trim()) ?? 0.0;
                  if (amt > 0) {
                    final wallet = selectedWalletId != null ? finance.getWalletById(selectedWalletId!) : null;

                    context.read<DebtProvider>().addPayment(
                          debtId: debt.id,
                          amount: amt,
                          notes: _paymentNotesController.text.trim().isEmpty
                              ? null
                              : _paymentNotesController.text.trim(),
                          walletId: wallet?.id,
                          walletName: wallet?.name,
                        );

                    if (wallet != null) {
                      if (debt.isLent) {
                        finance.adjustWalletBalance(wallet.id, amt);
                      } else {
                        finance.adjustWalletBalance(wallet.id, -amt);
                      }
                    }

                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          wallet != null
                              ? (debt.isLent
                                  ? 'تم استلام الدفعة وإيداع ${CurrencyFormatter.format(amt)} في ${wallet.name}'
                                  : 'تم سداد الدفعة وخصم ${CurrencyFormatter.format(amt)} من ${wallet.name}')
                              : 'تم تسجيل الدفعة بنجاح',
                        ),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
                child: const Text('تأكيد الدفعة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStatementDialog(BuildContext context, DebtModel debt, String currency) {
    final statement = DebtCommunicationService.generateStatement(debt, currency);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.description_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('سند وكشف حساب الدين'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                statement,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('نسخ كشف الحساب'),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await DebtCommunicationService.copyStatementToClipboard(debt, currency);
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('تم نسخ سند كشف الحساب إلى الحافظة بنجاح')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الدين؟'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا السجل نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              context.read<DebtProvider>().deleteDebt(widget.debtId);
              Navigator.of(ctx).pop(); // dialog
              Navigator.of(context).pop(); // sheet
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final debts = context.watch<DebtProvider>().debts;
    final debtIndex = debts.indexWhere((d) => d.id == widget.debtId);

    if (debtIndex == -1) {
      return const SizedBox();
    }

    final debt = debts[debtIndex];
    final color = debt.isLent ? AppColors.debtLent : AppColors.debtBorrowed;

    return Material(
      color: isDark ? AppColors.darkCard : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        debt.isLent ? Icons.call_made_rounded : Icons.call_received_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          debt.isLent ? 'سلفة (أموال لك)' : 'دين (أموال عليك)',
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Main Balance Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: isDark ? 0.25 : 0.12),
                        color.withValues(alpha: isDark ? 0.1 : 0.04),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المتبقي للسداد',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.format(debt.remainingAmount, symbol: currency),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: debt.isSettled ? AppColors.success : color,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: debt.isSettled
                                  ? AppColors.success
                                  : (debt.isOverdue ? AppColors.danger : color),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              debt.isSettled
                                  ? 'مسدد بالكامل'
                                  : (debt.isOverdue ? 'متأخر' : 'نشط'),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: debt.progress,
                          minHeight: 10,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(debt.isSettled ? AppColors.success : color),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المبلغ الإجمالي: ${CurrencyFormatter.format(debt.totalAmount, symbol: currency)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'المسدد: ${(debt.progress * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Communication Actions (WhatsApp, Call, Statement)
                Row(
                  children: [
                    // WhatsApp Reminder Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => DebtCommunicationService.sendWhatsAppReminder(debt, currency),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('تذكير واتساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Statement Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showStatementDialog(context, debt, currency),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.receipt_rounded, size: 18),
                        label: const Text('سند الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    if (debt.phone != null && debt.phone!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      // Call button
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppColors.info),
                        onPressed: () => DebtCommunicationService.makePhoneCall(debt.phone!),
                        icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                        tooltip: 'اتصال هاتف',
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Installment Calculator Box (جدولة الأقساط المقترحة)
                if (!debt.isSettled && debt.remainingAmount > 100)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calculate_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('جدولة الأقساط المقترحة للسداد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPlanItem('على شهرين', debt.remainingAmount / 2, currency),
                            _buildPlanItem('على 3 أشهر', debt.remainingAmount / 3, currency),
                            _buildPlanItem('على 6 أشهر', debt.remainingAmount / 6, currency),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Info Rows (Phone, Due Date, Notes)
                if (debt.phone != null && debt.phone!.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.phone_rounded, color: AppColors.info, size: 20),
                    ),
                    title: const Text('رقم الهاتف', style: TextStyle(fontSize: 12)),
                    subtitle: Text(debt.phone!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),

                if (debt.dueDate != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (debt.isOverdue ? AppColors.danger : AppColors.warning).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.event_rounded,
                        color: debt.isOverdue ? AppColors.danger : AppColors.warning,
                        size: 20,
                      ),
                    ),
                    title: const Text('تاريخ الاستحقاق', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      '${DateHelper.formatDate(debt.dueDate!)} (${DateHelper.getRelativeDueStatus(debt.dueDate)})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: debt.isOverdue ? AppColors.danger : null,
                      ),
                    ),
                  ),

                if (debt.notes != null && debt.notes!.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notes_rounded, size: 20),
                    ),
                    title: const Text('ملاحظات', style: TextStyle(fontSize: 12)),
                    subtitle: Text(debt.notes!),
                  ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Installments / Payments History
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'سجل الدفعات (${debt.payments.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (!debt.isSettled)
                      TextButton.icon(
                        onPressed: () => _showAddPaymentDialog(context, debt, currency),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('إضافة دفعة'),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                if (debt.payments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('لم يتم تسجيل أي دفعات بعد'),
                    ),
                  )
                else
                  ...debt.payments.reversed.map((p) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(p.amount, symbol: currency),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (p.notes != null)
                                    Text(
                                      p.notes!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            DateHelper.formatShort(p.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Bottom Settle Full Button
          if (!debt.isSettled)
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  context.read<DebtProvider>().settleDebtFully(debt.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت تسوية وإغلاق الدين بالكامل 🎉')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('تسوية وإغلاق الدين بالكامل', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildPlanItem(String title, double amountPerMonth, String currency) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          '${amountPerMonth.toStringAsFixed(0)} $currency',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ],
    );
  }
}
