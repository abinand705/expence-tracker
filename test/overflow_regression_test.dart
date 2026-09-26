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
import 'package:expense_tracker/services/analytics_service.dart';
import 'package:expense_tracker/widgets/dashboard/spend_categories_card.dart';
import 'package:expense_tracker/widgets/add_transaction_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Overflow Regression Tests', () {
    testWidgets('SpendCategoriesCard does not overflow on narrow 360px screen with large numbers', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final testTransactions = [
        model_tx.Transaction(
          id: '1',
          amount: 20.0,
          type: model_tx.TransactionType.expense,
          merchant: 'Food Stall',
          category: 'Food',
          date: now,
        ),
        model_tx.Transaction(
          id: '2',
          amount: 34.0,
          type: model_tx.TransactionType.expense,
          merchant: 'Store',
          category: 'Shopping',
          date: now,
        ),
        model_tx.Transaction(
          id: '3',
          amount: 2330.0,
          type: model_tx.TransactionType.expense,
          merchant: 'Others',
          category: 'Others',
          date: now,
        ),
      ];

      // Track any Flutter overflow errors
      bool hasOverflowError = false;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('overflowed')) {
          hasOverflowError = true;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SpendCategoriesCard(
              transactions: testTransactions,
              analyticsService: AnalyticsService(),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(hasOverflowError, isFalse, reason: 'SpendCategoriesCard should not overflow horizontally');
      expect(find.text('Spend Categories'), findsOneWidget);
      expect(find.text('Others'), findsOneWidget);
      expect(find.text('₹2330 (98%)'), findsOneWidget);
    });

    testWidgets('AddTransactionSheet does not overflow with long account name on 360px screen', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeFirestore = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'user_test', email: 'test@example.com'),
        signedIn: true,
      );

      final accountRepo = AccountRepository();
      accountRepo.setInstancesForTesting(fakeFirestore, mockAuth);
      final categoryRepo = CategoryRepository();
      categoryRepo.setInstancesForTesting(fakeFirestore, mockAuth);

      // Seed account with long name matching the user's screenshot
      await accountRepo.addAccount(Account(
        id: 'acc_kgb',
        name: 'Kerala Gramin Bank Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '••••0544',
        accountType: 'Savings',
        balance: 10000.0,
        currentBalance: 10000.0,
        accentColor: Colors.teal,
      ));

      await categoryRepo.addCategory(Category(
        id: 'bills',
        name: 'Bills',
        iconCodePoint: Icons.receipt.codePoint,
        colorValue: Colors.blue.toARGB32(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      bool hasOverflowError = false;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('overflowed')) {
          hasOverflowError = true;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showAddTransactionSheet(
                    context: context,
                    accountRepository: accountRepo,
                    categoryRepository: categoryRepo,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(hasOverflowError, isFalse, reason: 'AddTransactionSheet should not overflow horizontally with long account label');
      expect(find.byKey(const Key('manual_tx_account_dropdown')), findsOneWidget);
    });
  });
}
