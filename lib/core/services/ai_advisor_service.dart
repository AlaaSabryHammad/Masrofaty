import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../models/debt_model.dart';
import '../../providers/finance_provider.dart';

class AdvisorTip {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String badge;

  AdvisorTip({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.badge,
  });
}

class AiAdvisorService {
  static List<AdvisorTip> analyzeFinances({
    required FinanceProvider finance,
    required List<DebtModel> debts,
    required String currency,
  }) {
    final List<AdvisorTip> tips = [];
    final income = finance.monthlyIncome;
    final expense = finance.monthlyExpense;
    final savings = finance.monthlySavings;
    final savingRate = income > 0 ? ((savings / income) * 100).toInt() : 0;

    // 1. Savings Rate Analysis
    if (savings < 0) {
      tips.add(AdvisorTip(
        title: 'عجز مالي في ميزانية هذا الشهر!',
        description: 'مصاريفك تتجاوز دخلك بمقدار ${(expense - income).toStringAsFixed(0)} $currency. ننصح بالحد الفوري من المصاريف غير الأساسية كالمطاعم والترفيه.',
        icon: Icons.warning_amber_rounded,
        color: AppColors.danger,
        badge: 'تنبيه حرج',
      ));
    } else if (savingRate >= 20) {
      tips.add(AdvisorTip(
        title: 'أداء مالي ممتاز! معدل ادخار مرتفع',
        description: 'أنت تدخر حالياً $savingRate% من دخلك. يمكنك استثمار هذا الفائض (${savings.toStringAsFixed(0)} $currency) في صندوق طوارئ أو أهداف التوفير.',
        icon: Icons.stars_rounded,
        color: AppColors.success,
        badge: 'إنجاز ممتاز',
      ));
    } else if (savingRate > 0 && savingRate < 10) {
      tips.add(AdvisorTip(
        title: 'فرصة لزيادة معدل الادخار',
        description: 'نسبة ادخارك الحالية هي $savingRate% فقط. الهدف المالي الموصى به عالمياً هو تخصيص 20% على الأقل من الدخل للتوفير والاستثمار.',
        icon: Icons.lightbulb_outline_rounded,
        color: AppColors.warning,
        badge: 'توصية ذكية',
      ));
    }

    // 2. High Expense Categories Analysis
    final dist = finance.getExpenseDistribution();
    if (dist.isNotEmpty && expense > 0) {
      final sorted = dist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      final topCat = finance.getCategoryById(top.key);
      final topPercent = ((top.value / expense) * 100).toInt();

      if (topPercent >= 40 && topCat != null) {
        tips.add(AdvisorTip(
          title: 'تركيز نفقات عالٍ في "${topCat.name}"',
          description: 'تصنيف "${topCat.name}" يستهلك $topPercent% من كامل مصاريفك هذا الشهر بمبلغ ${top.value.toStringAsFixed(0)} $currency. فكّر في وضع ميزانية محددة لهذا التصنيف.',
          icon: Icons.pie_chart_outline_rounded,
          color: AppColors.info,
          badge: 'تحليل سلوك الصرف',
        ));
      }
    }

    // 3. Debts & Liabilities Analysis
    final overdueDebts = debts.where((d) => d.isOverdue && d.isBorrowed).toList();
    if (overdueDebts.isNotEmpty) {
      final totalOverdue = overdueDebts.fold(0.0, (sum, d) => sum + d.remainingAmount);
      tips.add(AdvisorTip(
        title: 'يوجد ديون متأخرة واجبة السداد!',
        description: 'عليك ديون متأخرة بإجمالي ${totalOverdue.toStringAsFixed(0)} $currency. سداد هذه الالتزامات أولوية قصوى لتفادي أي التزامات إضافية.',
        icon: Icons.priority_high_rounded,
        color: AppColors.danger,
        badge: 'أولوية سداد',
      ));
    }

    final receivables = debts.where((d) => d.isLent && !d.isSettled).toList();
    if (receivables.isNotEmpty) {
      final totalReceivables = receivables.fold(0.0, (sum, d) => sum + d.remainingAmount);
      tips.add(AdvisorTip(
        title: 'أموال مستحقة لك عند الآخرين',
        description: 'لديك سلف مستحقة بقيمة ${totalReceivables.toStringAsFixed(0)} $currency. يمكنك استخدام خاصية "تذكير واتساب" لمتابعة تحصيلها بلطف.',
        icon: Icons.handshake_rounded,
        color: AppColors.debtLent,
        badge: 'تحصيل مستحقات',
      ));
    }

    // 4. Emergency Fund Rule
    if (tips.length < 4) {
      tips.add(AdvisorTip(
        title: 'قاعدة 50/30/20 لإدارة الميزانية',
        description: 'قسّم دخلك: 50% للاحتياجات الأساسية (فواتير، إيجار، طعام)، 30% للرغبات والترفيه، و 20% للادخار وصناديق التوفير.',
        icon: Icons.tips_and_updates_rounded,
        color: AppColors.primary,
        badge: 'نصيحة ذهبية',
      ));
    }

    return tips;
  }
}
