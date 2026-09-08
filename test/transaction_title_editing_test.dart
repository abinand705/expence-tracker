import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/repositories/pending_due_repository.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/widgets/transaction_card.dart';
import 'package:expense_tracker/widgets/transaction_detail_dialog.dart';

class MockTransactionRepository implements TransactionRepository {
  final Map<String, model_tx.Transaction> transactions = {};
  final Map<String, Map<String, dynamic>> updateCalls = {};

  @override
  Future<List<model_tx.Transaction>> getTransactions() async {
    return transactions.values.toList();
  }

  @override
  Future<List<model_tx.Transaction>> getTransactionsForAccount(String accountId) async {
    return transactions.values.where((tx) => tx.accountId == accountId).toList();
  }

  @override
  Future<model_tx.Transaction?> getTransactionById(String id) async {
    return transactions[id];
  }

  @override
  Future<String> addTransaction(model_tx.Transaction transaction) async {
    transactions[transaction.id] = transaction;
    return transaction.id;
  }

  @override
  Future<bool> addTransactionIfAbsent(model_tx.Transaction transaction) async {
    if (transactions.containsKey(transaction.id)) {
      return false;
    }
    transactions[transaction.id] = transaction;
    return true;
  }

  @override
  Future<void> updateTransactionTitle(String transactionId, String? customTitle) async {
    updateCalls[transactionId] = {'customTitle': customTitle};
    if (transactions.containsKey(transactionId)) {
      final existing = transactions[transactionId]!;
      transactions[transactionId] = existing.copyWith(customTitle: customTitle);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPendingDueRepository implements PendingDueRepository {
  final Map<String, dynamic> dues = {};

  @override
  Future<bool> addPendingDueIfAbsent(dynamic due) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Transaction Title Editing & Persistence', () {
    late MockTransactionRepository repo;
    late MockPendingDueRepository dueRepo;

    setUp(() {
      repo = MockTransactionRepository();
      dueRepo = MockPendingDueRepository();
    });

    test('1. New transaction with customTitle = null displays parsed merchant', () {
      final tx = model_tx.Transaction(
        id: 'tx_1',
        amount: 250,
        type: model_tx.TransactionType.expense,
        merchant: 'Flipkart',
        category: 'Shopping',
        date: DateTime.now(),
      );
      expect(tx.displayTitle, 'Flipkart');
    });

    test('2. Transaction with customTitle = null and unknown merchant displays Unknown Merchant', () {
      final tx = model_tx.Transaction(
        id: 'tx_2',
        amount: 250,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: DateTime.now(),
      );
      expect(tx.displayTitle, 'Unknown Merchant');
    });

    test('3. Custom title overrides detected merchant in displayTitle', () {
      final tx = model_tx.Transaction(
        id: 'tx_3',
        amount: 250,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: DateTime.now(),
        customTitle: 'Amazon',
      );
      expect(tx.displayTitle, 'Amazon');
    });

    test('4. Empty or whitespace title clears custom title override', () {
      final tx = model_tx.Transaction(
        id: 'tx_4',
        amount: 250,
        type: model_tx.TransactionType.expense,
        merchant: 'Starbucks',
        category: 'Food',
        date: DateTime.now(),
        customTitle: '   ',
      );
      expect(tx.displayTitle, 'Starbucks');
    });

    test('5. updateTransactionTitle updates only customTitle and preserves other fields', () async {
      final originalDate = DateTime(2026, 9, 1, 10, 30);
      final tx = model_tx.Transaction(
        id: 'tx_5',
        amount: 250.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: originalDate,
        rawMessage: 'Paid Rs 250 to ...',
        accountId: 'acc_123',
        transactionSource: 'sms',
      );
      await repo.addTransaction(tx);

      // Update title: Unknown Merchant -> Amazon
      await repo.updateTransactionTitle('tx_5', 'Amazon');

      expect(repo.updateCalls['tx_5']?['customTitle'], 'Amazon');
      final updated = repo.transactions['tx_5']!;
      expect(updated.customTitle, 'Amazon');
      expect(updated.displayTitle, 'Amazon');
      // Preserved original fields
      expect(updated.amount, 250.0);
      expect(updated.date, originalDate);
      expect(updated.rawMessage, 'Paid Rs 250 to ...');
      expect(updated.accountId, 'acc_123');
      expect(updated.merchant, 'Unknown Merchant');
    });

    test('6. Changing title: Amazon -> Shopping modifies only customTitle', () async {
      final tx = model_tx.Transaction(
        id: 'tx_6',
        amount: 500.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: DateTime.now(),
        customTitle: 'Amazon',
      );
      await repo.addTransaction(tx);

      await repo.updateTransactionTitle('tx_6', 'Shopping');
      expect(repo.transactions['tx_6']!.customTitle, 'Shopping');
      expect(repo.transactions['tx_6']!.displayTitle, 'Shopping');
    });

    test('7. Removing title: Amazon -> empty string reverts customTitle to null', () async {
      final tx = model_tx.Transaction(
        id: 'tx_7',
        amount: 500.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: DateTime.now(),
        customTitle: 'Amazon',
      );
      await repo.addTransaction(tx);

      await repo.updateTransactionTitle('tx_7', null);
      expect(repo.transactions['tx_7']!.customTitle, isNull);
      expect(repo.transactions['tx_7']!.displayTitle, 'Unknown Merchant');
    });

    test('8. Repeated SMS scan preserves existing customTitle', () async {
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
        id: 'msg_repeat',
        text: 'Rs. 250 debited on 01-09-2026',
        timestamp: DateTime(2026, 9, 1),
        isMe: false,
      );

      // 1. Initial import
      final res1 = await importer.importMessage(msg, 'HDFC Bank', null, null, [hdfcAcc]);
      expect(res1, SmsImportResult.imported);
      final txId = repo.transactions.keys.first;

      // 2. User sets custom title to Amazon
      await repo.updateTransactionTitle(txId, 'Amazon');
      expect(repo.transactions[txId]!.customTitle, 'Amazon');

      // 3. Re-scan the same SMS
      final res2 = await importer.importMessage(msg, 'HDFC Bank', null, null, [hdfcAcc]);
      expect(res2, SmsImportResult.duplicate);

      // Verify custom title is still Amazon and original SMS is untouched
      expect(repo.transactions[txId]!.customTitle, 'Amazon');
      expect(repo.transactions[txId]!.displayTitle, 'Amazon');
      expect(repo.transactions[txId]!.rawMessage, 'Rs. 250 debited on 01-09-2026');
    });

    test('9. Deduplication: changing customTitle does not alter deterministic transaction ID', () async {
      final tx1 = model_tx.Transaction(
        id: 'sms_deterministic_hash_123',
        amount: 300,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: DateTime(2026, 9, 1),
        customTitle: 'Groceries',
      );
      await repo.addTransaction(tx1);

      await repo.updateTransactionTitle('sms_deterministic_hash_123', 'Supermarket');

      expect(repo.transactions.length, 1);
      expect(repo.transactions.containsKey('sms_deterministic_hash_123'), isTrue);
      expect(repo.transactions['sms_deterministic_hash_123']!.displayTitle, 'Supermarket');
    });

    test('10. Credit / Income transaction supports title editing', () async {
      final tx = model_tx.Transaction(
        id: 'tx_income',
        amount: 5000,
        type: model_tx.TransactionType.income,
        merchant: 'Unknown Merchant',
        category: 'Income',
        date: DateTime.now(),
        customTitle: 'Salary',
      );
      expect(tx.displayTitle, 'Salary');
      expect(tx.type, model_tx.TransactionType.income);
    });
  });

