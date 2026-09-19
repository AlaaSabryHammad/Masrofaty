import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/goal_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/theme_provider.dart';
import 'add_goal_dialog.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  void _showAddGoal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddGoalDialog(),
    );
  }

  void _showDepositDialog(BuildContext context, GoalModel goal, String currency) {
    final amountController = TextEditingController();
    final finance = context.read<FinanceProvider>();
    final rawWallets = finance.wallets;
    final wallets = <WalletModel>[];
    final seen = <String>{};
    for (final w in rawWallets) {
      if (seen.add(w.id)) {
        wallets.add(w);
      }
    }
    WalletModel? selectedWallet = wallets.isNotEmpty ? wallets.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final effectiveWallet = (wallets.contains(selectedWallet))
              ? selectedWallet
              : (wallets.isNotEmpty ? wallets.first : null);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(goal.icon, color: goal.color),
                const SizedBox(width: 8),
                Text('إيداع في ${goal.title}'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المتبقي لتحقيق الهدف: ${CurrencyFormatter.format(goal.remainingAmount, symbol: currency)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'مبلغ الإيداع',
                    suffixText: currency,
                    prefixIcon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('خصم من محفظة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<WalletModel>(
                  initialValue: effectiveWallet,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w,
                      child: Text(
                        '${w.name} (${w.balance.toStringAsFixed(0)} $currency)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedWallet = val),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (amt > 0 && selectedWallet != null) {
                    if (amt > selectedWallet!.balance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('رصيد المحفظة غير كافٍ!')),
                      );
                      return;
                    }
                    context.read<GoalProvider>().depositToGoal(
                          goalId: goal.id,
                          amount: amt,
                          finance: finance,
                          fromWalletId: selectedWallet!.id,
                        );
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إيداع المبلغ في هدف التوفير بنجاح 🎉')),
                    );
                  }
                },
                child: const Text('تأكيد الإيداع'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditGoal(BuildContext context, GoalModel goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddGoalDialog(goalToEdit: goal),
    );
  }

  void _showWithdrawDialog(BuildContext context, GoalModel goal, String currency) {
    if (goal.savedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رصيد مدخر في هذا الهدف للسحب منه')),
      );
      return;
    }

    final amountController = TextEditingController();
    final finance = context.read<FinanceProvider>();
    final rawWallets = finance.wallets;
    final wallets = <WalletModel>[];
    final seen = <String>{};
    for (final w in rawWallets) {
      if (seen.add(w.id)) {
        wallets.add(w);
      }
    }
    WalletModel? selectedWallet = wallets.isNotEmpty ? wallets.first : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final effectiveWallet = (wallets.contains(selectedWallet))
              ? selectedWallet
              : (wallets.isNotEmpty ? wallets.first : null);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.outbox_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('سحب من ${goal.title}', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الرصيد المتوفر في الهدف: ${CurrencyFormatter.format(goal.savedAmount, symbol: currency)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المراد سحبه',
                    suffixText: currency,
                    prefixIcon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('تحويل إلى محفظة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<WalletModel>(
                  initialValue: effectiveWallet,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w,
                      child: Text(
                        '${w.name} (${w.balance.toStringAsFixed(0)} $currency)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedWallet = val),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (amt <= 0) return;
                  if (amt > goal.savedAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('المبلغ المطلوب أكبر من الرصيد المتوفر في الهدف!')),
                    );
                    return;
                  }
                  if (selectedWallet == null) return;

                  final success = await context.read<GoalProvider>().withdrawFromGoal(
                        goalId: goal.id,
                        amount: amt,
                        finance: finance,
                        toWalletId: selectedWallet!.id,
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم سحب ${CurrencyFormatter.format(amt, symbol: currency)} وتحويلها إلى ${selectedWallet!.name} بنجاح ✅',
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: const Text('تأكيد السحب', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String goalId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الهدف؟'),
        content: Text('هل أنت متأكد من رغبتك في حذف "$title"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              context.read<GoalProvider>().deleteGoal(goalId);
              Navigator.of(ctx).pop();
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final goalProv = context.watch<GoalProvider>();
    final goals = goalProv.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('أهداف الادخار وصناديق التوفير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            onPressed: () => _showAddGoal(context),
            tooltip: 'إضافة هدف',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Total Savings Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.35),
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
                    const Text('إجمالي المدخرات في الأهداف', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${goals.length} أهداف نشطة',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(goalProv.totalSavedInGoals, symbol: currency),
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'المستهدف الكلي: ${CurrencyFormatter.format(goalProv.totalTargetGoals, symbol: currency)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'أهدافك الحالية (${goals.length})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (goals.isEmpty)
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
                    const Icon(Icons.savings_outlined, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('لا توجد أهداف ادخار حالياً', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => _showAddGoal(context),
                      child: const Text('أنشئ أول هدف ادخار'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...goals.map((g) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: g.isAchieved ? AppColors.success.withValues(alpha: 0.4) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: g.isAchieved ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: g.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(g.icon, color: g.color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(g.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  if (g.isAchieved) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                                  ],
                                ],
                              ),
                              if (g.targetDate != null)
                                Text(
                                  'المستهدف: ${DateHelper.formatShort(g.targetDate!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'تعديل الهدف',
                          onPressed: () => _showEditGoal(context, g),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          tooltip: 'حذف الهدف',
                          onPressed: () => _confirmDelete(context, g.id, g.title),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: g.progress,
                        minHeight: 10,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(g.isAchieved ? AppColors.success : g.color),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تم جمع: ${CurrencyFormatter.format(g.savedAmount, symbol: currency)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: g.color),
                        ),
                        Text(
                          '${(g.progress * 100).toInt()}% من ${CurrencyFormatter.format(g.targetAmount, symbol: currency)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Action Buttons (Deposit & Withdraw)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showDepositDialog(context, g, currency),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: g.color),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: Icon(Icons.add_rounded, size: 18, color: g.color),
                            label: Text('إيداع', style: TextStyle(color: g.color, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: g.savedAmount > 0 ? () => _showWithdrawDialog(context, g, currency) : null,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: g.savedAmount > 0 ? AppColors.warning : Colors.grey.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: Icon(Icons.outbox_rounded, size: 18, color: g.savedAmount > 0 ? AppColors.warning : Colors.grey),
                            label: Text(
                              'سحب',
                              style: TextStyle(
                                color: g.savedAmount > 0 ? AppColors.warning : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_goals',
        onPressed: () => _showAddGoal(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('هدف ادخار جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
