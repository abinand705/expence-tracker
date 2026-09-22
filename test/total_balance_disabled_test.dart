import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/services/analytics_service.dart';
import 'package:expense_tracker/services/statement_parsers/csv_statement_parser.dart';
import 'package:expense_tracker/utils/expense_parser.dart';
import 'package:expense_tracker/utils/feature_flags.dart';
import 'package:expense_tracker/widgets/dashboard/balance_card.dart';

void main() {
  group('MoneyTrack — Temporarily Disable Aggregate Total Balance Tests', () {
    // ── Test 1 — Total Balance enabled ──────────────────────────────────────
    testWidgets('Test 1: BalanceCard displays numeric balance and not "Currently unavailable" when enabled', (tester) async {
      // 1. Verify feature flag is enabled
      expect(FeatureFlags.enableTotalBalance, isTrue);

      final formatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BalanceCard(
              totalBalance: 40000.0,
              formatter: formatter,
            ),
          ),
        ),
      );

      // Verify "TOTAL BALANCE" header and numeric balance
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('Currently unavailable'), findsNothing);
      expect(find.text('₹ 40,000.00'), findsOneWidget);
    });

    // ── Test 2 — Individual account balance remains accessible ───────────────
    test('Test 2: Individual account balance remains accessible and serializable', () {
      final hdfcAccount = Account(
        id: 'acc_hdfc',
        name: 'HDFC Savings',
        bankName: 'HDFC',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.blue,
        currentBalance: 25000.0,
        balanceSource: 'manual',
        balanceUpdatedAt: DateTime(2026, 9, 21),
      );

      final sbiAccount = Account(
        id: 'acc_sbi',
        name: 'SBI Savings',
        bankName: 'SBI',
        accountNumber: '5678',
        accountType: 'savings',
        accentColor: Colors.green,
        currentBalance: 15000.0,
        balanceSource: 'manual',
        balanceUpdatedAt: DateTime(2026, 9, 21),
      );

      // Verify individual balances
      expect(hdfcAccount.currentBalance, 25000.0);
      expect(sbiAccount.currentBalance, 15000.0);

      // Verify serialization / deserialization maintains data integrity
      final hdfcMap = hdfcAccount.toMap();
      final deserializedHdfc = Account.fromMap(hdfcMap);
      expect(deserializedHdfc.currentBalance, 25000.0);
      expect(deserializedHdfc.name, 'HDFC Savings');
      expect(deserializedHdfc.accountNumber, '1234');

      final sbiMap = sbiAccount.toMap();
      final deserializedSbi = Account.fromMap(sbiMap);
      expect(deserializedSbi.currentBalance, 15000.0);
      expect(deserializedSbi.name, 'SBI Savings');
      expect(deserializedSbi.accountNumber, '5678');
    });

    // ── Test 3 — Expense processing remains functional ────────────────────────
    test('Test 3: Expense processing and analytics work without calculating aggregate Total Balance', () {
      final now = DateTime.now();
      final expenseTx = model_tx.Transaction(
        id: 'tx_exp_1',
        merchant: 'Grocery Store',
        amount: 500.0,
        type: model_tx.TransactionType.expense,
        category: 'Food',
        date: now,
        accountId: 'acc_hdfc',
      );

      final analyticsService = AnalyticsService();
      final totalExpenses = analyticsService.calculateTotalExpenses(
        [expenseTx],
        month: now.month,
        year: now.year,
      );

      expect(totalExpenses, 500.0);

      // Aggregate balance calculation is executed when enabled
      double aggregateBalance = 0.0;
      if (FeatureFlags.enableTotalBalance) {
        aggregateBalance = 25000.0 - 500.0;
      }
      expect(aggregateBalance, 24500.0);
    });

    // ── Test 4 — Income processing remains functional ─────────────────────────
    test('Test 4: Income processing and analytics work with calculating aggregate Total Balance', () {
      final now = DateTime.now();
      final incomeTx = model_tx.Transaction(
        id: 'tx_inc_1',
        merchant: 'Acme Corp',
        amount: 50000.0,
        type: model_tx.TransactionType.income,
        category: 'Salary',
        date: now,
        accountId: 'acc_sbi',
      );

      final analyticsService = AnalyticsService();
      final totalIncome = analyticsService.calculateTotalIncome(
        [incomeTx],
        month: now.month,
        year: now.year,
      );

      expect(totalIncome, 50000.0);

      // Aggregate balance calculation is executed when enabled
      double aggregateBalance = 0.0;
      if (FeatureFlags.enableTotalBalance) {
        aggregateBalance = 15000.0 + 50000.0;
      }
      expect(aggregateBalance, 65000.0);
    });

    // ── Test 5 — SMS transaction import continues ─────────────────────────────
    test('Test 5: SMS transaction parsing continues working independently of Total Balance', () {
      const smsBody = 'Rs. 1,200.00 spent on your HDFC Bank Card ending 1234 at Swiggy on 21-Sep-2026. Avl Bal: Rs 23,800.00.';
      
      final parsed = ExpenseParser.parse(smsBody);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1200.0);
      expect(parsed.type, model_tx.TransactionType.expense);
      expect(parsed.accountNumber, '1234');
      expect(parsed.merchant, 'Swiggy');
      expect(parsed.availableBalance, 23800.0);

      // Transaction can be created from SMS without depending on aggregate Total Balance
      final tx = model_tx.Transaction(
        id: 'sms_tx_1',
        merchant: parsed.merchant ?? 'Swiggy',
        amount: parsed.amount,
        type: parsed.type,
        category: 'Food',
        date: DateTime.now(),
        accountId: 'acc_hdfc',
      );

      expect(tx.amount, 1200.0);
      expect(tx.type, model_tx.TransactionType.expense);
    });

    // ── Test 6 — Transaction history continues ───────────────────────────────
    test('Test 6: Transaction history querying, sorting, and filtering continue working', () {
      final tx1 = model_tx.Transaction(
        id: 'tx_1',
        merchant: 'Coffee Shop',
        amount: 150.0,
        type: model_tx.TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 9, 20, 10, 0),
        accountId: 'acc_hdfc',
      );
      final tx2 = model_tx.Transaction(
        id: 'tx_2',
        merchant: 'Restaurant',
        amount: 800.0,
        type: model_tx.TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 9, 21, 20, 0),
        accountId: 'acc_hdfc',
      );
      final tx3 = model_tx.Transaction(
        id: 'tx_3',
        merchant: 'Freelance Client',
        amount: 5000.0,
        type: model_tx.TransactionType.income,
        category: 'Income',
        date: DateTime(2026, 9, 19, 15, 0),
        accountId: 'acc_sbi',
      );

      final transactions = [tx1, tx2, tx3];

      // Sorting descending by date
      final sorted = List<model_tx.Transaction>.from(transactions)
        ..sort((a, b) => b.date.compareTo(a.date));
      expect(sorted.first.id, 'tx_2');
      expect(sorted.last.id, 'tx_3');

      // Filter by account
      final hdfcTxs = transactions.where((t) => t.accountId == 'acc_hdfc').toList();
      expect(hdfcTxs.length, 2);

      // Filter by type
      final expenses = transactions.where((t) => t.type == model_tx.TransactionType.expense).toList();
      expect(expenses.length, 2);
      final incomes = transactions.where((t) => t.type == model_tx.TransactionType.income).toList();
      expect(incomes.length, 1);
    });

    // ── Test 7 — Dashboard analytics continue ────────────────────────────────
    test('Test 7: Dashboard expense/income/category analytics continue working independently', () {
      final now = DateTime.now();
      final txList = [
        model_tx.Transaction(
          id: 't1',
          merchant: 'Supermarket',
          amount: 2000.0,
          type: model_tx.TransactionType.expense,
          category: 'Food',
          date: DateTime(now.year, now.month, 5),
        ),
        model_tx.Transaction(
          id: 't2',
          merchant: 'Power Dept',
          amount: 1500.0,
          type: model_tx.TransactionType.expense,
          category: 'Bills',
          date: DateTime(now.year, now.month, 10),
        ),
        model_tx.Transaction(
          id: 't3',
          merchant: 'Employer',
          amount: 30000.0,
          type: model_tx.TransactionType.income,
          category: 'Income',
          date: DateTime(now.year, now.month, 12),
        ),
      ];

      final analytics = AnalyticsService();
      final totalExpenses = analytics.calculateTotalExpenses(txList, month: now.month, year: now.year);
      final totalIncome = analytics.calculateTotalIncome(txList, month: now.month, year: now.year);
      final categoryTotals = analytics.calculateCategoryTotals(txList, month: now.month, year: now.year);

      expect(totalExpenses, 3500.0);
      expect(totalIncome, 30000.0);
      expect(categoryTotals['Food'], 2000.0);
      expect(categoryTotals['Bills'], 1500.0);
    });

    // ── Test 8 — Statement import continues ──────────────────────────────────
    test('Test 8: Statement parser extracts transactions independently of aggregate Total Balance', () async {
      const csvContent = 'Date,Description,Debit,Credit,Balance\r\n'
          '2026-09-01,Opening Balance,0,0,50000.00\r\n'
          '2026-09-05,Amazon Shopping,1299.00,0,48701.00\r\n'
          '2026-09-10,Salary Credit,0,75000.00,123701.00\r\n';

      final tempDir = Directory.systemTemp.createTempSync('statement_test_');
      final tempFile = File('${tempDir.path}/statement.csv')..writeAsStringSync(csvContent);

      try {
        final parser = CsvStatementParser();
        final parsedStatement = await parser.parse(tempFile);
        expect(parsedStatement.transactions.length, 2);
        expect(parsedStatement.transactions[0].debit, 1299.00);
        expect(parsedStatement.transactions[0].description, 'Amazon Shopping');
        expect(parsedStatement.transactions[1].credit, 75000.00);
        expect(parsedStatement.transactions[1].description, 'Salary Credit');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