  group('UI: Transaction Details & Edit Title Dialog Widgets', () {
    testWidgets('TransactionCard displays displayTitle when customTitle is present', (tester) async {
      final tx = model_tx.Transaction(
        id: 'tx_card_1',
        amount: 250.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Food',
        date: DateTime(2026, 9, 1, 12, 0),
        customTitle: 'Amazon Cafe',
        rawMessage: 'Paid Rs 250 to Amazon Cafe',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: TransactionCard(transaction: tx),
          ),
        ),
      );

      expect(find.text('Amazon Cafe'), findsOneWidget);
      expect(find.text('Unknown Merchant'), findsNothing);
    });

    testWidgets('TransactionDetailDialog shows title, edit button, and original SMS in Dark Mode', (tester) async {
      final tx = model_tx.Transaction(
        id: 'tx_dialog_1',
        amount: 450.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Shopping',
        date: DateTime(2026, 9, 1, 14, 30),
        customTitle: 'Amazon',
        rawMessage: 'Paid Rs 450 to Amazon via UPI',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: TransactionDetailDialog(transaction: tx),
          ),
        ),
      );

      expect(find.text('Transaction Details'), findsOneWidget);
      expect(find.text('Amazon'), findsOneWidget);
      expect(find.text('Edit Title'), findsOneWidget);
      expect(find.text('Original Message'), findsOneWidget);
      expect(find.text('Paid Rs 450 to Amazon via UPI'), findsOneWidget);
    });

    testWidgets('EditTransactionTitleDialog pre-fills customTitle and trims on Save', (tester) async {
      final repo = MockTransactionRepository();
      final tx = model_tx.Transaction(
        id: 'tx_edit_1',
        amount: 150.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: DateTime.now(),
        customTitle: 'Amazon',
      );
      await repo.addTransaction(tx);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditTransactionTitleDialog(transaction: tx, repository: repo),
          ),
        ),
      );

      expect(find.text('Edit Transaction Title'), findsOneWidget);
      expect(find.text('Amazon'), findsOneWidget);

      // Enter new title
      final textField = find.byType(TextField);
      await tester.enterText(textField, '  Flipkart  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.updateCalls['tx_edit_1']?['customTitle'], 'Flipkart');
    });
  });
}
