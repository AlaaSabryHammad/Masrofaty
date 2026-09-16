import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';
import '../budgets/budgets_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _touchedIndex = -1;
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

  String _getMonthShortName(int month) {
    const months = [
      'ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون',
      'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final finance = context.watch<FinanceProvider>();

    final expenseDist = finance.getExpenseDistributionForMonth(_selectedDate.year, _selectedDate.month);
    final totalExpense = expenseDist.values.fold(0.0, (sum, val) => sum + val);

    final income = finance.getIncomeForMonth(_selectedDate.year, _selectedDate.month);
    final expense = finance.getExpenseForMonth(_selectedDate.year, _selectedDate.month);
    final savings = income - expense;
    final savingRate = income > 0 ? ((savings / income) * 100).clamp(0, 100).toInt() : 0;

    // 6 Months Historical Data
    final historicalMonths = List.generate(6, (i) {
      final d = DateTime(_selectedDate.year, _selectedDate.month - (5 - i), 1);
      final mIncome = finance.getIncomeForMonth(d.year, d.month);
      final mExpense = finance.getExpenseForMonth(d.year, d.month);
      return {
        'date': d,
        'income': mIncome,
        'expense': mExpense,
        'label': _getMonthShortName(d.month),
      };
    });

    double maxHistoricalValue = 100.0;
    for (final m in historicalMonths) {
      final inc = m['income'] as double;
      final exp = m['expense'] as double;
      if (inc > maxHistoricalValue) maxHistoricalValue = inc;
      if (exp > maxHistoricalValue) maxHistoricalValue = exp;
    }

    final isCurrentMonth = _selectedDate.year == DateTime.now().year && _selectedDate.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
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
                Row(
                  children: [
                    Text(
                      '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (isCurrentMonth) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'الشهر الحالي',
                          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: isCurrentMonth ? null : _nextMonth,
                  tooltip: 'الشهر التالي',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Budgets Tracker Navigation Banner
          InkWell(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetsScreen()));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0C4A6E), const Color(0xFF075985)]
                      : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.pie_chart_rounded, color: Color(0xFF0284C7), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مراقبة الميزانيات والحدود الشهرية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('تابع استهلاك حدود الصرف لكل تصنيف وتفادي التجاوز', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF0284C7)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Financial Health Overview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF1F5F9), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('معدل الادخار الشهري', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: (savings >= 0 ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$savingRate%',
                        style: TextStyle(
                          color: savings >= 0 ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: savingRate / 100.0,
                    minHeight: 10,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(savings >= 0 ? AppColors.success : AppColors.danger),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('الدخل', income, AppColors.income, currency),
                    _buildStatItem('المصاريف', expense, AppColors.expense, currency),
                    _buildStatItem('صافي الفائض', savings, savings >= 0 ? AppColors.success : AppColors.danger, currency),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 6-Month Comparison Bar Chart
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل آخر 6 أشهر (دخل مقابل مصروف)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.income, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('دخل', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 10),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.expense, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('مصروف', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            height: 240,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxHistoricalValue * 1.25,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? Colors.black87 : Colors.white,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < historicalMonths.length) {
                          final label = historicalMonths[idx]['label'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: idx == 5 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 11,
                                color: idx == 5 ? AppColors.primary : null,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(historicalMonths.length, (i) {
                  final m = historicalMonths[i];
                  final inc = m['income'] as double;
                  final exp = m['expense'] as double;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: inc,
                        color: AppColors.income,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: exp,
                        color: AppColors.expense,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Donut Chart: Expense Breakdown
          Text(
            'توزيع المصاريف حسب التصنيف (${_getMonthName(_selectedDate.month)})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          if (totalExpense <= 0)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: const Center(
                child: Text('لا توجد مصاريف مسجلة لهذا الشهر'),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: 50,
                        sections: _buildPieSections(expenseDist, totalExpense),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Category Breakdown Rows
                  ...expenseDist.entries.map((entry) {
                    final cat = finance.getCategoryById(entry.key);
                    final percent = ((entry.value / totalExpense) * 100).toStringAsFixed(1);
                    final color = cat?.color ?? AppColors.primary;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat?.name ?? 'أخرى',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Text(
                            '$percent% (${CurrencyFormatter.format(entry.value, symbol: currency)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, double amount, Color color, String currency) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.formatCompact(amount, symbol: currency),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data, double total) {
    final finance = context.read<FinanceProvider>();
    final entries = data.entries.toList();

    return List.generate(entries.length, (i) {
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 45.0 : 35.0;
      final entry = entries[i];
      final cat = finance.getCategoryById(entry.key);
      final color = cat?.color ?? AppColors.primary;

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '',
        radius: radius,
      );
    });
  }
}
