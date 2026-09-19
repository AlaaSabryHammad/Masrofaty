import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrofaty/core/constants/app_constants.dart';
import 'package:masrofaty/core/services/storage_service.dart';
import 'package:masrofaty/providers/theme_provider.dart';
import 'package:masrofaty/providers/workspace_provider.dart';
import 'package:masrofaty/views/settings/widgets/currency_picker_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CurrencyPickerSheet displays currencies, supports search, and changes currency', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storageService),
          ChangeNotifierProvider(create: (_) => ThemeProvider(storageService)),
          ChangeNotifierProvider(create: (_) => WorkspaceProvider(storageService)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              final themeProv = context.watch<ThemeProvider>();
              return Scaffold(
                body: Column(
                  children: [
                    Text('Current Currency: ${themeProv.currencySymbol}'),
                    ElevatedButton(
                      onPressed: () => CurrencyPickerSheet.show(context),
                      child: const Text('Change Currency'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Current Currency: ر.س'), findsOneWidget);

    // Open Currency Picker Sheet
    await tester.tap(find.text('Change Currency'));
    await tester.pumpAndSettle();

    expect(find.text('تغيير العملة الافتراضية'), findsOneWidget);
    expect(find.text('جنيه مصري'), findsOneWidget);

    // Test Search filter
    await tester.enterText(find.byType(TextField), 'كويت');
    await tester.pumpAndSettle();

    expect(find.text('دينار كويتي'), findsOneWidget);
    expect(find.text('جنيه مصري'), findsNothing);

    // Select Kuwaiti Dinar
    await tester.tap(find.text('دينار كويتي'));
    await tester.pumpAndSettle();

    // Verify currency updated in ThemeProvider & UI
    expect(find.text('Current Currency: د.ك'), findsOneWidget);
    expect(storageService.getCurrencySymbol(), 'د.ك');
  });

  test('AppConstants getCurrencyBySymbol resolves correctly', () {
    final egp = AppConstants.getCurrencyBySymbol('ج.م');
    expect(egp['code'], 'EGP');
    expect(egp['name'], 'جنيه مصري');
    expect(egp['flag'], '🇪🇬');

    final fallback = AppConstants.getCurrencyBySymbol('UNKNOWN');
    expect(fallback['symbol'], 'UNKNOWN');
  });
}
