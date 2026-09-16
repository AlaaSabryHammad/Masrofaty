import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';
import 'add_transaction_dialog.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  void _showAddTransaction(BuildContext context, {bool isExpense = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionDialog(initialIsExpense: isExpense),
    );
  }

  void _showEditTransaction(BuildContext context, dynamic tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionDialog(transactionToEdit: tx),
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المعاملة؟'),
        content: Text('هل أنت متأكد من رغبتك في حذف "$title"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              context.read<FinanceProvider>().deleteTransaction(id);
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
    final finance = context.watch<FinanceProvider>();
    final transactions = finance.filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المعاملات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _showAddTransaction(context),
            tooltip: 'إضافة معاملة',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => finance.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'ابحث في المصاريف والإيرادات...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: finance.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => finance.setSearchQuery(''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Period Filter Chips (اليوم / الأسبوع / الشهر / الكل)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip('هذا الشهر', TimeFilter.month, finance),
                  const SizedBox(width: 8),
                  _buildPeriodChip('اليوم', TimeFilter.today, finance),
                  const SizedBox(width: 8),
                  _buildPeriodChip('هذا الأسبوع', TimeFilter.week, finance),
                  const SizedBox(width: 8),
                  _buildPeriodChip('جميع الأوقات', TimeFilter.all, finance),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Transactions List
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 64,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text('لا توجد معاملات مسجلة في هذه الفترة', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddTransaction(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('تسجيل معاملة جديدة'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      final cat = finance.getCategoryById(tx.categoryId);
                      final wallet = finance.getWalletById(tx.walletId);
                      final isExpense = tx.isExpense;

                      final catColor = cat?.color ?? (isExpense ? AppColors.expense : AppColors.income);
                      final catIcon = cat?.icon ?? (isExpense ? Icons.arrow_upward : Icons.arrow_downward);

                      return InkWell(
                        onTap: () => _showEditTransaction(context, tx),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Row(
                            children: [
                              // Category Icon in Colorful Circle
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(catIcon, color: catColor, size: 22),
                              ),
                              const SizedBox(width: 14),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (wallet != null) ...[
                                          Icon(wallet.icon, size: 13, color: isDark ? Colors.white60 : Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(
                                            wallet.name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('•', style: TextStyle(color: isDark ? Colors.white30 : Colors.black26)),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          DateHelper.formatFriendly(tx.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        tx.notes!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Amount & Actions
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isExpense ? '-' : '+'}${CurrencyFormatter.format(tx.amount, symbol: currency)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isExpense ? AppColors.expense : AppColors.income,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        onPressed: () => _showEditTransaction(context, tx),
                                        tooltip: 'تعديل المعاملة',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        onPressed: () => _confirmDelete(context, tx.id, tx.title),
                                        tooltip: 'حذف المعاملة',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransaction(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildPeriodChip(String label, TimeFilter filter, FinanceProvider prov) {
    final isSelected = prov.currentTimeFilter == filter;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => prov.setTimeFilter(filter),
    );
  }
}
