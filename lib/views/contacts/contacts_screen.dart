import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/theme_provider.dart';
import 'contact_statement_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final debts = context.read<DebtProvider>().debts;
      context.read<ContactProvider>().syncFromDebts(debts);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String rel = 'friend';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'إضافة جهة تعامل جديدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل أو اسم الجهة',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال (اختياري)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: rel,
                  decoration: const InputDecoration(
                    labelText: 'طبيعة العلاقة',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'friend', child: Text('صديق')),
                    DropdownMenuItem(value: 'family', child: Text('عائلة / قريب')),
                    DropdownMenuItem(value: 'work', child: Text('زميل عمل')),
                    DropdownMenuItem(value: 'client', child: Text('عميل')),
                    DropdownMenuItem(value: 'merchant', child: Text('متجر / مورد')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => rel = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (رقم حساب، آيبان، إلخ)',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    await context.read<ContactProvider>().addContact(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          relationship: rel,
                          notes: notesCtrl.text.trim(),
                        );
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تسجيل جهة التعامل بنجاح ✨'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'حفظ جهة التعامل',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<ThemeProvider>().currencySymbol;
    final contactProv = context.watch<ContactProvider>();
    final debtProv = context.watch<DebtProvider>();
    final contacts = contactProv.filteredContacts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل جهات التعامل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'إضافة شخص جديد',
            onPressed: () => _showAddContactDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => contactProv.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الجوال...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          contactProv.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.grey.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips (All, Friends, Family, Work, Clients)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('all', 'الكل (${contactProv.contacts.length})', contactProv),
                _buildFilterChip('friend', 'أصدقاء', contactProv),
                _buildFilterChip('family', 'عائلة', contactProv),
                _buildFilterChip('work', 'عمل', contactProv),
                _buildFilterChip('client', 'عملاء', contactProv),
                _buildFilterChip('merchant', 'موردين', contactProv),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Contacts List
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: Colors.grey.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          contactProv.searchQuery.isEmpty
                              ? 'لم تقم بتسجيل أي جهات تعامل بعد'
                              : 'لا توجد نتائج مطابقة للبحث',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سجّل أسماء الأشخاص الذين تتعامل معهم دورياً لتسهيل إدارة حساباتهم وكشوفاتهم',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () => _showAddContactDialog(context),
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          label: const Text('إضافة جهة تعامل جديدة', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: contacts.length,
                    itemBuilder: (ctx, index) {
                      final contact = contacts[index];
                      return _buildContactCard(context, contact, debtProv, currency, isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_contacts',
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddContactDialog(context),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('إضافة شخص', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, ContactProvider prov) {
    final isSelected = prov.selectedRelationship == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isSelected ? AppColors.primary : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => prov.setSelectedRelationship(value),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    ContactModel contact,
    DebtProvider debtProv,
    String currency,
    bool isDark,
  ) {
    // Compute net balance with this contact
    final personDebts = debtProv.debts.where((d) {
      final matchesName = d.personName.trim().toLowerCase() == contact.name.trim().toLowerCase();
      final matchesPhone = contact.phone != null &&
          contact.phone!.isNotEmpty &&
          d.phone != null &&
          d.phone == contact.phone;
      return matchesName || matchesPhone;
    }).toList();

    double totalLentRemaining = 0.0;
    double totalBorrowedRemaining = 0.0;
    for (final d in personDebts) {
      if (d.isLent) {
        totalLentRemaining += d.remainingAmount;
      } else {
        totalBorrowedRemaining += d.remainingAmount;
      }
    }
    final netDue = totalLentRemaining - totalBorrowedRemaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ContactStatementScreen(contact: contact),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    contact.name.isNotEmpty ? contact.name.characters.first : '؟',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              contact.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              contact.relationshipLabel,
                              style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (contact.phone != null && contact.phone!.isNotEmpty) ...[
                            Icon(Icons.phone_rounded, size: 11, color: Colors.grey.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                contact.phone!,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '${personDebts.length} عمليات',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (personDebts.isEmpty)
                      const Text('لا معاملات', style: TextStyle(fontSize: 11, color: Colors.grey))
                    else if (netDue > 0) ...[
                      Text(
                        'أطلبه: ${CurrencyFormatter.format(netDue, symbol: currency)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                      ),
                      const Text('سلفة قائمة', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                    ] else if (netDue < 0) ...[
                      Text(
                        'يطلبني: ${CurrencyFormatter.format(netDue.abs(), symbol: currency)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.danger),
                      ),
                      const Text('دين مستحق', style: TextStyle(fontSize: 10, color: AppColors.danger)),
                    ] else ...[
                      const Text(
                        'خالص 0.00',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF3B82F6)),
                      ),
                      const Text('مسوى بالكامل', style: TextStyle(fontSize: 10, color: Color(0xFF3B82F6))),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
