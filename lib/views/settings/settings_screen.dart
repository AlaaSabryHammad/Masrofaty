import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/firebase_sync_service.dart';
import '../../core/services/security_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../auth/login_screen.dart';
import '../dashboard/widgets/sms_sync_dialog.dart';
import '../goals/goals_screen.dart';
import '../profile/profile_screen.dart';
import '../security/pin_lock_screen.dart';
import 'package:flutter/services.dart';
import '../../providers/recurring_provider.dart';
import '../categories/categories_screen.dart';
import '../recurring/recurring_screen.dart';
import '../budgets/budgets_screen.dart';
import '../../providers/workspace_provider.dart';
import '../dashboard/widgets/workspace_switcher_sheet.dart';
import 'widgets/saas_plans_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SecurityService? _securityService;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSecurity();
  }

  Future<void> _initSecurity() async {
    final storage = context.read<StorageService>();
    final sec = SecurityService(storage.prefs);
    setState(() {
      _securityService = sec;
      _pinEnabled = sec.isPinEnabled;
    });
  }

  void _showCurrencyPicker(BuildContext context) {
    final themeProv = context.read<ThemeProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: 380,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('اختر العملة الافتراضية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: AppConstants.currencies.length,
                  itemBuilder: (context, index) {
                    final curr = AppConstants.currencies[index];
                    final isSel = themeProv.currencySymbol == curr['symbol'];

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          curr['symbol']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      title: Text(curr['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(curr['code']!),
                      trailing: isSel ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                      onTap: () {
                        themeProv.setCurrency(curr['symbol']!);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _togglePin(bool value) {
    if (_securityService == null) return;

    if (value) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PinLockScreen(
            securityService: _securityService!,
            isSettingPin: true,
            onUnlocked: () {
              setState(() => _pinEnabled = true);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تفعيل رمز الأمان بنجاح 🔒')),
              );
            },
          ),
        ),
      );
    } else {
      _securityService!.disablePin();
      setState(() => _pinEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعطيل رمز الأمان')),
      );
    }
  }

  void _exportCsv() {
    final finance = context.read<FinanceProvider>();
    final currency = context.read<ThemeProvider>().currencySymbol;
    final csv = BackupService.exportTransactionsToCsv(finance, currency);

    BackupService.copyBackupToClipboard(csv);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ تقرير المعاملات (Excel CSV) إلى الحافظة بنجاح')),
    );
  }

  void _exportBackup() {
    final storage = context.read<StorageService>();
    final json = BackupService.exportAllDataToJson(storage);

    BackupService.copyBackupToClipboard(json);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ النسخة الاحتياطية الكاملة (JSON) إلى الحافظة بنجاح')),
    );
  }

  void _showImportBackupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore_page_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('استيراد نسخة احتياطية (JSON)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الصق نص النسخة الاحتياطية (JSON) هنا لاستعادة كافة البيانات (المعاملات، التصنيفات، المحافظ، الديون، وأهداف الادخار):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: '{\n  "version": "1.1.0",\n  "transactions": [...]\n}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final clipboardData = await Clipboard.getData('text/plain');
              if (clipboardData?.text != null) {
                controller.text = clipboardData!.text!;
              }
            },
            child: const Text('لصق من الحافظة'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              final storage = context.read<StorageService>();
              final success = await BackupService.importAllDataFromJson(storage, text);
              if (ctx.mounted) Navigator.of(ctx).pop();

              if (mounted) {
                if (success) {
                  context.read<FinanceProvider>().reload();
                  context.read<DebtProvider>().reload();
                  context.read<GoalProvider>().reload();
                  context.read<RecurringProvider>().reload();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت استعادة النسخة الاحتياطية بنجاح وتحديث كافة البيانات 🚀'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('فشل في قراءة ملف النسخة الاحتياطية. يرجى التأكد من صحة تنسيق JSON'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('استيراد الآن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _syncWithFirebase() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('جاري المزامنة السحابية مع Firebase...')),
    );

    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();
    final debts = context.read<DebtProvider>();
    final goals = context.read<GoalProvider>();
    final recurring = context.read<RecurringProvider>();
    final userId = auth.currentUser?.id ?? 'guest';

    final success = await FirebaseSyncService.syncToCloud(
      finance: finance,
      debts: debts,
      goals: goals,
      recurring: recurring,
      userId: userId,
    );

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(success ? 'تمت المزامنة السحابية مع Firebase بنجاح ☁️' : 'تنبيه: يتطلب اتصالاً بالإنترنت وإعداد Firebase Console'),
        backgroundColor: success ? AppColors.success : AppColors.warning,
      ),
    );
  }

  Future<void> _restoreFromFirebase() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final finance = context.read<FinanceProvider>();
    final debts = context.read<DebtProvider>();
    final goals = context.read<GoalProvider>();
    final recurring = context.read<RecurringProvider>();
    final userId = auth.currentUser?.id ?? 'guest';

    final success = await FirebaseSyncService.restoreFromCloud(
      finance: finance,
      debts: debts,
      goals: goals,
      recurring: recurring,
      userId: userId,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(success ? 'تمت استعادة البيانات من سحابة Firebase بنجاح' : 'لا توجد بيانات سحابية محفوظة بعد'),
        backgroundColor: success ? AppColors.success : AppColors.warning,
      ),
    );
  }

  void _confirmResetAllData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('تصفير كافة البيانات؟'),
          ],
        ),
        content: const Text(
          'سيتم حذف كافة المعاملات والديون وأهداف التوفير، وتصفير أرصدة المحافظ إلى 0.00 ر.س.\nهل أنت متأكد من رغبتك في البدء من الصفر؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final finance = context.read<FinanceProvider>();
              final debt = context.read<DebtProvider>();
              final goal = context.read<GoalProvider>();
              Navigator.of(ctx).pop();

              await finance.resetAllData();
              await debt.resetAllData();
              await goal.resetAllData();

              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('تم تصفير كافة البيانات بنجاح والبدء من الصفر 🧼'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: const Text('تأكيد التصفير', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProv = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والتخصيص'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Summary Card
          Builder(
            builder: (context) {
              final userProfile = context.watch<UserProfileProvider>().profile;
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF132D24), const Color(0xFF0F241C)]
                          : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9).withValues(alpha: 0.5)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            userProfile.avatarPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  userProfile.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    userProfile.tier,
                                    style: const TextStyle(
                                      color: Color(0xFFD97706),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userProfile.title,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userProfile.email,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          ),

          // Section: Account & Authentication
          _buildSectionHeader(context, 'الحساب وتسجيل الدخول'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: auth.isGuest
                          ? const Color(0xFF64748B).withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      auth.isGuest
                          ? Icons.person_outline_rounded
                          : (auth.currentUser?.authMethod == 'google'
                              ? Icons.g_mobiledata_rounded
                              : (auth.currentUser?.authMethod == 'phone'
                                  ? Icons.phone_android_rounded
                                  : Icons.email_rounded)),
                      color: auth.isGuest ? const Color(0xFF64748B) : AppColors.primary,
                    ),
                  ),
                  title: Text(
                    auth.isGuest ? 'وضع الضيف (حساب محلي)' : (auth.currentUser?.name ?? 'المستخدم'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    auth.isGuest
                        ? 'يمكنك ترقية حسابك لربطه سحابياً وحفظ بياناتك'
                        : (auth.currentUser?.email ?? auth.currentUser?.phone ?? 'مسجل بنجاح'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: auth.isGuest
                      ? ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('ترقية الحساب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      : null,
                ),
                 Consumer<WorkspaceProvider>(
                  builder: (context, wsProv, _) {
                    final activeWs = wsProv.activeWorkspace;
                    return Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: activeWs.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(activeWs.icon, color: activeWs.color),
                          ),
                          title: Text(
                            'مساحة العمل: ${activeWs.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${activeWs.type.labelArabic} • (${wsProv.workspaces.length} مساحات عمل مفعلة)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                          onTap: () => WorkspaceSwitcherSheet.show(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: wsProv.currentPlan.tier.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(wsProv.currentPlan.tier.icon, color: wsProv.currentPlan.tier.color),
                          ),
                          title: Row(
                            children: [
                              Text(
                                wsProv.currentPlan.tier.titleArabic,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: wsProv.currentPlan.tier.color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  wsProv.isPro ? 'PRO ⭐' : 'مجاني',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'الحد: حتى ${wsProv.maxWorkspaces} مساحات عمل مستقلة',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () => SaaSPlansSheet.show(context),
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout_rounded, color: AppColors.danger),
                  ),
                  title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  subtitle: const Text('الخروج والعودة إلى شاشة تسجيل الدخول', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.danger),
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Appearance
          _buildSectionHeader(context, 'المظهر والثيم'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      themeProv.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text('الوضع الليلي والنهاري', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    themeProv.themeMode == ThemeMode.dark
                        ? 'الوضع الليلي (مفعل)'
                        : (themeProv.themeMode == ThemeMode.light ? 'الوضع النهاري' : 'تلقائي حسب النظام'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Switch(
                    value: themeProv.isDarkMode,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) => themeProv.toggleTheme(),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildThemeOption(
                      context,
                      'فاتح',
                      Icons.light_mode_rounded,
                      themeProv.themeMode == ThemeMode.light,
                      () => themeProv.setThemeMode(ThemeMode.light),
                    ),
                    _buildThemeOption(
                      context,
                      'داكن',
                      Icons.dark_mode_rounded,
                      themeProv.themeMode == ThemeMode.dark,
                      () => themeProv.setThemeMode(ThemeMode.dark),
                    ),
                    _buildThemeOption(
                      context,
                      'تلقائي',
                      Icons.settings_system_daydream_rounded,
                      themeProv.themeMode == ThemeMode.system,
                      () => themeProv.setThemeMode(ThemeMode.system),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: General & Financial
          _buildSectionHeader(context, 'الخيارات المالية والادخار'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.monetization_on_rounded, color: AppColors.info),
                  ),
                  title: const Text('العملة الحالية', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(themeProv.currencySymbol),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => _showCurrencyPicker(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.flag_rounded, color: AppColors.primary),
                  ),
                  title: const Text('أهداف الادخار وصناديق التوفير', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('إدارة أهدافك ومتابعة نسب الإنجاز', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalsScreen()));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.category_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  title: const Text('إدارة التصنيفات والميزانيات', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('تخصيص تصنيفات المصاريف والإيرادات وحدود الصرف', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen()));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.repeat_rounded, color: Color(0xFFEC4899)),
                  ),
                  title: const Text('الاشتراكات والمعاملات المجدولة', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('إدارة الفواتير والرواتب والاشتراكات الدورية', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecurringScreen()));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF0EA5E9)),
                  ),
                  title: const Text('الميزانيات والحدود الشهرية', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('مراقبة استهلاك الميزانيات ونسب الصرف والتنبيهات', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetsScreen()));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.visibility_off_rounded, color: AppColors.warning),
                  ),
                  title: const Text('إخفاء الأرصدة للخصوصية', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('إخفاء الأرقام على الشاشة الرئيسية', style: TextStyle(fontSize: 12)),
                  trailing: Switch(
                    value: themeProv.hideBalance,
                    onChanged: (_) => themeProv.toggleHideBalance(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: SMS Bank Sync
          _buildSectionHeader(context, 'الرسائل البنكية التلقائية (SMS)'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sms_rounded, color: Color(0xFF0284C7)),
                  ),
                  title: const Text('القراءة التلقائية لرسائل البنوك', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('استقبال إشعارات البنوك وتسجيل العمليات تلقائياً', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SmsSyncDialog(),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sync_rounded, color: AppColors.primary),
                  ),
                  title: const Text('فحص الرسائل البنكية السابقة', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('مسح الرسائل الواردة لآخر 30 يوم وتسجيلها', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SmsSyncDialog(),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Security
          _buildSectionHeader(context, 'الأمان والحماية'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppColors.danger),
                  ),
                  title: const Text('قفل التطبيق برمز PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_pinEnabled ? 'الحماية مفعلة برمز أمان' : 'غير مفعل', style: const TextStyle(fontSize: 12)),
                  trailing: Switch(
                    value: _pinEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _togglePin,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Backup & Export
          _buildSectionHeader(context, 'النسخ الاحتياطي والتصدير'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: AppColors.success),
                  ),
                  title: const Text('تصدير كشف العمليات (Excel CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('تصدير كافة المعاملات لفتحها في Excel', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.copy_rounded, size: 18),
                  onTap: _exportCsv,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.backup_rounded, color: AppColors.primary),
                  ),
                  title: const Text('نسخة احتياطية كاملة (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('تصدير وحفظ كافة بيانات التطبيق وحساباته', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.copy_rounded, size: 18),
                  onTap: _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF6366F1)),
                  ),
                  title: const Text('استيراد نسخة احتياطية (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('استعادة كاملة لبيانات التطبيق وحساباته من نص JSON', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: _showImportBackupDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Firebase Cloud Sync
          _buildSectionHeader(context, 'المزامنة السحابية (Firebase Cloud)'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFFF59E0B)),
                  ),
                  title: const Text('مزامنة البيانات مع سحابة Firebase', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('رفع المعاملات والديون والأهداف للسحابة', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.sync_rounded, color: Color(0xFFF59E0B)),
                  onTap: _syncWithFirebase,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_download_rounded, color: AppColors.info),
                  ),
                  title: const Text('استعادة البيانات من سحابة Firebase', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('استرجاع بياناتك المحفوظة على السحابة', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.download_rounded, color: AppColors.info),
                  onTap: _restoreFromFirebase,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Reset Data (Danger Zone)
          _buildSectionHeader(context, 'تصفير البيانات'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              ),
              title: const Text('تصفير وحذف كافة البيانات', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
              subtitle: const Text('حذف المعاملات، تصفير الأرصدة إلى 0.00 والبدء من الصفر', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.restart_alt_rounded, color: AppColors.danger),
              onTap: _confirmResetAllData,
            ),
          ),

          const SizedBox(height: 24),

          // Section: About
          _buildSectionHeader(context, 'عن التطبيق'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConstants.appName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 2),
                      Text(
                        AppConstants.appTagline,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الإصدار 1.1.0 • صُمم بأعلى معايير الإتقان',
                        style: TextStyle(fontSize: 11, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? AppColors.primary : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
