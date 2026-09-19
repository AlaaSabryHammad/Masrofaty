import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/workspace_model.dart';
import '../../../providers/workspace_provider.dart';

class CreateWorkspaceDialog extends StatefulWidget {
  const CreateWorkspaceDialog({super.key});

  @override
  State<CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends State<CreateWorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taxNumberController = TextEditingController();

  WorkspaceType _selectedType = WorkspaceType.business;
  String _selectedCurrency = 'SAR';
  String _selectedCurrencySymbol = 'ر.س';
  bool _isSubmitting = false;

  List<Map<String, String>> get _currencies => AppConstants.currencies.map((c) => {
    'code': c['code']!,
    'symbol': c['symbol']!,
    'label': '${c['flag']} ${c['name']}',
  }).toList();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _taxNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final workspaceProvider = context.read<WorkspaceProvider>();

    try {
      final newWs = await workspaceProvider.createWorkspace(
        name: _nameController.text,
        type: _selectedType,
        currency: _selectedCurrency,
        currencySymbol: _selectedCurrencySymbol,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        taxNumber: _taxNumberController.text.isEmpty ? null : _taxNumberController.text,
        iconCode: _selectedType.icon.codePoint,
        colorValue: _selectedType.defaultColor.toARGB32(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (newWs != null) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إنشاء مساحة العمل "${newWs.name}" بنجاح!'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('وصلت للحد الأقصى لمساحات العمل في باقتك الحالية'),
              backgroundColor: AppColors.expense,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_business_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إضافة مساحة عمل / حساب جديد',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'فصل كامل للمحافظ والمصاريف والتقارير',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Workspace Name
              Text(
                'اسم الحساب / النشاط',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'مثال: شركة البركة، متجر الأناقة، فريلانس...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم الحساب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Workspace Type Selection
              Text(
                'نوع الحساب والنشاط',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WorkspaceType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    avatar: Icon(
                      type.icon,
                      size: 18,
                      color: isSelected ? Colors.white : type.defaultColor,
                    ),
                    label: Text(type.labelArabic),
                    selected: isSelected,
                    selectedColor: type.defaultColor,
                    backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? type.defaultColor
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Currency Selector
              Text(
                'العملة الأساسية لهذا الحساب',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCurrency,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.primary),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                items: _currencies.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['code'],
                    child: Text('${c['label']} (${c['symbol']})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final curr = _currencies.firstWhere((c) => c['code'] == val);
                    setState(() {
                      _selectedCurrency = curr['code']!;
                      _selectedCurrencySymbol = curr['symbol']!;
                    });
                  }
                },
              ),
              const SizedBox(height: 18),

              // Business Tax Number (Optional)
              if (_selectedType == WorkspaceType.business || _selectedType == WorkspaceType.store) ...[
                Text(
                  'الرقم الضريبي (اختياري للتقارير)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _taxNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '300xxxxxxxxx0003',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                    prefixIcon: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Smart Wallets Auto-generation Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedType.defaultColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _selectedType.defaultColor.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: _selectedType.defaultColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'سيتم تلقائياً تهيئة محافظ مخصصة لنشاط (${_selectedType.labelArabic}) فور الإنشاء.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'إنشاء مساحة العمل الآن',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
