import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/wallet_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';

class AddWalletDialog extends StatefulWidget {
  final WalletModel? walletToEdit;

  const AddWalletDialog({super.key, this.walletToEdit});

  @override
  State<AddWalletDialog> createState() => _AddWalletDialogState();
}

class _AddWalletDialogState extends State<AddWalletDialog> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  int _selectedColor = 0xFF10B981;
  int _selectedIcon = Icons.account_balance_wallet_rounded.codePoint;
  String _selectedType = 'bank';

  final List<Map<String, dynamic>> _iconChoices = [
    {'icon': Icons.account_balance_wallet_rounded, 'name': 'محفظة'},
    {'icon': Icons.account_balance_rounded, 'name': 'بنك'},
    {'icon': Icons.payments_rounded, 'name': 'كاش'},
    {'icon': Icons.credit_card_rounded, 'name': 'بطاقة'},
    {'icon': Icons.savings_rounded, 'name': 'توفير'},
    {'icon': Icons.phone_android_rounded, 'name': 'رقمية'},
  ];

  final List<Color> _colorChoices = [
    AppColors.primary,
    const Color(0xFF3B82F6),
    const Color(0xFF8B5CF6),
    const Color(0xFFF59E0B),
    const Color(0xFFEC4899),
    const Color(0xFF06B6D4),
    const Color(0xFFF43F5E),
    const Color(0xFF64748B),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.walletToEdit != null) {
      final w = widget.walletToEdit!;
      _nameController.text = w.name;
      _balanceController.text = w.balance.truncateToDouble() == w.balance
          ? w.balance.toInt().toString()
          : w.balance.toString();
      _selectedColor = w.colorValue;
      _selectedIcon = w.iconCode;
      _selectedType = w.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;

    if (widget.walletToEdit != null) {
      final updated = widget.walletToEdit!.copyWith(
        name: name,
        type: _selectedType,
        balance: balance,
        iconCode: _selectedIcon,
        colorValue: _selectedColor,
      );
      context.read<FinanceProvider>().updateWallet(updated);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث المحفظة بنجاح 💼')),
      );
      return;
    }

    context.read<FinanceProvider>().addWallet(
          name: name,
          type: _selectedType,
          initialBalance: balance,
          iconCode: _selectedIcon,
          colorValue: _selectedColor,
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إضافة المحفظة / الحساب بنجاح 💼')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                Text(
                  widget.walletToEdit != null ? 'تعديل المحفظة' : 'إضافة حساب أو محفظة',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحساب / المحفظة',
                    hintText: 'مثال: البنك الأهلي، محفظة التوفير...',
                    prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'الرصيد الافتتاحي',
                    suffixText: currency,
                    prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('اختر الأيقونة:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _iconChoices.map((item) {
                    final iconData = item['icon'] as IconData;
                    final isSel = _selectedIcon == iconData.codePoint;
                    return ChoiceChip(
                      selected: isSel,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconData, size: 18, color: isSel ? Colors.white : null),
                          const SizedBox(width: 6),
                          Text(item['name'] as String),
                        ],
                      ),
                      onSelected: (_) => setState(() {
                        _selectedIcon = iconData.codePoint;
                        _selectedType = (item['name'] as String).toLowerCase();
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('اختر لون البطاقة:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  children: _colorChoices.map((c) {
                    final isSel = _selectedColor == c.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c.toARGB32()),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                          boxShadow: isSel
                              ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)]
                              : null,
                        ),
                        child: isSel ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(
                    widget.walletToEdit != null ? 'حفظ التعديلات' : 'إضافة المحفظة',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
