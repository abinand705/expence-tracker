import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/repositories/pending_due_repository.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/services/analytics_service.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/widgets/transaction_detail_dialog.dart';
import 'package:expense_tracker/widgets/transaction_card.dart';
import 'package:expense_tracker/models/account.dart';

class MockTransactionRepository implements TransactionRepository {
  final Map<String, model_tx.Transaction> transactions = {};

  @override
  Future<String> addTransaction(model_tx.Transaction tx) async {
    transactions[tx.id] = tx;
    return tx.id;
  }

  @override
  Future<bool> addTransactionIfAbsent(model_tx.Transaction tx) async {
    if (transactions.containsKey(tx.id)) return false;
    transactions[tx.id] = tx;
    return true;
  }

  @override
  Future<List<model_tx.Transaction>> getTransactions() async {
    return transactions.values.toList();
  }

  @override
  Future<void> updateTransactionCategory(String transactionId, String category) async {
    if (transactions.containsKey(transactionId)) {
      final normalized = model_tx.TransactionCategory.normalize(category);
      final existing = transactions[transactionId]!;
      transactions[transactionId] = existing.copyWith(
        customCategory: normalized,
        category: normalized,
      );
    }
  }

  @override
  Future<void> updateTransactionTitle(String transactionId, String? customTitle) async {
    if (transactions.containsKey(transactionId)) {
      final existing = transactions[transactionId]!;
      transactions[transactionId] = existing.copyWith(
        customTitle: customTitle,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPendingDueRepository implements PendingDueRepository {
  @override
  Future<bool> addPendingDueIfAbsent(dynamic due) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Transaction Category Model & Precedence', () {
    test('1. New transaction without category defaults safely to Others for display', () {
      final tx = model_tx.Transaction(
        id: 'tx_1',
        amount: 500,
        type: model_tx.TransactionType.expense,
        merchant: 'Grocery Store',
        category: '',
        date: DateTime(2026, 9, 1),
      );
      expect(tx.displayCategory, 'Others');
    });

    test('2. User selects Food -> category = food, displayCategory = Food', () {
      final tx = model_tx.Transaction(
        id: 'tx_2',
        amount: 250,
        type: model_tx.TransactionType.expense,
        merchant: 'Zomato',
        category: 'food',
        date: DateTime(2026, 9, 1),
      );
      expect(tx.effectiveCategory, 'food');
      expect(tx.displayCategory, 'Food');
    });

    test('3. User selects Bills -> category = bills, displayCategory = Bills', () {
      final tx = model_tx.Transaction(
        id: 'tx_3',
        amount: 800,
        type: model_tx.TransactionType.expense,
        merchant: 'Airtel',
        category: 'bills',
        date: DateTime(2026, 9, 1),
      );
      expect(tx.effectiveCategory, 'bills');
      expect(tx.displayCategory, 'Bills');
    });

    test('4. User selects Shopping -> category = shopping, displayCategory = Shopping', () {
      final tx = model_tx.Transaction(
        id: 'tx_4',
        amount: 1500,
        type: model_tx.TransactionType.expense,
        merchant: 'Amazon',
        category: 'shopping',
        date: DateTime(2026, 9, 1),
      );
      expect(tx.effectiveCategory, 'shopping');
      expect(tx.displayCategory, 'Shopping');
    });

    test('5. User selects Others -> category = others, displayCategory = Others', () {
      final tx = model_tx.Transaction(
        id: 'tx_5',
        amount: 100,
        type: model_tx.TransactionType.expense,
        merchant: 'Misc',
        category: 'others',
        date: DateTime(2026, 9, 1),
      );
      expect(tx.effectiveCategory, 'others');
      expect(tx.displayCategory, 'Others');
    });

    test('6. User customCategory overrides auto detected category', () {
      final tx = model_tx.Transaction(
        id: 'tx_6',
        amount: 350,
        type: model_tx.TransactionType.expense,
        merchant: 'Swiggy',
        category: 'food',
        customCategory: 'shopping',
        date: DateTime(2026, 9, 1),
      );
      expect(tx.effectiveCategory, 'shopping');
      expect(tx.displayCategory, 'Shopping');
    });
  });

  group('Transaction Category Repository & Persistence', () {
    late MockTransactionRepository repo;

    setUp(() {
      repo = MockTransactionRepository();
    });

    test('7. updateTransactionCategory modifies only category field and preserves other fields', () async {
      final originalDate = DateTime(2026, 9, 1, 14, 30);
      final tx = model_tx.Transaction(
        id: 'tx_persist_1',
        amount: 750,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'others',
        customTitle: 'D-Mart Groceries',
        accountId: 'acc_hdfc_0544',
        rawMessage: 'Rs. 750 debited for D-Mart',
        date: originalDate,
        transactionSource: 'sms',
      );
      await repo.addTransaction(tx);

      // Change category from others to food
      await repo.updateTransactionCategory('tx_persist_1', 'food');

      final updated = repo.transactions['tx_persist_1']!;
      expect(updated.effectiveCategory, 'food');
      expect(updated.displayCategory, 'Food');

      // Verify all other fields are intact
      expect(updated.amount, 750);
      expect(updated.type, model_tx.TransactionType.expense);
      expect(updated.merchant, 'Unknown Merchant');
      expect(updated.customTitle, 'D-Mart Groceries');
      expect(updated.displayTitle, 'D-Mart Groceries');
      expect(updated.accountId, 'acc_hdfc_0544');
      expect(updated.rawMessage, 'Rs. 750 debited for D-Mart');
      expect(updated.date, originalDate);
      expect(updated.transactionSource, 'sms');
    });

    test('8. Changing category from Food to Shopping updates only category', () async {
      final tx = model_tx.Transaction(
        id: 'tx_change_cat',
        amount: 500,
        type: model_tx.TransactionType.expense,
        merchant: 'Amazon',
        category: 'food',
        date: DateTime(2026, 9, 1),
      );
      await repo.addTransaction(tx);

      await repo.updateTransactionCategory('tx_change_cat', 'shopping');

      final updated = repo.transactions['tx_change_cat']!;
      expect(updated.effectiveCategory, 'shopping');
      expect(updated.displayCategory, 'Shopping');
    });
  });

  group('Deduplication & Re-Scan Safety', () {
    late MockTransactionRepository repo;
    late MockPendingDueRepository dueRepo;

    setUp(() {
      repo = MockTransactionRepository();
      dueRepo = MockPendingDueRepository();
    });

    test('9. Deduplication: changing category does not change transaction ID / fingerprint', () async {
      final tx = model_tx.Transaction(
        id: 'sms_fingerprint_abc123',
        amount: 500,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'food',
        date: DateTime(2026, 9, 1),
      );
      await repo.addTransaction(tx);

      await repo.updateTransactionCategory('sms_fingerprint_abc123', 'shopping');

      expect(repo.transactions.containsKey('sms_fingerprint_abc123'), isTrue);
      expect(repo.transactions.length, 1);
      expect(repo.transactions['sms_fingerprint_abc123']!.displayCategory, 'Shopping');
    });

    test('10. SMS Rescan preserves user-assigned category', () async {
      final importer = SmsTransactionImporter(transactionRepo: repo, pendingDueRepo: dueRepo);
      final hdfcAcc = Account(
        id: 'acc_hdfc',
        name: 'HDFC Bank',
        bankName: 'HDFC Bank',
        accountNumber: '',
        accountType: 'Savings',
        accentColor: Colors.blue,
      );
      final msg = Message(
        id: 'msg_cat_scan',
        text: 'Rs. 450 debited for Swiggy on 01-09-2026',
        timestamp: DateTime(2026, 9, 1),
        isMe: false,
      );

      // 1. Initial import (guessed as food)
      final res1 = await importer.importMessage(msg, 'HDFC Bank', null, null, [hdfcAcc]);
      expect(res1, SmsImportResult.imported);
      final txId = repo.transactions.keys.first;

      // 2. User changes category to Others
      await repo.updateTransactionCategory(txId, 'others');
      expect(repo.transactions[txId]!.displayCategory, 'Others');

      // 3. Repeated SMS scan
      final res2 = await importer.importMessage(msg, 'HDFC Bank', null, null, [hdfcAcc]);
      expect(res2, SmsImportResult.duplicate);

      // Verify category is still Others
      expect(repo.transactions[txId]!.displayCategory, 'Others');
    });
  });

  group('Dashboard Spend Categories & Analytics', () {
    final analyticsService = AnalyticsService();

    test('11. Spend Categories aggregates expenses by category correctly', () {
      final transactions = [
        model_tx.Transaction(id: '1', amount: 100, type: model_tx.TransactionType.expense, merchant: 'Cafe', category: 'food', date: DateTime(2026, 9, 1)),
        model_tx.Transaction(id: '2', amount: 200, type: model_tx.TransactionType.expense, merchant: 'Restaurant', category: 'food', date: DateTime(2026, 9, 2)),
        model_tx.Transaction(id: '3', amount: 500, type: model_tx.TransactionType.expense, merchant: 'Electric Co', category: 'bills', date: DateTime(2026, 9, 3)),
        model_tx.Transaction(id: '4', amount: 1000, type: model_tx.TransactionType.expense, merchant: 'Clothing Store', category: 'shopping', date: DateTime(2026, 9, 4)),
        model_tx.Transaction(id: '5', amount: 50, type: model_tx.TransactionType.expense, merchant: 'Misc', category: 'others', date: DateTime(2026, 9, 5)),
      ];

      final totals = analyticsService.calculateCategoryTotals(transactions, month: 9, year: 2026);

      expect(totals['Food'], 300);
      expect(totals['Bills'], 500);
      expect(totals['Shopping'], 1000);
      expect(totals['Others'], 50);

      final totalExpense = analyticsService.calculateTotalExpenses(transactions, month: 9, year: 2026);
      expect(totalExpense, 1850);
    });

    test('12. Income exclusion: credits and income are NOT included in Spend Categories', () {
      final transactions = [
        model_tx.Transaction(id: 'inc_1', amount: 50000, type: model_tx.TransactionType.income, merchant: 'Salary', category: 'income', date: DateTime(2026, 9, 1)),
        model_tx.Transaction(id: 'exp_1', amount: 500, type: model_tx.TransactionType.expense, merchant: 'Dinner', category: 'food', date: DateTime(2026, 9, 2)),
      ];

      final totals = analyticsService.calculateCategoryTotals(transactions, month: 9, year: 2026);

      expect(totals['Food'], 500);
      expect(totals['Others'] ?? 0, 0);

      final totalExpense = analyticsService.calculateTotalExpenses(transactions, month: 9, year: 2026);
      expect(totalExpense, 500);
    });

    test('13. Category change from Food to Bills reflects immediately in recalculated totals', () {
      final tx1 = model_tx.Transaction(id: '1', amount: 500, type: model_tx.TransactionType.expense, merchant: 'M1', category: 'food', date: DateTime(2026, 9, 1));
      final tx2 = model_tx.Transaction(id: '2', amount: 200, type: model_tx.TransactionType.expense, merchant: 'M2', category: 'bills', date: DateTime(2026, 9, 2));

      var list = [tx1, tx2];
      var totalsBefore = analyticsService.calculateCategoryTotals(list, month: 9, year: 2026);
      expect(totalsBefore['Food'], 500);
      expect(totalsBefore['Bills'], 200);

      // User changes tx1 from Food to Bills
      final updatedTx1 = tx1.copyWith(customCategory: 'bills', category: 'bills');
      list = [updatedTx1, tx2];

      var totalsAfter = analyticsService.calculateCategoryTotals(list, month: 9, year: 2026);
      expect(totalsAfter['Food'], 0);
      expect(totalsAfter['Bills'], 700);
    });

    test('14. Expense Cycle date range filtering only includes transactions within range', () {
      final range = DateTimeRange(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 7, 23, 59, 59),
      );

      final transactions = [
        model_tx.Transaction(id: 'in_range', amount: 300, type: model_tx.TransactionType.expense, merchant: 'Grocery', category: 'food', date: DateTime(2026, 9, 3)),
        model_tx.Transaction(id: 'out_of_range', amount: 900, type: model_tx.TransactionType.expense, merchant: 'Supermarket', category: 'shopping', date: DateTime(2026, 9, 15)),
      ];

      final totals = analyticsService.calculateCategoryTotals(transactions, range: range);
      expect(totals['Food'], 300);
      expect(totals['Shopping'], 0);
    });

    test('15. Title and Category are independent properties', () {
      var tx = model_tx.Transaction(
        id: 'tx_independent',
        amount: 600,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'others',
        date: DateTime(2026, 9, 1),
      );

      // Set custom title
      tx = tx.copyWith(customTitle: 'Amazon');
      expect(tx.displayTitle, 'Amazon');
      expect(tx.displayCategory, 'Others');

      // Set custom category
      tx = tx.copyWith(customCategory: 'shopping', category: 'shopping');
      expect(tx.displayTitle, 'Amazon');
      expect(tx.displayCategory, 'Shopping');

      // Change title
      tx = tx.copyWith(customTitle: 'Amazon India');
      expect(tx.displayTitle, 'Amazon India');
      expect(tx.displayCategory, 'Shopping');
    });
  });

  group('UI: Category Selection Widget & Dialog', () {
    testWidgets('TransactionDetailDialog renders editable Category row and opens selector', (tester) async {
      final repo = MockTransactionRepository();
      final tx = model_tx.Transaction(
        id: 'tx_ui_test',
        amount: 450,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'food',
        date: DateTime(2026, 9, 1),
      );
      await repo.addTransaction(tx);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => TransactionDetailDialog(
                      transaction: tx,
                      repository: repo,
                    ),
                  );
                },
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.text('Category'), findsWidgets);
      expect(find.text('Food'), findsWidgets);

      // Tap on Category container to open selector modal
      await tester.tap(find.text('Category').first);
      await tester.pumpAndSettle();

      expect(find.text('Select Category'), findsOneWidget);
      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Others'), findsOneWidget);

      // Select Shopping
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();

      // Verify category updated in dialog and in repository
      expect(find.text('Shopping'), findsWidgets);
      expect(repo.transactions['tx_ui_test']!.displayCategory, 'Shopping');
    });

    testWidgets('TransactionCard displays displayCategory', (tester) async {
      final tx = model_tx.Transaction(
        id: 'tx_card_test',
        amount: 800,
        type: model_tx.TransactionType.expense,
        merchant: 'KSEB',
        category: 'bills',
        date: DateTime(2026, 9, 1, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: tx),
          ),
        ),
      );

      expect(find.textContaining('Bills'), findsOneWidget);
    });
  });
}
