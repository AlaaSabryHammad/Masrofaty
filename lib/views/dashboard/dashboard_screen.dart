import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../debts/add_debt_dialog.dart';
import '../transactions/add_transaction_dialog.dart';
import '../wallets/transfer_dialog.dart';
import '../widgets/notifications_sheet.dart';
import '../../providers/goal_provider.dart';
import '../ai_advisor/ai_advisor_sheet.dart';
import '../ai_advisor/smart_parser_dialog.dart';
import '../goals/goals_screen.dart';
import '../../providers/contact_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../contacts/contacts_screen.dart';
import '../profile/profile_screen.dart';
import '../../providers/recurring_provider.dart';
import '../recurring/recurring_screen.dart';

import '../../core/services/sms_sync_service.dart';
import '../../providers/workspace_provider.dart';
import 'widgets/wealth_distribution_card.dart';
import 'widgets/sms_sync_dialog.dart';
import 'widgets/workspace_switcher_sheet.dart';
import 'widgets/create_workspace_dialog.dart';
import '../widgets/user_avatar_widget.dart';
import '../settings/widgets/saas_plans_sheet.dart';
import '../settings/widgets/currency_picker_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SmsSyncService _smsSyncService = SmsSyncService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAlerts();
      _smsSyncService.initialize(context.read<FinanceProvider>());
      _checkPendingSms();
    });
  }

  @override
  void dispose() {
    _smsSyncService.dispose();
    super.dispose();
  }

  Future<void> _checkPendingSms() async {
    final finance = context.read<FinanceProvider>();
    final pending = await _smsSyncService.getPendingSms();
    if (pending.isNotEmpty && mounted) {
      for (final tx in pending) {
        await SmsSyncService.applyTransactionToFinance(tx, finance);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل ${pending.length} عملية بنكية تلقائياً من الرسائل الواردة!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSmsSync(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmsSyncDialog(),
    );
  }

  void _checkAlerts() {
    final debts = context.read<DebtProvider>().debts;
    final finance = context.read<FinanceProvider>();
    context.read<NotificationProvider>().checkSystemAlerts(
          debts: debts,
          categories: finance.categories,
          getSpentForCategory: (catId) => finance.getCategoryMonthlySpent(catId),
        );
  }

  void _showAddTx(BuildContext context, bool isExpense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionDialog(initialIsExpense: isExpense),
    );
  }

  void _showAddDebt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddDebtDialog(),
    );
  }

  void _showTransfer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransferDialog(),
    );
  }

  void _openNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  void _openAiAdvisor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiAdvisorSheet(),
    );
  }

  void _openSmartParser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmartParserDialog(),
    );
  }

  void _openGoals(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProv = context.watch<ThemeProvider>();
    final currency = themeProv.currencySymbol;
    final hideBalance = themeProv.hideBalance;

    final finance = context.watch<FinanceProvider>();
    final debts = context.watch<DebtProvider>();
    final notifs = context.watch<NotificationProvider>();
    final goals = context.watch<GoalProvider>().goals;
    final userProfile = context.watch<UserProfileProvider>().profile;

    final recentTransactions = finance.transactions.take(5).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _checkAlerts();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Top Bar (Avatar, Greeting, Notification Bell, Theme Toggle)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                      child: Row(
                        children: [
                          UserAvatarWidget(
                            avatarPath: userProfile.avatarPath,
                            size: 44,
                            showBorder: true,
                            borderColor: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'مرحباً، ${userProfile.name.split(' ').first}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'مصروفاتي',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateHelper.formatDate(DateTime.now()),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // SMS Bank Sync
                      IconButton(
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => _openSmsSync(context),
                        icon: const Icon(Icons.sms_rounded, color: Color(0xFF0284C7), size: 22),
                        tooltip: 'القارئ الذكي لرسائل البنوك',
                      ),
                      // Contacts & Statements
                      IconButton(
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ContactsScreen()),
                          );
                        },
                        icon: const Icon(Icons.people_alt_rounded, color: AppColors.primaryEmerald, size: 22),
                        tooltip: 'جهات التعامل وكشوف الحساب',
                      ),
                      // Currency Quick Picker
                      IconButton(
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => CurrencyPickerSheet.show(context),
                        icon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            themeProv.currencySymbol,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        tooltip: 'تغيير العملة',
                      ),
                      // Quick Theme Toggle
                      IconButton(
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => themeProv.toggleTheme(),
                        icon: Icon(
                          themeProv.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: themeProv.isDarkMode ? Colors.amber : Colors.indigo,
                          size: 22,
                        ),
                        tooltip: 'تبديل المظهر',
                      ),
                      // Notifications Bell
                      Stack(
                        children: [
                          IconButton(
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () => _openNotifications(context),
                            icon: const Icon(Icons.notifications_outlined, size: 23),
                          ),
                          if (notifs.unreadCount > 0)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${notifs.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Multi-Tenant SaaS Workspace Bar
              _buildWorkspaceSelectorBar(context, isDark),

              const SizedBox(height: 14),

              // Wealth & Asset Distribution Command Center
              WealthDistributionCard(
                onScanSmsTap: () => _openSmsSync(context),
                onTransferTap: () => _showTransfer(context),
                onAddLendTap: () => _showAddDebt(context),
              ),

              const SizedBox(height: 14),

              // Monthly Flow Summary (Income vs Expense)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_downward_rounded, color: AppColors.income, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'دخل هذا الشهر',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatCompact(finance.monthlyIncome, symbol: currency, hide: hideBalance),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: AppColors.expense, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مصاريف هذا الشهر',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatCompact(finance.monthlyExpense, symbol: currency, hide: hideBalance),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Quick Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAction(
                    context,
                    title: 'مصروف',
                    icon: Icons.remove_rounded,
                    color: AppColors.expense,
                    onTap: () => _showAddTx(context, true),
                  ),
                  _buildQuickAction(
                    context,
                    title: 'دخل جديد',
                    icon: Icons.add_rounded,
                    color: AppColors.income,
                    onTap: () => _showAddTx(context, false),
                  ),
                  _buildQuickAction(
                    context,
                    title: 'سلفة / دين',
                    icon: Icons.handshake_rounded,
                    color: AppColors.debtBorrowed,
                    onTap: () => _showAddDebt(context),
                  ),
                  _buildQuickAction(
                    context,
                    title: 'تحويل',
                    icon: Icons.sync_alt_rounded,
                    color: AppColors.transfer,
                    onTap: () => _showTransfer(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Smart AI Tools Row (المستشار المالي وقارئ الفواتير)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAiAdvisor(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('المستشار الذكي', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('تحليل الصرف والتوفير', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openSmartParser(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('قارئ الفواتير', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('استخراج من الرسائل', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Savings Goals Snapshot Card
              if (goals.isNotEmpty) ...[
                InkWell(
                  onTap: () => _openGoals(context),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF0F2E28), const Color(0xFF134E48)]
                            : [const Color(0xFFCCFBF1), const Color(0xFFE6FFFA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D9488),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.savings_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'أهداف الادخار وصناديق التوفير',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${goals.length} أهداف', style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'تم جمع ${CurrencyFormatter.format(context.watch<GoalProvider>().totalSavedInGoals, symbol: currency)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Recurring & Subscriptions Snapshot Card
              Consumer<RecurringProvider>(
                builder: (context, recurringProv, _) {
                  final activeRec = recurringProv.activeItems;
                  if (activeRec.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecurringScreen()));
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF2E1065), const Color(0xFF3B0764)]
                                : [const Color(0xFFF3E8FF), const Color(0xFFFAF5FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF9333EA).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF9333EA),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.repeat_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'الاشتراكات والمعاملات المجدولة',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Text('${activeRec.length} مفعلة', style: const TextStyle(fontSize: 11, color: Color(0xFF9333EA), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'التزام شهري: ${CurrencyFormatter.format(recurringProv.totalMonthlyRecurringExpense, symbol: currency)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 4),

              // Debts & Loans Summary Card
              InkWell(
                onTap: () => widget.onNavigateToTab?.call(2), // Debts tab
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: debts.overdueCount > 0
                          ? AppColors.danger.withValues(alpha: 0.4)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.debtBorrowed.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.account_tree_rounded, color: AppColors.debtBorrowed, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'حالة المديونات والسلف',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (debts.overdueCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${debts.overdueCount} متأخر',
                                    style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'أموال لي عند الآخرين',
                                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(debts.totalLentRemaining, symbol: currency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.debtLent),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 32, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'أموال علي (ديون للغير)',
                                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(debts.totalBorrowedRemaining, symbol: currency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.debtBorrowed),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Contacts & Statements Directory Card
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContactsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF064E3B).withValues(alpha: 0.4), const Color(0xFF022C22).withValues(alpha: 0.6)]
                          : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.people_alt_rounded, color: AppColors.primaryEmerald, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'جهات التعامل وكشوف الحساب',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Consumer<ContactProvider>(
                                  builder: (context, cProv, _) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryEmerald,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${cProv.contacts.length} مسجل',
                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'سجل جهاتك الثابتة واعرض كشف حساب تفصيلي ومشاركتها عبر واتساب',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('أحدث المعاملات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  TextButton(
                    onPressed: () => widget.onNavigateToTab?.call(1), // Transactions tab
                    child: const Text('عرض الكل'),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (recentTransactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: const Center(
                    child: Text('لا توجد معاملات مسجلة بعد'),
                  ),
                )
              else
                ...recentTransactions.map((tx) {
                  final cat = finance.getCategoryById(tx.categoryId);
                  final catColor = cat?.color ?? (tx.isExpense ? AppColors.expense : AppColors.income);
                  final catIcon = cat?.icon ?? (tx.isExpense ? Icons.arrow_upward : Icons.arrow_downward);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(catIcon, color: catColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateHelper.formatFriendly(tx.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${tx.isExpense ? '-' : '+'}${CurrencyFormatter.format(tx.amount, symbol: currency)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: tx.isExpense ? AppColors.expense : AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSelectorBar(BuildContext context, bool isDark) {
    final workspaceProv = context.watch<WorkspaceProvider>();
    final activeWs = workspaceProv.activeWorkspace;
    final plan = workspaceProv.currentPlan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activeWs.color.withAlpha(isDark ? 80 : 50),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: activeWs.color.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Active Workspace Chip with Dropdown
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => WorkspaceSwitcherSheet.show(context),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: activeWs.color.withAlpha(35),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: activeWs.color.withAlpha(70)),
                    ),
                    child: Icon(activeWs.icon, color: activeWs.color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                activeWs.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: activeWs.color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Text(
                              activeWs.type.labelArabic,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: activeWs.color,
                              ),
                            ),
                            InkWell(
                              onTap: () => CurrencyPickerSheet.show(context),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                child: Text(
                                  ' • ${activeWs.currencySymbol} ✎',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: activeWs.color,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Plan Badge / Upgrade & Add Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => SaaSPlansSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        plan.tier.color.withAlpha(40),
                        plan.tier.color.withAlpha(20),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: plan.tier.color.withAlpha(70)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(plan.tier.icon, color: plan.tier.color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        plan.tier.titleArabic.split(' ').first,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: plan.tier.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (!workspaceProv.canAddWorkspace) {
                    SaaSPlansSheet.show(context);
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const CreateWorkspaceDialog(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
