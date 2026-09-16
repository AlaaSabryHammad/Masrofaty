import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/contact_model.dart';
import '../../models/debt_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';
import '../debts/add_debt_dialog.dart';
import '../debts/debt_detail_sheet.dart';

class ContactStatementScreen extends StatelessWidget {
  final ContactModel contact;

  const ContactStatementScreen({super.key, required this.contact});

  void _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendWhatsApp(BuildContext context, String? phone, String statementText) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة رقم الجوال أولاً لمراسلة الشخص عبر واتساب')),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final encodedText = Uri.encodeComponent(statementText);
    final url = 'https://wa.me/$cleanPhone?text=$encodedText';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        Clipboard.setData(ClipboardData(text: statementText));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب، تم نسخ نص كشف الحساب للحافظة!')),
        );
      }
    }
  }

  void _copyStatement(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ كشف الحساب المالي بالكامل بنجاح 📋'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showEditContactDialog(BuildContext context, ContactModel current) {
    final nameCtrl = TextEditingController(text: current.name);
    final phoneCtrl = TextEditingController(text: current.phone ?? '');
    final notesCtrl = TextEditingController(text: current.notes ?? '');
    String rel = current.relationship;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تعديل بيانات جهة التعامل',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال (اختياري)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: rel,
                decoration: const InputDecoration(
                  labelText: 'طبيعة العلاقة',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'friend', child: Text('صديق')),
                  DropdownMenuItem(value: 'family', child: Text('عائلة / قريب')),
                  DropdownMenuItem(value: 'work', child: Text('زميل عمل')),
                  DropdownMenuItem(value: 'client', child: Text('عميل')),
                  DropdownMenuItem(value: 'merchant', child: Text('متجر / مورد')),
                  DropdownMenuItem(value: 'other', child: Text('أخرى')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => rel = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات / رقم الآيبان',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  await context.read<ContactProvider>().updateContact(
                        current.copyWith(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          relationship: rel,
                          notes: notesCtrl.text.trim(),
                        ),
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewDebtForContact(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddDebtDialog(
        initialIsLent: true,
        prefilledName: contact.name,
        prefilledPhone: contact.phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;

    // Refresh contact data if updated
    final liveContact = context.watch<ContactProvider>().getContactById(contact.id) ?? contact;

    final debts = context.watch<DebtProvider>().debts.where((d) {
      final matchesName = d.personName.trim().toLowerCase() == liveContact.name.trim().toLowerCase();
      final matchesPhone = liveContact.phone != null &&
          liveContact.phone!.isNotEmpty &&
          d.phone != null &&
          d.phone == liveContact.phone;
      return matchesName || matchesPhone;
    }).toList();

    final txs = context.watch<FinanceProvider>().transactions.where((t) {
      final matchesName = t.personName?.trim().toLowerCase() == liveContact.name.trim().toLowerCase();
      final matchesContactId = t.contactId == liveContact.id;
      return matchesName || matchesContactId;
    }).toList();

    // Financial calculations
    double totalLentRemaining = 0.0;
    double totalBorrowedRemaining = 0.0;
    double totalPaymentsMade = 0.0;

    for (final d in debts) {
      if (d.isLent) {
        totalLentRemaining += d.remainingAmount;
      } else {
        totalBorrowedRemaining += d.remainingAmount;
      }
      totalPaymentsMade += d.paidAmount;
    }

    final netDue = totalLentRemaining - totalBorrowedRemaining;

    // Generate formatted statement text for WhatsApp / Copy
    final statementText = _generateStatementText(
      contact: liveContact,
      currency: currency,
      totalLentRemaining: totalLentRemaining,
      totalBorrowedRemaining: totalBorrowedRemaining,
      netDue: netDue,
      debts: debts,
      txs: txs,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(liveContact.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'تعديل البيانات',
            onPressed: () => _showEditContactDialog(context, liveContact),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'مشاركة كشف الحساب',
            onPressed: () => _copyStatement(context, statementText),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        children: [
          // Hero Profile Card of Contact
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        liveContact.name.isNotEmpty ? liveContact.name.characters.first : '؟',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            liveContact.name,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  liveContact.relationshipLabel,
                                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (liveContact.phone != null && liveContact.phone!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  liveContact.phone!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (liveContact.notes != null && liveContact.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'ملاحظات: ${liveContact.notes}',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Action Buttons (Call, WhatsApp, Copy, Add Record)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(
                      icon: Icons.phone_rounded,
                      color: AppColors.primary,
                      label: 'اتصال',
                      onTap: () => _callPhone(liveContact.phone),
                    ),
                    _buildActionButton(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      label: 'واتساب',
                      onTap: () => _sendWhatsApp(context, liveContact.phone, statementText),
                    ),
                    _buildActionButton(
                      icon: Icons.copy_rounded,
                      color: const Color(0xFF3B82F6),
                      label: 'نسخ الكشف',
                      onTap: () => _copyStatement(context, statementText),
                    ),
                    _buildActionButton(
                      icon: Icons.add_circle_outline_rounded,
                      color: const Color(0xFFF59E0B),
                      label: 'إضافة سلفة/دين',
                      onTap: () => _addNewDebtForContact(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Net Financial Position Card (الموقف المالي الصافي)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: netDue > 0
                    ? [const Color(0xFF065F46), const Color(0xFF047857)] // I am owed money
                    : (netDue < 0
                        ? [const Color(0xFF991B1B), const Color(0xFFB91C1C)] // I owe money
                        : [const Color(0xFF1E293B), const Color(0xFF334155)]), // Settled
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: (netDue > 0 ? AppColors.primary : (netDue < 0 ? AppColors.danger : Colors.grey)).withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      netDue > 0
                          ? 'صافي المستحقات (أطلبه)'
                          : (netDue < 0 ? 'صافي الالتزام (يطلبني)' : 'الحساب خالص بالكامل'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        netDue > 0 ? 'سلفة لي' : (netDue < 0 ? 'دين علي' : 'مسوى 0.00'),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(netDue.abs(), symbol: currency),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSubBalanceItem('سلف قائمة له', totalLentRemaining, currency),
                    _buildSubBalanceItem('ديون مستحقة له', totalBorrowedRemaining, currency),
                    _buildSubBalanceItem('إجمالي المسدد', totalPaymentsMade, currency),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section Header: Statement Ledger Timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'كشف الحساب وسجل العمليات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${debts.length + txs.length} حركة',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (debts.isEmpty && txs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_outlined, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  const Text('لا توجد أي معاملات أو ديون مسجلة مع هذا الشخص حتى الآن'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () => _addNewDebtForContact(context),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('تسجيل أول معاملة معه', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          else ...[
            // Debts and Loans Section
            if (debts.isNotEmpty) ...[
              for (final debt in debts)
                _buildDebtStatementCard(context, debt, currency, isDark),
            ],

            // Direct Transactions linked to Contact
            if (txs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'المعاملات المالية المباشرة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              for (final tx in txs)
                _buildTransactionCard(context, tx, currency, isDark),
            ],
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSubBalanceItem(String title, double amount, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.format(amount, symbol: currency),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDebtStatementCard(BuildContext context, DebtModel debt, String currency, bool isDark) {
    final progress = debt.progress;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DebtDetailSheet(debtId: debt.id),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (debt.isSettled
                ? AppColors.primary
                : (debt.isOverdue ? AppColors.danger : AppColors.warning)).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (debt.isLent ? AppColors.debtLent : AppColors.debtBorrowed).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    debt.isLent ? Icons.call_made_rounded : Icons.call_received_rounded,
                    color: debt.isLent ? AppColors.debtLent : AppColors.debtBorrowed,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.notes != null && debt.notes!.isNotEmpty ? debt.notes! : (debt.isLent ? 'سلفة' : 'دين'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        DateHelper.formatDate(debt.createdDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(debt.totalAmount, symbol: currency),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      debt.isSettled
                          ? 'مسدد بالكامل'
                          : 'المتبقي: ${CurrencyFormatter.format(debt.remainingAmount, symbol: currency)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: debt.isSettled ? AppColors.primary : AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (debt.payments.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'سجل الدفعات المسددة (${debt.payments.length} دفعات):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              for (final p in debt.payments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '• ${DateHelper.formatDate(p.date)}${p.notes != null ? " (${p.notes})" : ""}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        CurrencyFormatter.format(p.amount, symbol: currency),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  debt.isSettled ? AppColors.primary : (debt.isLent ? AppColors.debtLent : AppColors.debtBorrowed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionModel tx, String currency, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (tx.isExpense ? AppColors.expense : AppColors.income).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tx.isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: tx.isExpense ? AppColors.expense : AppColors.income,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(DateHelper.formatDate(tx.date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            '${tx.isExpense ? "-" : "+"}${CurrencyFormatter.format(tx.amount, symbol: currency)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: tx.isExpense ? AppColors.expense : AppColors.income,
            ),
          ),
        ],
      ),
    );
  }

  String _generateStatementText({
    required ContactModel contact,
    required String currency,
    required double totalLentRemaining,
    required double totalBorrowedRemaining,
    required double netDue,
    required List<DebtModel> debts,
    required List<TransactionModel> txs,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════');
    buffer.writeln('📊 كشف حساب مالي تفصيلي');
    buffer.writeln('تطبيق مصروفاتي - Masrofaty');
    buffer.writeln('═══════════════════════════');
    buffer.writeln('👤 جهة التعامل: ${contact.name}');
    if (contact.phone != null && contact.phone!.isNotEmpty) {
      buffer.writeln('📞 رقم الجوال: ${contact.phone}');
    }
    buffer.writeln('🏷️ التصنيف: ${contact.relationshipLabel}');
    buffer.writeln('📅 تاريخ التقرير: ${DateHelper.formatDate(DateTime.now())}');
    buffer.writeln('');
    buffer.writeln('💵 الموقف المالي الصافي:');
    if (netDue > 0) {
      buffer.writeln('• الرصيد المستحق: أطلبه ${CurrencyFormatter.format(netDue, symbol: currency)}');
    } else if (netDue < 0) {
      buffer.writeln('• الرصيد المستحق: يطلبني ${CurrencyFormatter.format(netDue.abs(), symbol: currency)}');
    } else {
      buffer.writeln('• الرصيد المستحق: خالص بالكامل 0.00 $currency');
    }
    buffer.writeln('• إجمالي السلف القائمة: ${CurrencyFormatter.format(totalLentRemaining, symbol: currency)}');
    buffer.writeln('• إجمالي الديون المستحقة: ${CurrencyFormatter.format(totalBorrowedRemaining, symbol: currency)}');
    buffer.writeln('');
    buffer.writeln('📋 سجل العمليات والتفاصيل:');

    if (debts.isEmpty && txs.isEmpty) {
      buffer.writeln('(لا توجد عمليات مسجلة)');
    } else {
      int index = 1;
      for (final d in debts) {
        buffer.writeln('$index) [${d.isLent ? "سلفة له" : "دين عليه"}] ${d.notes ?? "بدون ملاحظات"}');
        buffer.writeln('   - المبلغ: ${CurrencyFormatter.format(d.totalAmount, symbol: currency)} | المتبقي: ${CurrencyFormatter.format(d.remainingAmount, symbol: currency)}');
        buffer.writeln('   - التاريخ: ${DateHelper.formatDate(d.createdDate)} | الحالة: ${d.isSettled ? "مسدد" : "نشط"}');
        if (d.payments.isNotEmpty) {
          buffer.writeln('   - الدفعات المسددة:');
          for (final p in d.payments) {
            buffer.writeln('     ↳ ${CurrencyFormatter.format(p.amount, symbol: currency)} بتاريخ ${DateHelper.formatDate(p.date)} (${p.notes ?? "دفعة"})');
          }
        }
        index++;
      }
      for (final t in txs) {
        buffer.writeln('$index) [${t.isExpense ? "مصروف" : "دخل"}] ${t.title} - ${CurrencyFormatter.format(t.amount, symbol: currency)} بتاريخ ${DateHelper.formatDate(t.date)}');
        index++;
      }
    }

    buffer.writeln('');
    buffer.writeln('═══════════════════════════');
    buffer.writeln('تم إنشاء كشف الحساب آلياً عبر تطبيق مصروفاتي');
    return buffer.toString();
  }
}
