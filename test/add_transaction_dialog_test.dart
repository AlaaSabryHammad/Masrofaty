import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrofaty/core/services/storage_service.dart';

import 'package:masrofaty/models/transaction_model.dart';
import 'package:masrofaty/providers/contact_provider.dart';
import 'package:masrofaty/providers/finance_provider.dart';
import 'package:masrofaty/providers/theme_provider.dart';
import 'package:masrofaty/views/transactions/add_transaction_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AddTransactionDialog renders wallet dropdown without assertion errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    final finance = FinanceProvider(storage);
    final contact = ContactProvider(storage);
    final theme = ThemeProvider(storage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: finance),
          ChangeNotifierProvider.value(value: contact),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddTransactionDialog(initialIsExpense: true),
          ),
        ),
      ),
    );

    // Let post frame callbacks and animations settle
    await tester.pumpAndSettle();

    // Verify Dropdown exists and displays properly
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AddTransactionDialog in Edit mode matches wallet correctly without crash', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    final finance = FinanceProvider(storage);
    final contact = ContactProvider(storage);
    final theme = ThemeProvider(storage);

    final dummyTx = TransactionModel(
      id: 'tx_edit_test',
      title: 'وجبة غداء',
      amount: 45.0,
      type: 'expense',
      categoryId: finance.categories.first.id,
      walletId: finance.wallets.first.id,
      date: DateTime.now(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: finance),
          ChangeNotifierProvider.value(value: contact),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddTransactionDialog(transactionToEdit: dummyTx),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('وجبة غداء'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AddTransactionDialog handles potential duplicate wallets safely without crash', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    final finance = FinanceProvider(storage);
    final contact = ContactProvider(storage);
    final theme = ThemeProvider(storage);

    // Inject duplicate wallet into finance.wallets list
    final w1 = finance.wallets.first;
    finance.wallets.add(w1); // Deliberate duplicate

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: finance),
          ChangeNotifierProvider.value(value: contact),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddTransactionDialog(initialIsExpense: true),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
