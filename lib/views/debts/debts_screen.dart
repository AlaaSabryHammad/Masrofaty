import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../providers/contact_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/theme_provider.dart';
import '../contacts/contacts_screen.dart';
import '../contacts/contact_statement_screen.dart';
import 'add_debt_dialog.dart';
import 'debt_detail_sheet.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  void _showAddDebt(BuildContext context, {bool isLent = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddDebtDialog(initialIsLent: isLent),
    );
  }

  void _showDebtDetails(BuildContext context, String debtId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DebtDetailSheet(debtId: debtId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final debtProv = context.watch<DebtProvider>();
    final debts = debtProv.filteredDebts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المديونات والسلف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_rounded),
            tooltip: 'جهات التعامل وكشوف الحساب',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _showAddDebt(context, isLent: debtProv.filterType != DebtFilterType.borrowed),
            tooltip: 'إضافة سلفة أو دين',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Summary Cards (Lent vs Borrowed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Lent (أموال لي)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.debtLent.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.debtLent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('أموال لي (سلف)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.debtLent.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call_made_rounded, color: AppColors.debtLent, size: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          CurrencyFormatter.format(debtProv.totalLentRemaining, symbol: currency),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.debtLent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'من أصل ${CurrencyFormatter.format(debtProv.totalLent, symbol: currency)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Borrowed (أموال علي)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.debtBorrowed.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.debtBorrowed.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('أموال علي (ديون)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.debtBorrowed.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call_received_rounded, color: AppColors.debtBorrowed, size: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          CurrencyFormatter.format(debtProv.totalBorrowedRemaining, symbol: currency),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.debtBorrowed,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'من أصل ${CurrencyFormatter.format(debtProv.totalBorrowed, symbol: currency)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Segmented Tabs: الكل / أموال لي / أموال علي
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTab(context, 'الكل', DebtFilterType.all, debtProv),
                  _buildTab(context, 'أموال لي', DebtFilterType.lent, debtProv),
                  _buildTab(context, 'أموال علي', DebtFilterType.borrowed, debtProv),
                ],
              ),
            ),
          ),

          // Status Filter Chips (نشط / متأخر / مكتمل)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip('الجميع', DebtFilterStatus.all, debtProv),
                  const SizedBox(width: 8),
                  _buildStatusChip('النشطة (${debtProv.activeDebtsCount})', DebtFilterStatus.active, debtProv),
                  const SizedBox(width: 8),
                  _buildStatusChip('المتأخرة (${debtProv.overdueCount})', DebtFilterStatus.overdue, debtProv,
                      highlight: debtProv.overdueCount > 0),
                  const SizedBox(width: 8),
                  _buildStatusChip('المسددة (${debtProv.settledDebtsCount})', DebtFilterStatus.settled, debtProv),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Debts List
          Expanded(
            child: debts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 64,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text('لا توجد مديونات أو سلف في هذه الفئة', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddDebt(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إضافة سلفة أو دين جديد'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: debts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final debt = debts[index];
                      final isLent = debt.isLent;
                      final baseColor = isLent ? AppColors.debtLent : AppColors.debtBorrowed;

                      return InkWell(
                        onTap: () => _showDebtDetails(context, debt.id),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: debt.isOverdue
                                  ? AppColors.danger.withValues(alpha: 0.5)
                                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              width: debt.isOverdue ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Category Avatar
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: baseColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isLent ? Icons.call_made_rounded : Icons.call_received_rounded,
                                      color: baseColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                debt.personName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () {
                                                final contact = context.read<ContactProvider>().getOrCreateContact(
                                                      debt.personName,
                                                      phone: debt.phone,
                                                    );
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => ContactStatementScreen(contact: contact),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.receipt_long_rounded, size: 12, color: AppColors.primaryEmerald),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      'كشف حساب',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.primaryEmerald,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isLent ? 'سلفة لك في ذمته' : 'دين عليك لصالحه',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(debt.remainingAmount, symbol: currency),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: debt.isSettled ? AppColors.success : baseColor,
                                        ),
                                      ),
                                      Text(
                                        'إجمالي: ${CurrencyFormatter.format(debt.totalAmount, symbol: currency)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: debt.progress,
                                  minHeight: 6,
                                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    debt.isSettled ? AppColors.success : baseColor,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Footer Row (Due Date & Status badge)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_rounded,
                                        size: 14,
                                        color: debt.isOverdue ? AppColors.danger : (isDark ? Colors.white60 : Colors.black54),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateHelper.getRelativeDueStatus(debt.dueDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: debt.isOverdue ? FontWeight.bold : FontWeight.normal,
                                          color: debt.isOverdue ? AppColors.danger : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: debt.isSettled
                                          ? AppColors.success.withValues(alpha: 0.15)
                                          : (debt.isOverdue
                                              ? AppColors.danger.withValues(alpha: 0.15)
                                              : baseColor.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      debt.isSettled
                                          ? 'تم السداد بالكامل'
                                          : (debt.isOverdue
                                              ? 'متأخر'
                                              : 'مسدد ${(debt.progress * 100).toInt()}%'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: debt.isSettled
                                            ? AppColors.success
                                            : (debt.isOverdue ? AppColors.danger : baseColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_debts',
        onPressed: () => _showAddDebt(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('إضافة سلفة / دين', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTab(BuildContext context, String title, DebtFilterType type, DebtProvider prov) {
    final isSelected = prov.filterType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => prov.setFilterType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.darkCardElevated : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
              color: isSelected ? AppColors.primary : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String title, DebtFilterStatus status, DebtProvider prov, {bool highlight = false}) {
    final isSelected = prov.filterStatus == status;
    return ChoiceChip(
      selected: isSelected,
      label: Text(title),
      selectedColor: highlight ? AppColors.danger.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
      onSelected: (_) => prov.setFilterStatus(status),
    );
  }
}
