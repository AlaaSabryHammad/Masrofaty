import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/wallet_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/theme_provider.dart';

class TransferDialog extends StatefulWidget {
  const TransferDialog({super.key});

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  WalletModel? _fromWallet;
  WalletModel? _toWallet;

  @override
  void initState() {
    super.initState();
    final finance = context.read<FinanceProvider>();
    if (finance.wallets.length >= 2) {
      _fromWallet = finance.wallets[0];
      _toWallet = finance.wallets[1];
    } else if (finance.wallets.isNotEmpty) {
      _fromWallet = finance.wallets[0];
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_fromWallet == null || _toWallet == null) return;
    if (_fromWallet!.id == _toWallet!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التحويل لنفس المحفظة!')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
      );
      return;
    }

    if (amount > _fromWallet!.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رصيد المحفظة المحول منها غير كافٍ!')),
      );
      return;
    }

    context.read<FinanceProvider>().transferBetweenWallets(
          fromWalletId: _fromWallet!.id,
          toWalletId: _toWallet!.id,
          amount: amount,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم التحويل المالي بين الحسابين بنجاح'),
        backgroundColor: AppColors.transfer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final wallets = context.watch<FinanceProvider>().wallets;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        children: [
          // Handle
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.transfer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sync_alt_rounded, color: AppColors.transfer),
                    ),
                    const SizedBox(width: 12),
                    const Text('تحويل بين الحسابات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Amount
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.transfer.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.transfer.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        currency,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.transfer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            filled: false,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // From Wallet
                const Text('تحويل من حساب:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<WalletModel>(
                  initialValue: _fromWallet,
                  isExpanded: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.arrow_upward_rounded)),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(w.icon, color: w.color, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${w.name} (${w.balance.toStringAsFixed(0)} $currency)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _fromWallet = val),
                ),

                const SizedBox(height: 16),

                // Arrow icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.transfer.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, color: AppColors.transfer),
                  ),
                ),

                const SizedBox(height: 16),

                // To Wallet
                const Text('إلى حساب:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<WalletModel>(
                  initialValue: _toWallet,
                  isExpanded: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.arrow_downward_rounded)),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(w.icon, color: w.color, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${w.name} (${w.balance.toStringAsFixed(0)} $currency)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _toWallet = val),
                ),

                const SizedBox(height: 20),

                // Notes
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    hintText: 'سحب من الصراف، إيداع نقدي...',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.transfer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('تأكيد التحويل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
