import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../auth/login_screen.dart';
import '../../providers/workspace_provider.dart';
import '../dashboard/widgets/workspace_switcher_sheet.dart';
import '../settings/widgets/saas_plans_sheet.dart';
import '../widgets/user_avatar_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context) {
    final profileProv = context.read<UserProfileProvider>();
    final profile = profileProv.profile;

    final nameController = TextEditingController(text: profile.name);
    final titleController = TextEditingController(text: profile.title);
    final emailController = TextEditingController(text: profile.email);
    final phoneController = TextEditingController(text: profile.phone);
    final budgetController = TextEditingController(text: profile.monthlyBudget.toStringAsFixed(0));
    final bioController = TextEditingController(text: profile.bio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                'تعديل الملف الشخصي',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'المهنة أو التخصص الوظيفي',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الميزانية الشهرية المستهدفة (ر.س)',
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'شعارك المالي / نبذة شخصية',
                  prefixIcon: Icon(Icons.format_quote_rounded),
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
                  final parsedBudget = double.tryParse(budgetController.text) ?? profile.monthlyBudget;
                  await profileProv.updateProfile(
                    name: nameController.text.trim(),
                    title: titleController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    monthlyBudget: parsedBudget,
                    bio: bioController.text.trim(),
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث بيانات الملف الشخصي بنجاح ✨'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
                child: const Text(
                  'حفظ التعديلات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProv = context.watch<ThemeProvider>();
    final currency = themeProv.currencySymbol;
    final profile = context.watch<UserProfileProvider>().profile;
    final finance = context.watch<FinanceProvider>();
    final debts = context.watch<DebtProvider>();
    final goals = context.watch<GoalProvider>().goals;
    final auth = context.watch<AuthProvider>();

    final monthlySpent = finance.monthlyExpense;
    final budgetLimit = profile.monthlyBudget;
    final budgetProgress = budgetLimit > 0 ? (monthlySpent / budgetLimit).clamp(0.0, 1.0) : 0.0;
    final budgetRemaining = (budgetLimit - monthlySpent).clamp(0.0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'تعديل الملف الشخصي',
            onPressed: () => _showEditProfileDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Hero Profile Card
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF34D399), Color(0xFFF59E0B)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: UserAvatarWidget(
                          avatarPath: profile.avatarPath,
                          size: 104,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showEditProfileDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2.5,
                          ),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  profile.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            profile.tier,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildAuthBadge(context, auth),
                  ],
                ),
                if (auth.isGuest) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'حساب تجريبي (ضيف). يمكنك ترقية حسابك لحفظ بياناتك سحابياً.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('ترقية الحساب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Bio / Financial Motto
          if (profile.bio.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      profile.bio,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Monthly Budget Progress Section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'الميزانية الشهرية المقررة',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.format(budgetLimit, symbol: currency),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: budgetProgress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      budgetProgress > 0.9
                          ? AppColors.danger
                          : (budgetProgress > 0.75 ? AppColors.warning : AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المصروف: ${CurrencyFormatter.format(monthlySpent, symbol: currency)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      'المتبقي: ${CurrencyFormatter.format(budgetRemaining, symbol: currency)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Financial Achievements / Stats Badges
          const Text(
            'أوسمة وإحصائيات الحساب',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatBadge(
                  context: context,
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                  title: 'المحافظ النشطة',
                  value: '${finance.wallets.length} محافظ',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBadge(
                  context: context,
                  icon: Icons.flag_circle_rounded,
                  color: const Color(0xFF3B82F6),
                  title: 'صناديق التوفير',
                  value: '${goals.length} أهداف',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatBadge(
                  context: context,
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFF8B5CF6),
                  title: 'سجل العمليات',
                  value: '${finance.transactions.length} عملية',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatBadge(
                  context: context,
                  icon: Icons.handshake_rounded,
                  color: const Color(0xFFF59E0B),
                  title: 'سجلات الديون',
                  value: '${debts.debts.length} سلفة/دين',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // User Info List Card
          Material(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.6),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.work_outline_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'المهنة / التخصص',
                  subtitle: profile.title.isNotEmpty ? profile.title : 'غير محدد',
                ),
                const Divider(height: 1, indent: 56),
                _buildInfoTile(
                  icon: Icons.email_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'البريد الإلكتروني',
                  subtitle: profile.email,
                ),
                const Divider(height: 1, indent: 56),
                _buildInfoTile(
                  icon: Icons.phone_android_rounded,
                  iconColor: AppColors.primary,
                  title: 'رقم الجوال',
                  subtitle: profile.phone,
                ),
                const Divider(height: 1, indent: 56),
                _buildInfoTile(
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'عضو منذ',
                  subtitle: DateHelper.formatDate(profile.joinDate),
                ),
                const Divider(height: 1, indent: 56),
                _buildInfoTile(
                  icon: Icons.attach_money_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'العملة المعتمدة',
                  subtitle: currency,
                ),
                const Divider(height: 1, indent: 56),
                _buildInfoTile(
                  icon: Icons.verified_user_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'نوع الحساب والتوثيق',
                  subtitle: auth.isGuest
                      ? 'وضع الضيف (محلي)'
                      : (auth.currentUser?.authMethod == 'google'
                          ? 'حساب Google'
                          : (auth.currentUser?.authMethod == 'phone'
                              ? 'رقم الجوال (SMS OTP)'
                              : 'البريد الإلكتروني وكلمة المرور')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Multi-Tenant SaaS Workspace & Subscription Card
          Consumer<WorkspaceProvider>(
            builder: (context, workspaceProv, _) {
              final activeWs = workspaceProv.activeWorkspace;
              final plan = workspaceProv.currentPlan;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: activeWs.color.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: activeWs.color.withAlpha(80)),
                          ),
                          child: Icon(activeWs.icon, color: activeWs.color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مساحة العمل: ${activeWs.name}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                '${activeWs.type.labelArabic} • ${workspaceProv.workspaces.length} مساحات عمل مفعلة',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => WorkspaceSwitcherSheet.show(context),
                          child: const Text('تبديل'),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: plan.tier.color.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(plan.tier.icon, color: plan.tier.color, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.tier.titleArabic,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'الحد: ${workspaceProv.maxWorkspaces} مساحات عمل',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => SaaSPlansSheet.show(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: plan.tier.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('ترقية الباقة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Logout Button
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text(
              'تسجيل الخروج من الحساب',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildAuthBadge(BuildContext context, AuthProvider auth) {
    final user = auth.currentUser;
    String label = 'حساب محلي';
    IconData icon = Icons.lock_outline_rounded;
    Color color = AppColors.primary;

    if (user != null) {
      if (user.isGuest) {
        label = 'وضع الضيف';
        icon = Icons.person_outline_rounded;
        color = const Color(0xFF64748B);
      } else {
        switch (user.authMethod) {
          case 'google':
            label = 'Google';
            icon = Icons.g_mobiledata_rounded;
            color = const Color(0xFF4285F4);
            break;
          case 'phone':
            label = 'رقم الجوال';
            icon = Icons.phone_android_rounded;
            color = const Color(0xFF0284C7);
            break;
          case 'email':
          default:
            label = 'البريد الإلكتروني';
            icon = Icons.email_rounded;
            color = AppColors.primary;
            break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('تسجيل الخروج'),
          ],
        ),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟ يمكنك تسجيل الدخول مجدداً في أي وقت.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AppGate()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
