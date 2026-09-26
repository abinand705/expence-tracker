import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/repositories/category_repository.dart';
import 'package:expense_tracker/widgets/add_transaction_sheet.dart';
import 'package:expense_tracker/screens/transactions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late TransactionRepository transactionRepo;
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;

  final testUser = MockUser(
    isAnonymous: false,
    uid: 'user_123',
    email: 'user@example.com',
    displayName: 'Test User',
  );

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(mockUser: testUser, signedIn: true);

    transactionRepo = TransactionRepository();
    transactionRepo.setInstancesForTesting(fakeFirestore, mockAuth);

    accountRepo = AccountRepository();
    accountRepo.setInstancesForTesting(fakeFirestore, mockAuth);

    categoryRepo = CategoryRepository();
    categoryRepo.setInstancesForTesting(fakeFirestore, mockAuth);
  });

  Account createSampleAccount({
    String id = 'acc_1',
    String name = 'KGBANK Savings',
    String bankName = 'KGBANK',
    String accountNumber = 'XXXX1234',
    double balance = 25000.0,
  }) {
    return Account(
      id: id,
      name: name,
      bankName: bankName,
      accountNumber: accountNumber,
      accountType: 'Savings',
      balance: balance,
      currentBalance: balance,
      accentColor: Colors.blue,
    );
  }

  Category createSampleCategory({
    String id = 'food',
    String name = 'Food',
  }) {
    final now = DateTime.now();
    return Category(
      id: id,
      name: name,
      iconCodePoint: Icons.restaurant.codePoint,
      colorValue: Colors.orange.toARGB32(),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> pumpTestWidget(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: child),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    final submitFinder = find.byKey(const Key('submit_transaction_button'));
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();
  }

  group('Transactions Page — Manual Transaction Entry Tests', () {
    testWidgets('1. Plus button appears at top of Transactions page', (tester) async {
      await pumpTestWidget(tester, TransactionsScreen(
        transactionRepository: transactionRepo,
        accountRepository: accountRepo,
        categoryRepository: categoryRepo,
      ));

      expect(find.byKey(const Key('add_transaction_button')), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('2. Tapping plus button opens the Add Transaction panel', (tester) async {
      await accountRepo.addAccount(createSampleAccount());
      await categoryRepo.addCategory(createSampleCategory());

      await pumpTestWidget(tester, TransactionsScreen(
        transactionRepository: transactionRepo,
        accountRepository: accountRepo,
        categoryRepository: categoryRepo,
      ));

      await tester.tap(find.byKey(const Key('add_transaction_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add Transaction'), findsWidgets);
      expect(find.byKey(const Key('manual_tx_title_field')), findsOneWidget);
      expect(find.byKey(const Key('manual_tx_amount_field')), findsOneWidget);
      expect(find.byKey(const Key('manual_tx_type_segmented_button')), findsOneWidget);
      expect(find.byKey(const Key('manual_tx_category_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('manual_tx_account_dropdown')), findsOneWidget);
    });

    testWidgets('3. Category and Account dropdowns load available options', (tester) async {
      await accountRepo.addAccount(createSampleAccount(id: 'acc_kg', name: 'KGBANK Savings', accountNumber: '1234'));
      await categoryRepo.addCategory(createSampleCategory(id: 'food', name: 'Food'));
      await categoryRepo.addCategory(createSampleCategory(id: 'bills', name: 'Bills'));

      await pumpTestWidget(tester, AddTransactionSheet(
        transactionRepository: transactionRepo,
        accountRepository: accountRepo,
        categoryRepository: categoryRepo,
      ));

      expect(find.byKey(const Key('manual_tx_category_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('manual_tx_account_dropdown')), findsOneWidget);
      expect(find.textContaining('KGBANK Savings'), findsOneWidget);
    });

    testWidgets('4. Valid Debit transaction saves to Firestore and updates account balance', (tester) async {
      final acc = createSampleAccount(id: 'acc_1', balance: 5000.0);
      await accountRepo.addAccount(acc);
      await categoryRepo.addCategory(createSampleCategory(id: 'food', name: 'Food'));

      await pumpTestWidget(tester, AddTransactionSheet(
        transactionRepository: transactionRepo,
        accountRepository: accountRepo,
        categoryRepository: categoryRepo,
      ));

      await tester.enterText(find.byKey(const Key('manual_tx_title_field')), 'Lunch at Cafe');
      await tester.enterText(find.byKey(const Key('manual_tx_amount_field')), '350.0');

      await tapSubmit(tester);

      final txs = await transactionRepo.getTransactions();
      expect(txs.length, 1);
      expect(txs.first.merchant, 'Lunch at Cafe');
      expect(txs.first.amount, 350.0);
      expect(txs.first.type, model_tx.TransactionType.expense);
      expect(txs.first.accountId, 'acc_1');
      expect(txs.first.isManual, true);
      expect(txs.first.transactionSource, 'manual');

      // Account balance reduced by 350
      final updatedAcc = await accountRepo.getAccountById('acc_1');
      expect(updatedAcc?.currentBalance, 5000.0 - 350.0);
    });

    testWidgets('5. Valid Credit transaction saves to Firestore and updates account balance', (tester) async {
      final acc = createSampleAccount(id: 'acc_1', balance: 5000.0);
      await accountRepo.addAccount(acc);
      await categoryRepo.addCategory(createSampleCategory(id: 'food', name: 'Food'));

      await pumpTestWidget(tester, AddTransactionSheet(
        transactionRepository: transactionRepo,
        accountRepository: accountRepo,
        categoryRepository: categoryRepo,
      ));

      await tester.enterText(find.byKey(const Key('manual_tx_title_field')), 'Freelance Payment');
      await tester.enterText(find.byKey(const Key('manual_tx_amount_field')), '15000.0');

      // Switch to Credit
      await tester.tap(find.text('Credit'));
      await tester.pumpAndSettle();

      await tapSubmit(tester);

      final txs = await transactionRepo.getTransactions();
      expect(txs.length, 1);
      expect(txs.first.merchant, 'Freelance Payment');
      expect(txs.first.amount, 15000.0);
      expect(txs.first.type, model_tx.TransactionType.income);
      expect(txs.first.accountId, 'acc_1');

      // Account balance increased by 15000
      final updatedAcc = await accountRepo.getAccountById('acc_1');
      expect(updatedAcc?.currentBalance, 5000.0 + 15000.0);
    });

    testWidgets('6. Validation catches empty title and amount', (tester) async {
      await accountRepo.addAccount(createSampleAccount());
      await categoryRepo.addCategory(createSampleCategory());

      await pumpTestWidget(tester, AddTransactionSheet(
        transactionRepository: transactionRepo,
        accountRepository: accountRepo,
        categoryRepository: categoryRepo,
      ));

      await tapSubmit(tester);

      expect(find.text('Title cannot be empty.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('manual_tx_title_field')), 'Shopping');
      await tapSubmit(tester);

      expect(find.text('Amount cannot be empty.'), findsOneWidget);
    });
  });
}
