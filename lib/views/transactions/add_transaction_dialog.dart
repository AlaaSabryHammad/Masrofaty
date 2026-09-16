import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../providers/contact_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';

class AddTransactionDialog extends StatefulWidget {
  final bool initialIsExpense;
  final TransactionModel? transactionToEdit;

  const AddTransactionDialog({
    super.key,
    this.initialIsExpense = true,
    this.transactionToEdit,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late bool _isExpense;
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _personController = TextEditingController();
  final _notesController = TextEditingController();

  CategoryModel? _selectedCategory;
  WalletModel? _selectedWallet;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!;
      _isExpense = tx.isExpense;
      _amountController.text = tx.amount.truncateToDouble() == tx.amount
          ? tx.amount.toInt().toString()
          : tx.amount.toString();
      _titleController.text = tx.title;
      _personController.text = tx.personName ?? '';
      _notesController.text = tx.notes ?? '';
      _selectedDate = tx.date;
    } else {
      _isExpense = widget.initialIsExpense;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final finance = context.read<FinanceProvider>();
      final filteredCats = finance.categories.where((c) => c.isExpense == _isExpense).toList();
      setState(() {
        if (widget.transactionToEdit != null) {
          _selectedCategory = finance.getCategoryById(widget.transactionToEdit!.categoryId) ??
              (filteredCats.isNotEmpty ? filteredCats.first : null);
          _selectedWallet = finance.getWalletById(widget.transactionToEdit!.walletId) ??
              (finance.wallets.isNotEmpty ? finance.wallets.first : null);
        } else {
          if (filteredCats.isNotEmpty) _selectedCategory = filteredCats.first;
          if (finance.wallets.isNotEmpty) _selectedWallet = finance.wallets.first;
        }
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _personController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(bool isExpense) {
    setState(() {
      _isExpense = isExpense;
      final finance = context.read<FinanceProvider>();
      final filteredCats = finance.categories.where((c) => c.isExpense == _isExpense).toList();
      _selectedCategory = filteredCats.isNotEmpty ? filteredCats.first : null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedWallet == null) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    final personName = _personController.text.trim().isEmpty ? null : _personController.text.trim();
    String? contactId;
    if (personName != null) {
      final contact = context.read<ContactProvider>().getOrCreateContact(personName);
      contactId = contact.id;
    }

    if (widget.transactionToEdit != null) {
      final updated = widget.transactionToEdit!.copyWith(
        title: _titleController.text.trim(),
        amount: amount,
        type: _isExpense ? 'expense' : 'income',
        categoryId: _selectedCategory!.id,
        walletId: _selectedWallet!.id,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        personName: personName,
        contactId: contactId,
      );
      context.read<FinanceProvider>().updateTransaction(updated);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تم تحديث المعاملة بنجاح',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      context.read<FinanceProvider>().addTransaction(
            title: _titleController.text.trim(),
            amount: amount,
            type: _isExpense ? 'expense' : 'income',
            categoryId: _selectedCategory!.id,
            walletId: _selectedWallet!.id,
            date: _selectedDate,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            personName: personName,
            contactId: contactId,
          );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isExpense ? 'تم تسجيل المصروف بنجاح' : 'تم إضافة الإيراد بنجاح',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _isExpense ? AppColors.expense : AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final finance = context.watch<FinanceProvider>();
    final availableCategories = finance.categories.where((c) => c.isExpense == _isExpense).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            // Header & Type Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.transactionToEdit != null
                        ? 'تعديل المعاملة'
                        : (_isExpense ? 'تسجيل مصروف جديد' : 'إضافة دخل جديد'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            // Segmented switch (مصروف / إيراد)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTypeChanged(true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isExpense ? AppColors.expense : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 18,
                                color: _isExpense ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'مصروف',
                                style: TextStyle(
                                  color: _isExpense ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTypeChanged(false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isExpense ? AppColors.income : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 18,
                                color: !_isExpense ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'إيراد / دخل',
                                style: TextStyle(
                                  color: !_isExpense ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Amount Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_isExpense ? AppColors.expense : AppColors.income).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (_isExpense ? AppColors.expense : AppColors.income).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          currency,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _isExpense ? AppColors.expense : AppColors.income,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'يرجى إدخال المبلغ';
                              if (double.tryParse(val) == null) return 'أدخل رقماً صحيحاً';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title Input
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'الوصف أو البيان',
                      hintText: _isExpense ? 'مثال: مشتريات سوبرماركت، مطعم...' : 'مثال: راتب، مكافأة...',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'يرجى إدخال الوصف';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Category Selector Label
                  const Text('التصنيف', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableCategories.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final cat = availableCategories[index];
                        final isSelected = _selectedCategory?.id == cat.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 82,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? cat.color.withValues(alpha: isDark ? 0.3 : 0.15)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? cat.color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cat.color.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(cat.icon, color: cat.color, size: 22),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Wallet & Date Row
                  Row(
                    children: [
                      // Wallet Selector
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('المحفظة / الحساب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<WalletModel>(
                              initialValue: _selectedWallet,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: finance.wallets.map((w) {
                                return DropdownMenuItem(
                                  value: w,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(w.icon, size: 18, color: w.color),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          w.name,
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedWallet = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Date Selector
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('التاريخ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateHelper.formatShort(_selectedDate),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Optional Person/Contact Field
                  Builder(
                    builder: (context) {
                      final contacts = context.watch<ContactProvider>().contacts;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (contacts.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.people_outline_rounded, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                                const SizedBox(width: 4),
                                Text(
                                  'جهة التعامل أو الشخص (اختياري):',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 36,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: contacts.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final c = contacts[index];
                                  final isSelected = _personController.text.trim() == c.name;
                                  return FilterChip(
                                    showCheckmark: false,
                                    selected: isSelected,
                                    avatar: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: isSelected
                                          ? Colors.white
                                          : AppColors.primaryEmerald.withValues(alpha: 0.2),
                                      child: Text(
                                        c.avatarInitial,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? AppColors.primaryEmerald : null,
                                        ),
                                      ),
                                    ),
                                    label: Text(
                                      c.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    selectedColor: AppColors.primaryEmerald,
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppColors.primaryEmerald
                                          : (isDark ? Colors.white12 : Colors.black12),
                                    ),
                                    onSelected: (_) {
                                      setState(() {
                                        if (isSelected) {
                                          _personController.clear();
                                        } else {
                                          _personController.text = c.name;
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          TextFormField(
                            controller: _personController,
                            decoration: InputDecoration(
                              labelText: 'جهة التعامل / الشخص (اختياري)',
                              hintText: 'مثال: أحمد علي، السوبرماركت، العميل...',
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                              suffixIcon: _personController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () => setState(() => _personController.clear()),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Notes Input
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات إضافية (اختياري)',
                      hintText: 'مكان الشراء، رقم الإيصال، إلخ...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isExpense ? AppColors.expense : AppColors.income,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      widget.transactionToEdit != null
                          ? 'حفظ التعديلات'
                          : (_isExpense ? 'حفظ المصروف' : 'حفظ الإيراد'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
