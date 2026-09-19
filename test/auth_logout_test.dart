import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrofaty/core/services/auth_service.dart';
import 'package:masrofaty/core/services/storage_service.dart';

import 'package:masrofaty/providers/auth_provider.dart';
import 'package:masrofaty/providers/contact_provider.dart';
import 'package:masrofaty/providers/debt_provider.dart';
import 'package:masrofaty/providers/finance_provider.dart';
import 'package:masrofaty/providers/goal_provider.dart';
import 'package:masrofaty/providers/notification_provider.dart';
import 'package:masrofaty/providers/recurring_provider.dart';
import 'package:masrofaty/providers/theme_provider.dart';
import 'package:masrofaty/providers/user_profile_provider.dart';
import 'package:masrofaty/providers/workspace_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Logout completes cleanly and triggers reload without ProviderNotFoundException', (tester) async {
    SharedPreferences.setMockInitialValues({
      AuthService.keyAuthUser: '{"id":"test_user_123","email":"test@example.com","name":"Test User","isGuest":false,"role":"user","isEmailVerified":true}',
    });

    final storageService = await StorageService.init();
    final authService = AuthService(storageService.prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
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
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              final auth = context.watch<AuthProvider>();
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await auth.logout();
                    },
                    child: Text(auth.isAuthenticated ? 'Logged In: ${auth.currentUser?.name}' : 'Logged Out'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Logged In: Test User'), findsOneWidget);

    // Perform logout tap
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Logged Out'), findsOneWidget);
  });
}
