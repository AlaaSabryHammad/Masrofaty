import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/bill_parser_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';

class SmartParserDialog extends StatefulWidget {
  const SmartParserDialog({super.key});

  @override
  State<SmartParserDialog> createState() => _SmartParserDialogState();
}

class _SmartParserDialogState extends State<SmartParserDialog> {
  final _textController = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  ParsedBillResult? _parsedResult;
  String? _selectedWalletId;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final finance = context.read<FinanceProvider>();
      if (finance.wallets.isNotEmpty) {
        setState(() {
          _selectedWalletId = finance.wallets.first.id;
        });
      }
    });
  }

  void _parseText(String text) {
    if (text.trim().isEmpty) {
      setState(() {
        _parsedResult = null;
        _titleController.clear();
        _amountController.clear();
      });
      return;
    }
    final res = BillParserService.parse(text);
    setState(() {
      _parsedResult = res;
      _selectedCategoryId = res.categoryId;
      _titleController.text = res.merchant ?? (res.isExpense ? 'مشتريات' : 'إيداع');
      if (res.amount != null) {
        _amountController.text = res.amount.toString();
      }
    });
  }

  void _applySample(String sample) {
    _textController.text = sample;
    _parseText(sample);
  }

  void _confirmAndSave() {
    final amt = double.tryParse(_amountController.text.trim()) ?? _parsedResult?.amount ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صالح أولاً')),
      );
      return;
    }

    final finance = context.read<FinanceProvider>();
    final wallet = _selectedWalletId ?? (finance.wallets.isNotEmpty ? finance.wallets.first.id : 'wallet_cash');
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_parsedResult?.merchant ?? 'عملية شراء');
    final catId = _selectedCategoryId ?? _parsedResult?.categoryId ?? 'cat_other_exp';
    final isExp = _parsedResult?.isExpense ?? true;

    finance.addTransaction(
      title: title,
      amount: amt,
      type: isExp ? 'expense' : 'income',
      categoryId: catId,
      walletId: wallet,
      date: DateTime.now(),
      notes: 'تمت الإضافة عبر القارئ الذكي: ${_textController.text.trim()}',
    );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تسجيل العملية بنجاح بمبلغ $amt عبر القارئ الذكي',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final finance = context.watch<FinanceProvider>();

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('القارئ الذكي للرسائل البنكية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'الصق نص الرسالة البنكية أو الفاتورة ليتم استخراج البيانات تلقائياً:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Text Input
                TextField(
                  controller: _textController,
                  maxLines: 4,
                  onChanged: _parseText,
                  decoration: InputDecoration(
                    hintText: 'مثال: شراء عبر مدى بمبلغ 145.50 ر.س لدى سوبرماركت بنده...',
                    suffixIcon: _textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _textController.clear();
                              _parseText('');
                            },
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

                // Quick Sample Chips
                const Text('أو جرب رسالة نموذجية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.shopping_cart_rounded, size: 16),
                        label: const Text('بنده 145 ر.س'),
                        onPressed: () => _applySample('شراء ببطاقة مدى: خصم مبلغ 145.00 ر.س لدى سوبرماركت بنده ماركت'),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.local_gas_station_rounded, size: 16),
                        label: const Text('وقود ساسكو 90 ر.س'),
                        onPressed: () => _applySample('تمت عملية شراء عبر البطاقة بمبلغ 90.00 SAR لدى محطة ساسكو للوقود'),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.account_balance_rounded, size: 16),
                        label: const Text('إيداع راتب 12500 ر.س'),
                        onPressed: () => _applySample('حوالة واردة / إيداع راتب بمبلغ 12,500.00 ر.س لحسابك الجاري'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Extracted Result Box & Editing Form
                if (_parsedResult != null && _parsedResult!.amount != null) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text('تم استخراج البيانات - راجع وعدّل قبل الحفظ:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (_parsedResult!.isExpense ? AppColors.expense : AppColors.income).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _parsedResult!.isExpense ? 'مصروف' : 'دخل / إيداع',
                                style: TextStyle(
                                  color: _parsedResult!.isExpense ? AppColors.expense : AppColors.income,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title & Amount
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'البيان / المتجر',
                            prefixIcon: Icon(Icons.store_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'المبلغ المستخرج',
                            suffixText: currency,
                            prefixIcon: const Icon(Icons.attach_money_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'التصنيف',
                            prefixIcon: Icon(Icons.category_rounded),
                          ),
                          items: finance.categories
                              .where((c) => c.isExpense == _parsedResult!.isExpense)
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
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                        const SizedBox(height: 12),

                        // Wallet Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedWalletId ?? (finance.wallets.isNotEmpty ? finance.wallets.first.id : null),
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _parsedResult!.isExpense ? 'الخصم من محفظة:' : 'الإيداع في محفظة:',
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
                          onChanged: (val) => setState(() => _selectedWalletId = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _confirmAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('تأكيد وحفظ المعاملة بنجاح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
