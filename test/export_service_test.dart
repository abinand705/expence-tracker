import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/services/export_service.dart';
import 'package:expense_tracker/screens/export_data_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExportService Unit Tests', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late TransactionRepository transactionRepo;
    late AccountRepository accountRepo;
    late ExportService exportService;
    late Directory tempDir;
    const uid = 'test_export_user_456';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      final mockUser = MockUser(uid: uid);
      auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      transactionRepo = TransactionRepository();
      transactionRepo.setInstancesForTesting(firestore, auth);
      accountRepo = AccountRepository();
      accountRepo.setInstancesForTesting(firestore, auth);

      // Create dummy transactions in Firestore
      final ref = firestore.collection('users').doc(uid).collection('transactions');
      
      // 1. Expense within range (02 Sep 2026 10:30 AM)
      await ref.doc('tx1').set({
        'id': 'tx1',
        'amount': 250.0,
        'type': 'expense',
        'merchant': 'Swiggy',
        'category': 'food',
        'date': DateTime(2026, 9, 2, 10, 30),
        'accountId': 'acc1',
        'transactionSource': 'sms',
        'upiReference': 'UPI123456789',
        'notes': 'Lunch with colleagues',
      });

      // 2. Expense with custom title & custom category (01 Sep 2026 08:15 PM)
      await ref.doc('tx2').set({
        'id': 'tx2',
        'amount': 1200.0,
        'type': 'expense',
        'merchant': 'AMZN Retail',
        'customTitle': 'New Keyboard',
        'category': 'shopping',
        'customCategory': 'shopping',
        'date': DateTime(2026, 9, 1, 20, 15),
        'accountId': 'acc1',
        'transactionSource': 'manual',
        'paymentMethod': 'Credit Card',
        'notes': 'Office accessories, urgent',
      });

      // 3. Income transaction (02 Sep 2026 09:00 AM) - MUST BE EXCLUDED
      await ref.doc('tx3').set({
        'id': 'tx3',
        'amount': 50000.0,
        'type': 'income',
        'merchant': 'Employer Salary',
        'category': 'others',
        'date': DateTime(2026, 9, 2, 9, 0),
        'accountId': 'acc1',
        'transactionSource': 'sms',
      });

      // 4. Expense outside date range (15 Aug 2026) - MUST BE EXCLUDED
      await ref.doc('tx4').set({
        'id': 'tx4',
        'amount': 800.0,
        'type': 'expense',
        'merchant': 'Supermarket',
        'category': 'food',
        'date': DateTime(2026, 8, 15, 14, 0),
        'accountId': 'acc1',
        'transactionSource': 'sms',
      });

      // 5. Expense with special characters/quotes/newlines in merchant & notes (02 Sep 2026 11:45 PM)
      await ref.doc('tx5').set({
        'id': 'tx5',
        'amount': 99.50,
        'type': 'expense',
        'merchant': 'Café, "Special" & Tea',
        'category': 'food',
        'date': DateTime(2026, 9, 2, 23, 45),
        'accountId': 'acc2',
        'transactionSource': 'sms',
        'notes': 'Line 1\nLine 2 with "quotes" and, commas',
      });

      // Account 1: HDFC Bank
      await firestore.collection('users').doc(uid).collection('accounts').doc('acc1').set({
        'id': 'acc1',
        'name': 'Salary Account',
        'bankName': 'HDFC Bank',
        'accountNumber': '501002345678',
        'accountType': 'Savings',
        'accentColor': 0xFF1E88E5,
      });

      // Account 2: SBI
      await firestore.collection('users').doc(uid).collection('accounts').doc('acc2').set({
        'id': 'acc2',
        'name': 'Savings SBI',
        'bankName': 'State Bank of India',
        'accountNumber': '9876',
        'accountType': 'Savings',
        'accentColor': 0xFF43A047,
      });

      exportService = ExportService(
        transactionRepo: transactionRepo,
        accountRepo: accountRepo,
      );

      tempDir = await Directory.systemTemp.createTemp('moneytrack_export_test');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Custom date range selection filters inclusive expense transactions', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 2);

      final expenses = await exportService.getExpenseTransactions(startDate: start, endDate: end);
      expect(expenses.length, 3); // tx1, tx2, tx5 (tx3 is income, tx4 is in August)
      expect(expenses.any((tx) => tx.id == 'tx1'), isTrue);
      expect(expenses.any((tx) => tx.id == 'tx2'), isTrue);
      expect(expenses.any((tx) => tx.id == 'tx5'), isTrue);
      expect(expenses.any((tx) => tx.id == 'tx3'), isFalse); // Income excluded
      expect(expenses.any((tx) => tx.id == 'tx4'), isFalse); // Outside date range excluded
    });

    test('2. Quick date range calculations (Today, This Week, This Month, Last Month, Last 3 Months, This Year)', () {
      final refDate = DateTime(2026, 9, 15, 14, 30);

      final (todayStart, todayEnd) = ExportService.calculateQuickRange(QuickDateRange.today, referenceDate: refDate);
      expect(todayStart, DateTime(2026, 9, 15));
      expect(todayEnd, DateTime(2026, 9, 15));

      final (thisMonthStart, thisMonthEnd) = ExportService.calculateQuickRange(QuickDateRange.thisMonth, referenceDate: refDate);
      expect(thisMonthStart, DateTime(2026, 9, 1));
      expect(thisMonthEnd, DateTime(2026, 9, 15));

      final (lastMonthStart, lastMonthEnd) = ExportService.calculateQuickRange(QuickDateRange.lastMonth, referenceDate: refDate);
      expect(lastMonthStart, DateTime(2026, 8, 1));
      expect(lastMonthEnd, DateTime(2026, 8, 31));

      final (last3MonthsStart, _) = ExportService.calculateQuickRange(QuickDateRange.last3Months, referenceDate: refDate);
      expect(last3MonthsStart, DateTime(2026, 7, 1));

      final (thisYearStart, _) = ExportService.calculateQuickRange(QuickDateRange.thisYear, referenceDate: refDate);
      expect(thisYearStart, DateTime(2026, 1, 1));
    });

    test('3. Single-day date range (startDate == endDate) is inclusive', () async {
      final day = DateTime(2026, 9, 1);
      final expenses = await exportService.getExpenseTransactions(startDate: day, endDate: day);

      expect(expenses.length, 1);
      expect(expenses.first.id, 'tx2');
    });

    test('4. Start date after end date throws ArgumentError', () async {
      expect(
        () => exportService.getExpenseTransactions(
          startDate: DateTime(2026, 9, 5),
          endDate: DateTime(2026, 9, 1),
        ),
        throwsArgumentError,
      );
    });

    test('5. Summary calculation computes accurate count and sum', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 2);

      final expenses = await exportService.getExpenseTransactions(startDate: start, endDate: end);
      final summary = exportService.calculateSummary(expenses, startDate: start, endDate: end);

      expect(summary.count, 3);
      expect(summary.totalAmount, 250.0 + 1200.0 + 99.50);
      expect(summary.isEmpty, isFalse);
    });

    test('6. Empty date range yields summary with count 0 and isEmpty == true', () async {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);

      final expenses = await exportService.getExpenseTransactions(startDate: start, endDate: end);
      final summary = exportService.calculateSummary(expenses, startDate: start, endDate: end);

      expect(summary.count, 0);
      expect(summary.totalAmount, 0.0);
      expect(summary.isEmpty, isTrue);
    });

    test('7. CSV formatting contains valid headers and correctly escaped columns', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 2);

      final accounts = await accountRepo.getAccounts();
      final accountMap = {for (final a in accounts) a.id: a};

      final expenses = await exportService.getExpenseTransactions(startDate: start, endDate: end);
      final csv = exportService.generateCsvData(expenses, accountMap: accountMap);

      // Must start with UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);

      // Must contain expected header columns
      expect(csv.contains('Date,Time,Title,Merchant,Amount (INR),Category,Account,Bank,Payment Method,Transaction Source,Reference ID,Notes'), isTrue);

      // Must contain custom title priority ('New Keyboard')
      expect(csv.contains('New Keyboard'), isTrue);

      // Must contain masked account number (****5678 for HDFC Bank)
      expect(csv.contains('****5678'), isTrue);
      expect(csv.contains('HDFC Bank'), isTrue);

      // Must contain reference ID
      expect(csv.contains('UPI123456789'), isTrue);

      // Must properly escape quotes and commas in merchant and notes
      expect(csv.contains('"Café, ""Special"" & Tea"'), isTrue);
    });

    test('8. Full export workflow writes real file with meaningful filename to storage', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 2);

      final result = await exportService.exportExpensesToCsv(
        startDate: start,
        endDate: end,
        customDirectory: tempDir,
      );

      expect(result.success, isTrue);
      expect(result.isEmpty, isFalse);
      expect(result.fileName, 'MoneyTrack_Expenses_2026-09-01_to_2026-09-02.csv');
      expect(result.filePath, isNotNull);

      final exportedFile = File(result.filePath!);
      expect(await exportedFile.exists(), isTrue);

      final content = await exportedFile.readAsString();
      expect(content.contains('Swiggy'), isTrue);
      expect(content.contains('New Keyboard'), isTrue);
      expect(result.summary.count, 3);
    });

    test('9. Export is non-destructive and does not modify underlying Firestore documents', () async {
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 9, 2);

      await exportService.exportExpensesToCsv(
        startDate: start,
        endDate: end,
        customDirectory: tempDir,
      );

      final doc = await firestore.collection('users').doc(uid).collection('transactions').doc('tx2').get();
      expect(doc.data()?['customTitle'], 'New Keyboard');
      expect(doc.data()?['amount'], 1200.0);
    });
  });

  group('ExportDataScreen Widget UI Tests', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late TransactionRepository transactionRepo;
    late AccountRepository accountRepo;
    late ExportService exportService;
    const uid = 'test_widget_export_uid';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      firestore = FakeFirebaseFirestore();
      final mockUser = MockUser(uid: uid);
      auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      transactionRepo = TransactionRepository();
      transactionRepo.setInstancesForTesting(firestore, auth);
      accountRepo = AccountRepository();
      accountRepo.setInstancesForTesting(firestore, auth);

      // Insert dummy expense for September 2026
      await firestore.collection('users').doc(uid).collection('transactions').doc('w_tx1').set({
        'id': 'w_tx1',
        'amount': 450.0,
        'type': 'expense',
        'merchant': 'Grocery Mart',
        'category': 'food',
        'date': DateTime.now(),
      });

      exportService = ExportService(
        transactionRepo: transactionRepo,
        accountRepo: accountRepo,
      );
    });

    testWidgets('ExportDataScreen renders quick chips, date cards, and summary preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExportDataScreen(exportService: exportService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export Expense Data'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
      expect(find.text('SUMMARY PREVIEW'), findsOneWidget);
      expect(find.text('Export Expense Data (CSV)'), findsOneWidget);
    });
  });
}
