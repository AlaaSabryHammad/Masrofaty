import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../providers/contact_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';

class AddDebtDialog extends StatefulWidget {
  final bool initialIsLent; // true = أموال لي (سلفة), false = أموال علي (دين)
  final String? prefilledName;
  final String? prefilledPhone;

  const AddDebtDialog({
    super.key,
    this.initialIsLent = true,
    this.prefilledName,
    this.prefilledPhone,
  });

  @override
  State<AddDebtDialog> createState() => _AddDebtDialogState();
}

class _AddDebtDialogState extends State<AddDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  late bool _isLent;
  late final TextEditingController _personNameController;
  late final TextEditingController _phoneController;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dueDate;
  String? _selectedWalletId;

  @override
  void initState() {
    super.initState();
    _isLent = widget.initialIsLent;
    _personNameController = TextEditingController(text: widget.prefilledName ?? '');
    _phoneController = TextEditingController(text: widget.prefilledPhone ?? '');
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    final name = _personNameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();

    // Auto-register to fixed contacts
    context.read<ContactProvider>().getOrCreateContact(name, phone: phone);

    final finance = context.read<FinanceProvider>();
    final wallet = _selectedWalletId != null ? finance.getWalletById(_selectedWalletId!) : null;

    context.read<DebtProvider>().addDebt(
          personName: name,
          phone: phone,
          totalAmount: amount,
          type: _isLent ? 'lent' : 'borrowed',
          dueDate: _dueDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          walletId: wallet?.id,
          walletName: wallet?.name,
        );

    // If wallet linked: deduct if lending money, add if borrowing money
    if (wallet != null) {
      if (_isLent) {
        finance.adjustWalletBalance(wallet.id, -amount);
      } else {
        finance.adjustWalletBalance(wallet.id, amount);
      }
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isLent
              ? (wallet != null
                  ? 'تم تسجيل السلفة وخصم ${CurrencyFormatter.format(amount)} من ${wallet.name}'
                  : 'تم تسجيل السلفة (أموال لك) بنجاح')
              : (wallet != null
                  ? 'تم تسجيل الدين وإيداع ${CurrencyFormatter.format(amount)} في ${wallet.name}'
                  : 'تم تسجيل الدين (التزام عليك) بنجاح'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _isLent ? AppColors.debtLent : AppColors.debtBorrowed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;

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

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLent ? 'تسجيل سلفة جديدة (أموال لي)' : 'تسجيل دين جديد (أموال علي)',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            // Segmented switch
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
                        onTap: () => setState(() => _isLent = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isLent ? AppColors.debtLent : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.call_made_rounded,
                                size: 18,
                                color: _isLent ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'أموال لي (سلفة)',
                                style: TextStyle(
                                  color: _isLent ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
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
                        onTap: () => setState(() => _isLent = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isLent ? AppColors.debtBorrowed : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.call_received_rounded,
                                size: 18,
                                color: !_isLent ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'أموال علي (دين)',
                                style: TextStyle(
                                  color: !_isLent ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
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
                  // Amount
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_isLent ? AppColors.debtLent : AppColors.debtBorrowed).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (_isLent ? AppColors.debtLent : AppColors.debtBorrowed).withValues(alpha: 0.25),
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
                            color: _isLent ? AppColors.debtLent : AppColors.debtBorrowed,
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

                  // Quick contacts list if available
                  Builder(
                    builder: (context) {
                      final contacts = context.watch<ContactProvider>().contacts;
                      if (contacts.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people_outline_rounded, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                'جهات التعامل المسجلة (اختر للملء السريع):',
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
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: contacts.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final c = contacts[index];
                                final isSelected = _personNameController.text.trim() == c.name;
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
                                      _personNameController.text = c.name;
                                      if (c.phone != null && c.phone!.isNotEmpty) {
                                        _phoneController.text = c.phone!;
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),

                  // Person Name
                  TextFormField(
                    controller: _personNameController,
                    decoration: InputDecoration(
                      labelText: _isLent ? 'اسم المستلف (من أخذ منك)' : 'اسم الدائن (من أخذت منه)',
                      hintText: 'مثال: محمد أحمد، شركة التقسيط...',
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'يرجى إدخال الاسم';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف (اختياري)',
                      hintText: '+966...',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Due Date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تاريخ السداد / الاستحقاق المتوقع',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDueDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Text(
                                    _dueDate != null
                                        ? DateHelper.formatDate(_dueDate!)
                                        : 'حدد تاريخ الاستحقاق (اختياري)',
                                    style: TextStyle(
                                      fontWeight: _dueDate != null ? FontWeight.bold : FontWeight.normal,
                                      color: _dueDate != null
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    ),
                                  ),
                                ],
                              ),
                              if (_dueDate != null)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _dueDate = null),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Wallet Linking Selector
                  Builder(
                    builder: (context) {
                      final wallets = context.watch<FinanceProvider>().wallets;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 16,
                                color: _isLent ? AppColors.debtLent : AppColors.debtBorrowed,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isLent ? 'خصم السلفة من محفظة:' : 'إيداع الدين في محفظة:',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedWalletId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('بدون ربط بالمحافظ (تسجيل فقط)'),
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
                                          '${w.name} (${CurrencyFormatter.format(w.balance, symbol: currency)})',
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) => setState(() => _selectedWalletId = val),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'سبب أو تفاصيل الدين (اختياري)',
                      hintText: 'تفاصيل الاتفاق أو رقم المعاملة...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLent ? AppColors.debtLent : AppColors.debtBorrowed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _isLent ? 'حفظ السلفة' : 'حفظ الدين',
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
