import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masrofaty/core/services/sms_sync_service.dart';
import 'package:masrofaty/core/services/storage_service.dart';
import 'package:masrofaty/providers/finance_provider.dart';
import 'package:masrofaty/providers/theme_provider.dart';
import 'package:masrofaty/views/dashboard/widgets/sms_sync_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('iOS Bank SMS Parsing & Service Tests', () {
    test('Parse Al-Rajhi purchase message', () {
      const sms = 'شراء عبر مدى بقيمة 184.50 ر.س من أسواق العثيم بطاقة مدى *1234 في 18/09/2026';
      final tx = SmsSyncService.parseRawText(sms, sender: 'AlRajhi');

      expect(tx, isNotNull);
      expect(tx!.amount, 184.50);
      expect(tx.isExpense, isTrue);
      expect(tx.isAtmWithdrawal, isFalse);
      expect(tx.merchant, contains('أسواق العثيم'));
    });

    test('Parse ATM Cash Withdrawal message', () {
      const sms = 'سحب نقدي من صراف آلي بمبلغ 500.00 SAR بطاقة *9876';
      final tx = SmsSyncService.parseRawText(sms, sender: 'AlAhli');

      expect(tx, isNotNull);
      expect(tx!.amount, 500.00);
      expect(tx.isAtmWithdrawal, isTrue);
    });

    test('Parse Salary Deposit message', () {
      const sms = 'إيداع راتب بمبلغ 12000.00 ر.س في حسابك لدى بنك الإنماء';
      final tx = SmsSyncService.parseRawText(sms, sender: 'Alinma');

      expect(tx, isNotNull);
      expect(tx!.amount, 12000.00);
      expect(tx.isExpense, isFalse);
    });

    test('Parse multiple batch SMS messages', () {
      const batchSms = '''
شراء عبر مدى بقيمة 45.00 ر.س من ماكدونالدز بطاقة *1111
---
شراء عبر مدى بقيمة 220.00 ر.س من مكتبة جرير بطاقة *2222
''';
      final list = SmsSyncService.parseMultipleMessages(batchSms);

      expect(list.length, 2);
      expect(list[0].amount, 45.00);
      expect(list[1].amount, 220.00);
    });

    test('Apply parsed transaction to FinanceProvider', () async {
      final storage = await StorageService.init();
      final finance = FinanceProvider(storage);


      final initialTxCount = finance.transactions.length;

      const sms = 'شراء بقيمة 75.00 ر.س من صيدلية النهدي';
      final tx = SmsSyncService.parseRawText(sms)!;

      await SmsSyncService.applyTransactionToFinance(tx, finance);

      expect(finance.transactions.length, initialTxCount + 1);
      final added = finance.transactions.first;
      expect(added.amount, 75.00);
      expect(added.title, contains('صيدلية النهدي'));
      expect(added.type, 'expense');
    });
  });

  group('SmsSyncDialog Widget Tests', () {
    testWidgets('Renders SmsSyncDialog with paste button and text input', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': ''};
        }
        return null;
      });

      final storage = await StorageService.init();
      final finance = FinanceProvider(storage);

      final theme = ThemeProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: finance),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SmsSyncDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify title exists
      expect(find.text('القارئ الذكي لرسائل البنوك'), findsOneWidget);

      // Verify paste button exists
      expect(find.textContaining('قراءة الرسالة المنسوخة من الحافظة'), findsOneWidget);

      // Verify input field exists
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Enter SMS in text field, tap parse, and save transaction', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': ''};
        }
        return null;
      });

      final storage = await StorageService.init();
      final finance = FinanceProvider(storage);
      final theme = ThemeProvider(storage);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: finance),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SmsSyncDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter SMS in TextField
      const testSms = 'شراء عبر مدى بقيمة 120.00 ر.س من مكتبة جرير بطاقة *5555';
      await tester.enterText(find.byType(TextField), testSms);
      await tester.pump();

      // Tap 'تحليل الرسالة' button
      final parseButton = find.text('تحليل الرسالة');
      expect(parseButton, findsOneWidget);
      await tester.tap(parseButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify transaction is detected and displayed in a CheckboxListTile
      expect(find.widgetWithText(CheckboxListTile, 'مكتبة جرير بطاقة *'), findsOneWidget);

      // Verify save button appears
      final saveButton = find.textContaining('تسجيل العمليات المحددة');
      expect(saveButton, findsOneWidget);

      // Tap save
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify transaction was added to FinanceProvider
      expect(
        finance.transactions.any((tx) => tx.amount == 120.00 && tx.title.contains('مكتبة جرير')),
        isTrue,
      );
    });
  });
}
