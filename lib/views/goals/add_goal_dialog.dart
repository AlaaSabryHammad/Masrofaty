import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../models/goal_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/theme_provider.dart';

class AddGoalDialog extends StatefulWidget {
  final GoalModel? goalToEdit;

  const AddGoalDialog({super.key, this.goalToEdit});

  @override
  State<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<AddGoalDialog> {
  final _titleController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _initialDepositController = TextEditingController();

  DateTime? _targetDate;
  int _selectedColor = 0xFF10B981;
  int _selectedIcon = Icons.savings_rounded.codePoint;

  final List<Map<String, dynamic>> _iconChoices = [
    {'icon': Icons.savings_rounded, 'name': 'حصالة'},
    {'icon': Icons.directions_car_rounded, 'name': 'سيارة'},
    {'icon': Icons.flight_takeoff_rounded, 'name': 'سفر'},
    {'icon': Icons.home_rounded, 'name': 'منزل'},
    {'icon': Icons.laptop_mac_rounded, 'name': 'أجهزة'},
    {'icon': Icons.security_rounded, 'name': 'طوارئ'},
  ];

  final List<Color> _colorChoices = [
    AppColors.primary,
    const Color(0xFF3B82F6),
    const Color(0xFF8B5CF6),
    const Color(0xFFF59E0B),
    const Color(0xFFEC4899),
    const Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.goalToEdit != null) {
      final g = widget.goalToEdit!;
      _titleController.text = g.title;
      _targetAmountController.text = g.targetAmount.truncateToDouble() == g.targetAmount
          ? g.targetAmount.toInt().toString()
          : g.targetAmount.toString();
      _targetDate = g.targetDate;
      _selectedIcon = g.iconCode;
      _selectedColor = g.colorValue;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _initialDepositController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final target = double.tryParse(_targetAmountController.text.trim()) ?? 0.0;
    if (target <= 0) return;

    if (widget.goalToEdit != null) {
      context.read<GoalProvider>().updateGoal(
            goalId: widget.goalToEdit!.id,
            title: title,
            targetAmount: target,
            targetDate: _targetDate,
            iconCode: _selectedIcon,
            colorValue: _selectedColor,
          );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث هدف الادخار بنجاح 🎯')),
      );
      return;
    }

    final initialDeposit = double.tryParse(_initialDepositController.text.trim()) ?? 0.0;
    final finance = context.read<FinanceProvider>();
    final walletId = finance.wallets.isNotEmpty ? finance.wallets.first.id : null;

    context.read<GoalProvider>().addGoal(
          title: title,
          targetAmount: target,
          initialDeposit: initialDeposit,
          targetDate: _targetDate,
          iconCode: _selectedIcon,
          colorValue: _selectedColor,
          finance: initialDeposit > 0 ? finance : null,
          fromWalletId: walletId,
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إضافة هدف الادخار بنجاح 🎯')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      widget.goalToEdit != null ? 'تعديل هدف الادخار' : 'إضافة هدف ادخار جديد',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الهدف / الصندوق',
                    hintText: 'مثال: سيارة جديدة، صندوق الطوارئ...',
                    prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _targetAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المستهدف الوصول إليه',
                    suffixText: currency,
                    prefixIcon: const Icon(Icons.monetization_on_rounded),
                  ),
                ),
                if (widget.goalToEdit == null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _initialDepositController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'دفعة افتتاحية أولى (اختياري)',
                      suffixText: currency,
                      prefixIcon: const Icon(Icons.savings_rounded),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _targetDate = picked);
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
                        Row(
                          children: [
                            const Icon(Icons.event_available_rounded, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Text(
                              _targetDate != null ? DateHelper.formatDate(_targetDate!) : 'تاريخ الإنجاز المستهدف (اختياري)',
                              style: TextStyle(
                                color: _targetDate != null
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                fontWeight: _targetDate != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        if (_targetDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _targetDate = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('اختر أيقونة الهدف:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      onSelected: (_) => setState(() => _selectedIcon = iconData.codePoint),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('اختر لون الصندوق:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        ),
                        child: isSel ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(
                    widget.goalToEdit != null ? 'حفظ التعديلات' : 'إنشاء هدف الادخار',
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
