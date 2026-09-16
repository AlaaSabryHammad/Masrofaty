import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/finance_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../contacts/contacts_screen.dart';

class WealthDistributionCard extends StatelessWidget {
  final VoidCallback? onScanSmsTap;
  final VoidCallback? onTransferTap;
  final VoidCallback? onAddLendTap;

  const WealthDistributionCard({
    super.key,
    this.onScanSmsTap,
    this.onTransferTap,
    this.onAddLendTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final isDark = themeProv.isDarkMode;
    final hideBalance = themeProv.hideBalance;
    final currency = themeProv.currencySymbol;

    final finance = context.watch<FinanceProvider>();
    final debtProv = context.watch<DebtProvider>();

    final bankBalance = finance.totalBankBalance;
    final cashBalance = finance.totalCashBalance;
    final savingsBalance = finance.totalSavingsBalance;
    final lentToFriends = debtProv.totalLentRemaining;
    final debtsOwed = debtProv.totalBorrowedRemaining;

    // Total positive assets (Bank + Cash + Savings + Money loaned to friends)
    final totalAssets = bankBalance + cashBalance + savingsBalance + lentToFriends;
    // Net Worth = Assets - Liabilities
    final netWorth = totalAssets - debtsOwed;

    // Percentage calculations
    final bankShare = totalAssets > 0 ? (bankBalance / totalAssets) : 0.0;
    final cashShare = totalAssets > 0 ? (cashBalance / totalAssets) : 0.0;
    final lentShare = totalAssets > 0 ? (lentToFriends / totalAssets) : 0.0;
    final savingsShare = totalAssets > 0 ? (savingsBalance / totalAssets) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Net Worth & Privacy Eye
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF0F2027),
                        const Color(0xFF203A43),
                        const Color(0xFF2C5364),
                      ]
                    : [
                        const Color(0xFF064E3B),
                        const Color(0xFF047857),
                        const Color(0xFF059669),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pie_chart_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'صافي الثروة الشامل',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        hideBalance
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => themeProv.toggleHideBalance(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  CurrencyFormatter.format(netWorth, symbol: currency, hide: hideBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أصولك السائلة + سلف أصدقائك (${CurrencyFormatter.format(totalAssets, symbol: currency, hide: hideBalance)})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 16),

                // Multi-Segment Visual Asset Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 10,
                    color: Colors.white.withValues(alpha: 0.15),
                    child: totalAssets <= 0
                        ? Container(color: Colors.white24)
                        : Row(
                            children: [
                              if (bankShare > 0)
                                Flexible(
                                  flex: (bankShare * 1000).toInt(),
                                  child: Container(color: const Color(0xFF38BDF8)),
                                ),
                              if (cashShare > 0)
                                Flexible(
                                  flex: (cashShare * 1000).toInt(),
                                  child: Container(color: const Color(0xFF10B981)),
                                ),
                              if (lentShare > 0)
                                Flexible(
                                  flex: (lentShare * 1000).toInt(),
                                  child: Container(color: const Color(0xFFF59E0B)),
                                ),
                              if (savingsShare > 0)
                                Flexible(
                                  flex: (savingsShare * 1000).toInt(),
                                  child: Container(color: const Color(0xFFA855F7)),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          // 4-Block Breakdown Grid: Bank, Cash, Friends Loans, Debts Owed
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // 1. Bank Accounts
                    Expanded(
                      child: _buildAssetTile(
                        context,
                        title: 'حسابات بنكية',
                        amount: bankBalance,
                        subtitle: '${(bankShare * 100).toStringAsFixed(0)}% من أموالك',
                        icon: Icons.account_balance_rounded,
                        accentColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        currency: currency,
                        hide: hideBalance,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 2. Cash
                    Expanded(
                      child: _buildAssetTile(
                        context,
                        title: 'فلوس نقدي (كاش)',
                        amount: cashBalance,
                        subtitle: '${(cashShare * 100).toStringAsFixed(0)}% من أموالك',
                        icon: Icons.payments_rounded,
                        accentColor: const Color(0xFF10B981),
                        bgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                        currency: currency,
                        hide: hideBalance,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // 3. Loans to Friends
                    Expanded(
                      child: _buildAssetTile(
                        context,
                        title: 'سلف عند أصدقائي',
                        amount: lentToFriends,
                        subtitle: 'أموال لك لدى الغير',
                        icon: Icons.people_alt_rounded,
                        accentColor: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        currency: currency,
                        hide: hideBalance,
                        isDark: isDark,
                        badge: 'لك',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ContactsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 4. Debts Owed (Liabilities)
                    Expanded(
                      child: _buildAssetTile(
                        context,
                        title: 'ديون والتزامات',
                        amount: debtsOwed,
                        subtitle: 'مطلوبات للغير',
                        icon: Icons.assignment_late_rounded,
                        accentColor: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        currency: currency,
                        hide: hideBalance,
                        isDark: isDark,
                        badge: 'عليك',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quick Action Strip
                Row(
                  children: [
                    if (onScanSmsTap != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onScanSmsTap,
                          icon: const Icon(Icons.sms_rounded, size: 16),
                          label: const Text(
                            'فحص رسائل البنوك',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (onScanSmsTap != null && (onAddLendTap != null || onTransferTap != null))
                      const SizedBox(width: 8),
                    if (onAddLendTap != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onAddLendTap,
                          icon: const Icon(Icons.handshake_rounded, size: 16),
                          label: const Text(
                            'إقراض صديق',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildAssetTile(
    BuildContext context, {
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required String currency,
    required bool hide,
    required bool isDark,
    String? badge,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(amount, symbol: currency, hide: hide),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    return content;
  }
}
