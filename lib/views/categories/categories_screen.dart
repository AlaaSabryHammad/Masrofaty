import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/category_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _iconChoices = [
    {'icon': Icons.shopping_bag_rounded, 'name': 'تسوق'},
    {'icon': Icons.restaurant_rounded, 'name': 'مطاعم'},
    {'icon': Icons.directions_car_rounded, 'name': 'مواصلات'},
    {'icon': Icons.receipt_long_rounded, 'name': 'فواتير'},
    {'icon': Icons.medical_services_rounded, 'name': 'صحة'},
    {'icon': Icons.school_rounded, 'name': 'تعليم'},
    {'icon': Icons.sports_esports_rounded, 'name': 'ترفيه'},
    {'icon': Icons.home_rounded, 'name': 'سكن'},
    {'icon': Icons.family_restroom_rounded, 'name': 'عائلة'},
    {'icon': Icons.savings_rounded, 'name': 'ادخار'},
    {'icon': Icons.work_rounded, 'name': 'عمل / راتب'},
    {'icon': Icons.trending_up_rounded, 'name': 'استثمار'},
    {'icon': Icons.card_giftcard_rounded, 'name': 'مكافأة / هدية'},
    {'icon': Icons.laptop_chromebook_rounded, 'name': 'عمل حر'},
    {'icon': Icons.category_rounded, 'name': 'عام'},
  ];

  final List<Color> _colorChoices = [
    AppColors.primary,
    const Color(0xFFEF4444),
    const Color(0xFF3B82F6),
    const Color(0xFF8B5CF6),
    const Color(0xFFF59E0B),
    const Color(0xFFEC4899),
    const Color(0xFF06B6D4),
    const Color(0xFF10B981),
    const Color(0xFF6366F1),
    const Color(0xFF14B8A6),
    const Color(0xFF84CC16),
    const Color(0xFF64748B),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditDialog({CategoryModel? categoryToEdit, required bool isExpense}) {
    final nameController = TextEditingController(text: categoryToEdit?.name ?? '');
    final budgetController = TextEditingController(
      text: categoryToEdit != null && categoryToEdit.budgetLimit > 0
          ? categoryToEdit.budgetLimit.toStringAsFixed(0)
          : '',
    );
    int selectedIcon = categoryToEdit?.iconCode ??
        (isExpense ? Icons.shopping_bag_rounded.codePoint : Icons.work_rounded.codePoint);
    int selectedColor = categoryToEdit?.colorValue ??
        (isExpense ? AppColors.expense.toARGB32() : AppColors.income.toARGB32());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
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
                      Text(
                        categoryToEdit != null
                            ? 'تعديل التصنيف'
                            : (isExpense ? 'إضافة تصنيف مصروف جديد' : 'إضافة تصنيف دخل جديد'),
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
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم التصنيف',
                          hintText: 'مثال: مشتريات البقالة، مكافأة...',
                          prefixIcon: Icon(Icons.label_outline_rounded),
                        ),
                      ),
                      if (isExpense) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: budgetController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'حد الميزانية الشهرية (اختياري)',
                            hintText: '0 للميزانية غير المحددة',
                            suffixText: currency,
                            prefixIcon: const Icon(Icons.speed_rounded),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text('اختر الأيقونة:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _iconChoices.map((item) {
                          final icon = item['icon'] as IconData;
                          final isSel = selectedIcon == icon.codePoint;
                          return ChoiceChip(
                            selected: isSel,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 18, color: isSel ? Colors.white : null),
                                const SizedBox(width: 6),
                                Text(item['name'] as String, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            onSelected: (_) => setDlgState(() => selectedIcon = icon.codePoint),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('اختر اللون المميز:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: _colorChoices.map((c) {
                          final isSel = selectedColor == c.toARGB32();
                          return GestureDetector(
                            onTap: () => setDlgState(() => selectedColor = c.toARGB32()),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                                boxShadow: isSel
                                    ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                                    : null,
                              ),
                              child: isSel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          final budget = double.tryParse(budgetController.text.trim()) ?? 0.0;
                          final finance = context.read<FinanceProvider>();

                          if (categoryToEdit != null) {
                            finance.updateCategory(categoryToEdit.copyWith(
                              name: name,
                              iconCode: selectedIcon,
                              colorValue: selectedColor,
                              budgetLimit: isExpense ? budget : 0.0,
                            ));
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تحديث التصنيف بنجاح 🏷️')),
                            );
                          } else {
                            finance.addCategory(
                              name: name,
                              isExpense: isExpense,
                              iconCode: selectedIcon,
                              colorValue: selectedColor,
                              budgetLimit: isExpense ? budget : 0.0,
                            );
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إضافة التصنيف الجديد بنجاح 🏷️')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExpense ? AppColors.expense : AppColors.income,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          categoryToEdit != null ? 'حفظ التعديلات' : 'إضافة التصنيف',
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

  void _confirmDelete(BuildContext context, CategoryModel cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('حذف التصنيف؟'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف تصنيف "${cat.name}"؟\nسيتم نقل أي معاملات سابقة مرتبطة به إلى التصنيف الافتراضي تلقائياً.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await context.read<FinanceProvider>().deleteCategory(cat.id);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حذف تصنيف "${cat.name}" بنجاح'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لا يمكن حذف هذا التصنيف (يجب الإبقاء على تصنيف واحد على الأقل)'),
                    ),
                  );
                }
              }
            },
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
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

    final expenseCats = finance.categories.where((c) => c.isExpense).toList();
    final incomeCats = finance.categories.where((c) => !c.isExpense).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التصنيفات'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: [
            Tab(text: 'المصاريف (${expenseCats.length})'),
            Tab(text: 'الإيرادات (${incomeCats.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(expenseCats, isExpense: true, isDark: isDark, currency: currency, finance: finance),
          _buildCategoryList(incomeCats, isExpense: false, isDark: isDark, currency: currency, finance: finance),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final isExp = _tabController.index == 0;
          _showAddEditDialog(isExpense: isExp);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('تصنيف جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoryList(
    List<CategoryModel> cats, {
    required bool isExpense,
    required bool isDark,
    required String currency,
    required FinanceProvider finance,
  }) {
    if (cats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('لا توجد تصنيفات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showAddEditDialog(isExpense: isExpense),
              child: const Text('إضافة أول تصنيف'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final cat = cats[index];
        final monthlySpent = isExpense ? finance.getCategoryMonthlySpent(cat.id) : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(cat.icon, color: cat.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    if (isExpense && cat.budgetLimit > 0)
                      Text(
                        'تم صرف ${CurrencyFormatter.format(monthlySpent, symbol: currency)} من ${CurrencyFormatter.format(cat.budgetLimit, symbol: currency)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: (monthlySpent > cat.budgetLimit) ? AppColors.danger : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                      )
                    else
                      Text(
                        isExpense ? 'ميزانية مفتوحة' : 'إيراد / دخل مالي',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    onPressed: () => _showAddEditDialog(categoryToEdit: cat, isExpense: isExpense),
                    tooltip: 'تعديل التصنيف',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    onPressed: () => _confirmDelete(context, cat),
                    tooltip: 'حذف التصنيف',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
