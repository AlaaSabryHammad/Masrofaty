import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/services/auth_service.dart';
import 'core/services/firebase_sync_service.dart';
import 'core/services/security_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_profile_provider.dart';
import 'views/auth/login_screen.dart';
import 'views/main_navigation_screen.dart';
import 'views/security/pin_lock_screen.dart';
import 'views/splash/splash_screen.dart';

import 'providers/recurring_provider.dart';
import 'core/config/email_config.dart';
import 'providers/workspace_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase first safely
  try {
    await FirebaseSyncService.initialize();
  } catch (e) {
    debugPrint('[FirebaseSyncService] init notice: $e');
  }

  // 2. Initialize storage & email config
  final storageService = await StorageService.init();
  await EmailConfig.init();
  final securityService = SecurityService(storageService.prefs);
  final authService = AuthService(storageService.prefs);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<SecurityService>.value(value: securityService),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider(create: (_) => ThemeProvider(storageService)),
        ChangeNotifierProvider(create: (_) => FinanceProvider(storageService)),
        ChangeNotifierProvider(create: (_) => DebtProvider(storageService)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(storageService)),
        ChangeNotifierProvider(create: (_) => GoalProvider(storageService)),
        ChangeNotifierProvider(create: (_) => UserProfileProvider(storageService.prefs)),
        ChangeNotifierProvider(create: (_) => ContactProvider(storageService)),
        ChangeNotifierProvider(create: (_) => RecurringProvider(storageService)),
        ChangeNotifierProvider(
          create: (ctx) => WorkspaceProvider(
            storageService,
            () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try { ctx.read<FinanceProvider>().reload(); } catch (_) {}
                try { ctx.read<DebtProvider>().reload(); } catch (_) {}
                try { ctx.read<GoalProvider>().reload(); } catch (_) {}
                try { ctx.read<ContactProvider>().reload(); } catch (_) {}
                try { ctx.read<RecurringProvider>().reload(); } catch (_) {}
                try { ctx.read<ThemeProvider>().refreshCurrency(); } catch (_) {}
              });
            },
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            late final AuthProvider authProvider;
            authProvider = AuthProvider(
              authService,
              ctx.read<UserProfileProvider>(),
              storageService,
              ctx.read<WorkspaceProvider>(),
              () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final user = authProvider.currentUser;
                  final uid = user?.id ?? 'guest';
                  try { ctx.read<WorkspaceProvider>().initForUser(uid); } catch (_) {}
                  try { ctx.read<UserProfileProvider>().initForUser(uid, user); } catch (_) {}
                  try { ctx.read<FinanceProvider>().reload(); } catch (_) {}
                  try { ctx.read<DebtProvider>().reload(); } catch (_) {}
                  try { ctx.read<GoalProvider>().reload(); } catch (_) {}
                  try { ctx.read<ContactProvider>().reload(); } catch (_) {}
                  try { ctx.read<RecurringProvider>().reload(); } catch (_) {}
                  try { ctx.read<ThemeProvider>().refreshCurrency(); } catch (_) {}
                });
              },
            );
            return authProvider;
          },
        ),
      ],
      child: const MasrofatyApp(),
    ),
  );
}

class MasrofatyApp extends StatelessWidget {
  const MasrofatyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // 1. Check if user is authenticated (or guest)
    if (!auth.isAuthenticated) {
      _unlocked = false;
      return const LoginScreen();
    }

    // 2. Check if PIN locked
    final security = context.read<SecurityService>();
    if (security.isLocked && !_unlocked) {
      return PinLockScreen(
        securityService: security,
        isSettingPin: false,
        onUnlocked: () {
          setState(() => _unlocked = true);
        },
      );
    }

    // 3. Authenticated and unlocked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<RecurringProvider>().checkAndExecuteDue(context.read<FinanceProvider>());
        } catch (_) {}
      }
    });
    return const MainNavigationScreen();
  }
}
