import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/recurring_transaction_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/theme_provider.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  void _showAddEditDialog({RecurringTransactionModel? itemToEdit}) {
    final finance = context.read<FinanceProvider>();
    final titleController = TextEditingController(text: itemToEdit?.title ?? '');
    final amountController = TextEditingController(
      text: itemToEdit != null ? itemToEdit.amount.toString() : '',
    );
    final notesController = TextEditingController(text: itemToEdit?.notes ?? '');

    bool isExpense = itemToEdit?.isExpense ?? true;
    String selectedFrequency = itemToEdit?.frequency ?? 'monthly';
    String selectedCategory = itemToEdit?.categoryId ??
        (finance.categories.where((c) => c.isExpense == isExpense).isNotEmpty
            ? finance.categories.where((c) => c.isExpense == isExpense).first.id
            : 'cat_bills');
    String selectedWallet = itemToEdit?.walletId ??
        (finance.wallets.isNotEmpty ? finance.wallets.first.id : 'wallet_cash');
    DateTime selectedDate = itemToEdit?.nextDueDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final currency = context.watch<ThemeProvider>().currencySymbol;
          final availableCats = finance.categories.where((c) => c.isExpense == isExpense).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        itemToEdit != null ? 'تعديل المعاملة الدورية' : 'إضافة اشتراك / معاملة دورية',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Expense / Income Switcher
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('مصروف دوري'), icon: Icon(Icons.arrow_upward_rounded)),
                          ButtonSegment(value: false, label: Text('إيراد متكرر'), icon: Icon(Icons.arrow_downward_rounded)),
                        ],
                        selected: {isExpense},
                        onSelectionChanged: (set) {
                          setDlgState(() {
                            isExpense = set.first;
                            final cats = finance.categories.where((c) => c.isExpense == isExpense).toList();
                            if (cats.isNotEmpty) {
                              selectedCategory = cats.first.id;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 18),

                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم / الوصف',
                          hintText: 'مثال: اشتراك نتفليكس، إيجار الشقة، الراتب الشهري...',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'المبلغ',
                          suffixText: currency,
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Frequency Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: 'دورية التكرار',
                          prefixIcon: Icon(Icons.repeat_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('يومياً')),
                          DropdownMenuItem(value: 'weekly', child: Text('أسبوعياً')),
                          DropdownMenuItem(value: 'monthly', child: Text('شهرياً')),
                          DropdownMenuItem(value: 'yearly', child: Text('سنوياً')),
                        ],
                        onChanged: (val) => setDlgState(() => selectedFrequency = val ?? 'monthly'),
                      ),
                      const SizedBox(height: 14),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'التصنيف',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: availableCats
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Row(
                                    children: [
                                      Icon(c.icon, size: 18, color: c.color),
                                      const SizedBox(width: 8),
                                      Text(c.name),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) => setDlgState(() => selectedCategory = val ?? selectedCategory),
                      ),
                      const SizedBox(height: 14),

                      // Wallet Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedWallet,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: isExpense ? 'الخصم من محفظة:' : 'الإيداع في محفظة:',
                          prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                        ),
                        items: finance.wallets
                            .map((w) => DropdownMenuItem(
                                  value: w.id,
                                  child: Row(
                                    children: [
                                      Icon(w.icon, size: 18, color: w.color),
                                      const SizedBox(width: 8),
                                      Text('${w.name} (${w.balance.toStringAsFixed(0)} $currency)'),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) => setDlgState(() => selectedWallet = val ?? selectedWallet),
                      ),
                      const SizedBox(height: 14),

                      // Next Due Date Picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDlgState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.event_repeat_rounded, color: AppColors.primary),
                                  SizedBox(width: 10),
                                  Text('تاريخ الاستحقاق القادم:'),
                                ],
                              ),
                              Text(
                                DateHelper.formatFriendly(selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات إضافية (اختياري)',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: () {
                          final title = titleController.text.trim();
                          final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                          if (title.isEmpty || amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('يرجى التأكد من كتابة الاسم والمبلغ بشكل صحيح')),
                            );
                            return;
                          }

                          final recProv = context.read<RecurringProvider>();
                          if (itemToEdit != null) {
                            recProv.updateRecurring(itemToEdit.copyWith(
                              title: title,
                              amount: amt,
                              type: isExpense ? 'expense' : 'income',
                              frequency: selectedFrequency,
                              categoryId: selectedCategory,
                              walletId: selectedWallet,
                              nextDueDate: selectedDate,
                              notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            ));
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تحديث المعاملة الدورية بنجاح 🔄')),
                            );
                          } else {
                            recProv.addRecurring(
                              title: title,
                              amount: amt,
                              type: isExpense ? 'expense' : 'income',
                              categoryId: selectedCategory,
                              walletId: selectedWallet,
                              frequency: selectedFrequency,
                              startDate: selectedDate,
                              notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            );
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم جدولة المعاملة الدورية بنجاح 🔄')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          itemToEdit != null ? 'حفظ التعديلات' : 'جدولة المعاملة',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, RecurringTransactionModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء المعاملة الدورية؟'),
        content: Text('هل أنت متأكد من رغبتك في إيقاف وحذف "${item.title}"؟ لن يتم تطبيقها تلقائياً بعد الآن.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              context.read<RecurringProvider>().deleteRecurring(item.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم حذف "${item.title}" بنجاح'), backgroundColor: AppColors.danger),
              );
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processNow() async {
    final finance = context.read<FinanceProvider>();
    final count = await context.read<RecurringProvider>().checkAndProcessDueTransactions(finance);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? 'تم تسجيل $count معاملات مستحقة بنجاح ⚡' : 'لا توجد معاملات دورية مستحقة اليوم'),
          backgroundColor: count > 0 ? AppColors.success : AppColors.info,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final recProv = context.watch<RecurringProvider>();
    final finance = context.watch<FinanceProvider>();
    final items = recProv.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاشتراكات والمعاملات الدورية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            onPressed: _processNow,
            tooltip: 'تطبيق المستحق الآن',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Total Monthly Recurring Summary Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المصاريف الدورية الشهرية المقدرة',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${recProv.activeItems.length} نشطة',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(recProv.totalMonthlyRecurringExpense, symbol: currency),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded, color: AppColors.income, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'الدخل الدوري المقدر: ${CurrencyFormatter.format(recProv.totalMonthlyRecurringIncome, symbol: currency)} / شهر',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'قائمة المعاملات المجدولة (${items.length})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _processNow,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('تحقق الآن', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.event_repeat_rounded, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('لا توجد اشتراكات أو معاملات دورية بعد', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      'أضف اشتراكاتك (مثل نتفليكس، فواتير الاتصالات، الإيجار) ليتم تسجيلها تلقائياً',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showAddEditDialog(),
                      child: const Text('إضافة أول معاملة دورية'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.map((item) {
              final cat = finance.getCategoryById(item.categoryId);
              final wallet = finance.getWalletById(item.walletId);
              final isExp = item.isExpense;

              return Opacity(
                opacity: item.isActive ? 1.0 : 0.6,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.isActive
                          ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (cat?.color ?? AppColors.primary).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat?.icon ?? Icons.repeat_rounded, color: cat?.color ?? AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.frequencyLabel,
                                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (wallet != null) ...[
                                Text(
                                  wallet.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('•', style: TextStyle(color: isDark ? Colors.white30 : Colors.black26)),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                'الاستحقاق: ${DateHelper.formatShort(item.nextDueDate)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: item.isDueNow ? AppColors.danger : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                  fontWeight: item.isDueNow ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isExp ? '-' : '+'}${CurrencyFormatter.format(item.amount, symbol: currency)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isExp ? AppColors.expense : AppColors.income,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: item.isActive,
                              activeThumbColor: AppColors.primary,
                              onChanged: (_) => recProv.toggleActive(item.id),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, size: 20),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showAddEditDialog(itemToEdit: item);
                                } else if (val == 'delete') {
                                  _confirmDelete(context, item);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('تعديل')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger), SizedBox(width: 8), Text('حذف', style: TextStyle(color: AppColors.danger))])),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('إضافة معاملة دورية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
