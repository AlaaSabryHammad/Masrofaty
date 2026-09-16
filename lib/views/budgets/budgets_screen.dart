import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/category_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';

enum BudgetFilter { all, overBudget, warning, withinBudget, noBudget }

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  BudgetFilter _currentFilter = BudgetFilter.all;
  DateTime _selectedDate = DateTime.now();

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedDate.year == now.year && _selectedDate.month >= now.month) return;
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    });
  }

  String _getMonthName(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month - 1];
  }

  void _showSetBudgetDialog(CategoryModel category, String currency) {
    final controller = TextEditingController(
      text: category.budgetLimit > 0 ? category.budgetLimit.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, color: category.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ميزانية ${category.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حدد الحد الأقصى للمصاريف الشهرية لهذا التصنيف للتنبيه عند الاقتراب أو التجاوز:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'الحد الشهري المستهدف',
                suffixText: currency,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          if (category.budgetLimit > 0)
            TextButton(
              onPressed: () async {
                await context.read<FinanceProvider>().updateCategoryBudget(category.id, 0);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('إلغاء الميزانية', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final val = double.tryParse(controller.text.trim()) ?? 0.0;
              await context.read<FinanceProvider>().updateCategoryBudget(category.id, val);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final finance = context.watch<FinanceProvider>();

    final expenseCategories = finance.categories.where((c) => c.isExpense).toList();

    double totalBudget = 0.0;
    double totalSpentOnBudgeted = 0.0;

    for (final cat in expenseCategories) {
      if (cat.budgetLimit > 0) {
        totalBudget += cat.budgetLimit;
        totalSpentOnBudgeted += finance.getCategorySpentForMonth(cat.id, _selectedDate.year, _selectedDate.month);
      }
    }

    final totalSpentAll = finance.getExpenseForMonth(_selectedDate.year, _selectedDate.month);
    final overallRatio = totalBudget > 0 ? (totalSpentOnBudgeted / totalBudget).clamp(0.0, 1.5) : 0.0;
    final overallPercent = (overallRatio * 100).toInt();

    // Filter categories
    final filteredCategories = expenseCategories.where((cat) {
      final spent = finance.getCategorySpentForMonth(cat.id, _selectedDate.year, _selectedDate.month);
      final hasBudget = cat.budgetLimit > 0;
      final ratio = hasBudget ? (spent / cat.budgetLimit) : 0.0;

      switch (_currentFilter) {
        case BudgetFilter.all:
          return true;
        case BudgetFilter.overBudget:
          return hasBudget && ratio >= 1.0;
        case BudgetFilter.warning:
          return hasBudget && ratio >= 0.7 && ratio < 1.0;
        case BudgetFilter.withinBudget:
          return hasBudget && ratio < 0.7;
        case BudgetFilter.noBudget:
          return !hasBudget;
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الميزانيات والحدود الشهرية'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Month Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _previousMonth,
                  tooltip: 'الشهر السابق',
                ),
                Text(
                  '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _nextMonth,
                  tooltip: 'الشهر التالي',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Overview Budget Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إجمالي الميزانية المحددة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (overallPercent >= 100
                                ? AppColors.danger
                                : (overallPercent >= 70 ? AppColors.warning : AppColors.success))
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        totalBudget > 0 ? '$overallPercent%' : 'غير محدد',
                        style: TextStyle(
                          color: overallPercent >= 100
                              ? AppColors.danger
                              : (overallPercent >= 70 ? AppColors.warning : AppColors.success),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      CurrencyFormatter.format(totalSpentOnBudgeted, symbol: currency),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ ${CurrencyFormatter.format(totalBudget, symbol: currency)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalBudget > 0 ? (overallRatio).clamp(0.0, 1.0) : 0.0,
                    minHeight: 10,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      overallPercent >= 100
                          ? AppColors.danger
                          : (overallPercent >= 70 ? AppColors.warning : AppColors.success),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      totalBudget >= totalSpentOnBudgeted
                          ? 'المتبقي: ${CurrencyFormatter.format(totalBudget - totalSpentOnBudgeted, symbol: currency)}'
                          : 'تجاوزت الميزانية بـ: ${CurrencyFormatter.format(totalSpentOnBudgeted - totalBudget, symbol: currency)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: totalBudget >= totalSpentOnBudgeted
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : AppColors.danger,
                      ),
                    ),
                    Text(
                      'إجمالي كافة المصاريف: ${CurrencyFormatter.formatCompact(totalSpentAll, symbol: currency)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Filters Chip Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', BudgetFilter.all),
                const SizedBox(width: 8),
                _buildFilterChip('تجاوز الميزانية ⚠️', BudgetFilter.overBudget),
                const SizedBox(width: 8),
                _buildFilterChip('قريب من الحد ⏳', BudgetFilter.warning),
                const SizedBox(width: 8),
                _buildFilterChip('ضمن الميزانية ✅', BudgetFilter.withinBudget),
                const SizedBox(width: 8),
                _buildFilterChip('بدون ميزانية ➕', BudgetFilter.noBudget),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Cards
          if (filteredCategories.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('لا توجد تصنيفات مطابقة لهذا الفلتر', style: TextStyle(color: Colors.grey)),
            )
          else
            ...filteredCategories.map((cat) {
              final spent = finance.getCategorySpentForMonth(cat.id, _selectedDate.year, _selectedDate.month);
              final hasBudget = cat.budgetLimit > 0;
              final ratio = hasBudget ? (spent / cat.budgetLimit).clamp(0.0, 1.5) : 0.0;
              final percent = (ratio * 100).toInt();

              final statusColor = !hasBudget
                  ? Colors.grey
                  : (percent >= 100
                      ? AppColors.danger
                      : (percent >= 70 ? AppColors.warning : AppColors.success));

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: percent >= 100
                        ? AppColors.danger.withValues(alpha: 0.4)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                hasBudget
                                    ? '${CurrencyFormatter.format(spent, symbol: currency)} من ${CurrencyFormatter.format(cat.budgetLimit, symbol: currency)}'
                                    : 'مصروف هذا الشهر: ${CurrencyFormatter.format(spent, symbol: currency)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasBudget)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$percent%',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'تعديل الميزانية',
                          onPressed: () => _showSetBudgetDialog(cat, currency),
                        ),
                      ],
                    ),
                    if (hasBudget) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (ratio).clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            spent <= cat.budgetLimit
                                ? 'متبقي: ${CurrencyFormatter.format(cat.budgetLimit - spent, symbol: currency)}'
                                : 'تجاوزت بـ: ${CurrencyFormatter.format(spent - cat.budgetLimit, symbol: currency)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: spent <= cat.budgetLimit
                                  ? (isDark ? Colors.white60 : Colors.black54)
                                  : AppColors.danger,
                              fontWeight: spent > cat.budgetLimit ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (percent >= 100)
                            const Text(
                              'تجاوزت الحد! ⚠️',
                              style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showSetBudgetDialog(cat, currency),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('تحديد ميزانية شهرية', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String title, BudgetFilter filter) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (_) => setState(() => _currentFilter = filter),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
