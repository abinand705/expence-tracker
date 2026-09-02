import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/services/sms_account_resolver.dart';
import 'package:expense_tracker/services/bank_detection_service.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/repositories/pending_due_repository.dart';
import 'package:expense_tracker/models/pending_due.dart';

class MockTransactionRepo implements TransactionRepository {
  final Map<String, model_tx.Transaction> transactions = {};

  @override
  Future<model_tx.Transaction?> getTransactionById(String id) async => transactions[id];

  @override
  Future<String> addTransaction(model_tx.Transaction transaction) async {
    transactions[transaction.id] = transaction;
    return transaction.id;
  }

  @override
  Future<bool> addTransactionIfAbsent(model_tx.Transaction transaction) async {
    if (transactions.containsKey(transaction.id)) return false;
    transactions[transaction.id] = transaction;
    return true;
  }

  @override
  Future<List<model_tx.Transaction>> getTransactions() async => transactions.values.toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPendingDueRepo implements PendingDueRepository {
  final Map<String, PendingDue> dues = {};

  @override
  Future<bool> addPendingDueIfAbsent(PendingDue due) async {
    if (dues.containsKey(due.id)) return false;
    dues[due.id] = due;
    return true;
  }

  @override
  Future<List<PendingDue>> getPendingDues() async => dues.values.toList();

  @override
  Future<void> deletePendingDue(String id) async => dues.remove(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('3-Digit SMS Account Matching Specification Tests', () {
    late SmsAccountResolver resolver;
    late BankDefinition bobBank;
    late BankDefinition hdfcBank;

    setUp(() {
      resolver = SmsAccountResolver();
      bobBank = BankDefinition(
        id: 'bob',
        displayName: 'Bank of Baroda',
        senderPatterns: ['bobsms', 'bob', 'baroda'],
        contentPatterns: ['bank of baroda', 'bob', 'baroda'],
        accentColor: Colors.orange,
      );
      hdfcBank = BankDefinition(
        id: 'hdfc',
        displayName: 'HDFC Bank',
        senderPatterns: ['hdfcbk', 'hdfc'],
        contentPatterns: ['hdfc bank'],
        accentColor: Colors.blue,
      );
    });

    test('Test 1: Existing BOB XXXX0711 + SMS BOB XXXX0711 -> match existing Account.id', () {
      final accounts = [
        Account(
          id: 'bob_real_acc_id',
          name: 'My BOB Savings',
          bankName: 'Bank of Baroda',
          accountNumber: 'XXXX0711',
          accountType: 'Savings',
          accentColor: Colors.orange,
        ),
      ];

      final resolvedId = resolver.resolveAccountId(
        sender: 'BOBSMS',
        messageText: 'Rs. 500 debited from A/C XXXX0711 at Amazon',
        bank: bobBank,
        existingAccounts: accounts,
      );

      expect(resolvedId, 'bob_real_acc_id');
    });

    test('Test 2: Existing BOB XXXX0711 + SMS BOB XXX711 -> match existing Account.id', () {
      final accounts = [
        Account(
          id: 'bob_real_acc_id',
          name: 'My BOB Savings',
          bankName: 'Bank of Baroda',
          accountNumber: 'XXXX0711',
          accountType: 'Savings',
          accentColor: Colors.orange,
        ),
      ];

      final resolvedId = resolver.resolveAccountId(
        sender: 'BOBSMS',
        messageText: 'Rs. 500 debited from A/C XXX711 at Flipkart',
        bank: bobBank,
        existingAccounts: accounts,
      );

      expect(resolvedId, 'bob_real_acc_id');
    });

    test('Test 3: Existing BOB XXXX0711 + SMS "from your 0711-BANK OF BARODA" -> last3=711 -> match', () {
      final accounts = [
        Account(
          id: 'bob_real_acc_id',
          name: 'My BOB Savings',
          bankName: 'Bank of Baroda',
          accountNumber: 'XXXX0711',
          accountType: 'Savings',
          accentColor: Colors.orange,
        ),
      ];

      final resolvedId = resolver.resolveAccountId(
        sender: 'BOBSMS',
        messageText: 'Rs 100.00 will be debited on 21 Aug 2026 from your 0711-BANK OF BARODA for upcoming SIP',
        bank: bobBank,
        existingAccounts: accounts,
      );

      expect(resolvedId, 'bob_real_acc_id');
    });

    test('Test 4: Existing BOB XXXX0711 + SMS "account ending 711" -> match if unique', () {
      final accounts = [
        Account(
          id: 'bob_real_acc_id',
          name: 'My BOB Savings',
          bankName: 'Bank of Baroda',
          accountNumber: 'XXXX0711',
          accountType: 'Savings',
          accentColor: Colors.orange,
        ),
      ];

      // SMS without explicit bank in sender
      final resolvedId = resolver.resolveAccount(
        bankIdOrName: null,
        rawAccountOrSuffix: '711',
        accounts: accounts,
      );

      expect(resolvedId, 'bob_real_acc_id');
    });

    test('Test 5: Existing BOB XXXX711 and HDFC XXXX711 + SMS "account ending 711" -> ambiguous without bank -> accountId = null, with bank -> matches', () {
      final accounts = [
        Account(
          id: 'bob_acc_1',
          name: 'BOB Account',
          bankName: 'Bank of Baroda',
          accountNumber: 'XXXX711',
          accountType: 'Savings',
          accentColor: Colors.orange,
        ),
        Account(
          id: 'hdfc_acc_1',
          name: 'HDFC Account',
          bankName: 'HDFC Bank',
          accountNumber: 'XXXX711',
          accountType: 'Savings',
          accentColor: Colors.blue,
        ),
      ];

      // Without bank: ambiguous between BOB and HDFC
      final resolvedWithoutBank = resolver.resolveAccount(
        bankIdOrName: null,
        rawAccountOrSuffix: '711',
        accounts: accounts,
      );
      expect(resolvedWithoutBank, isNull);

      // With HDFC bank: resolves unambiguously to hdfc_acc_1
      final resolvedWithBank = resolver.resolveAccountId(
        sender: 'HDFCBK',
        messageText: 'Rs 500 debited from account ending 711',
        bank: hdfcBank,
        existingAccounts: accounts,
      );
      expect(resolvedWithBank, 'hdfc_acc_1');
    });

    test('Test 6: No existing account matches -> accountId = null -> NO new Unknown account', () {
      final accounts = [
        Account(
          id: 'other_acc_id',
          name: 'Other Bank',
          bankName: 'Other Bank',
          accountNumber: 'XXXX9999',
          accountType: 'Savings',
          accentColor: Colors.grey,
        ),
      ];

      final resolvedId = resolver.resolveAccountId(
        sender: 'BOBSMS',
        messageText: 'Rs. 500 debited from A/C XXXX0711 at Amazon',
        bank: bobBank,
        existingAccounts: accounts,
      );

      expect(resolvedId, isNull);
    });

    test('Test 7: Existing real account + existing auto-discovered duplicate -> resolve to real account', () {
      final accounts = [
        Account(
          id: 'real_user_account_id',
          name: 'Salary Account',
          bankName: 'Bank of Baroda',
          accountNumber: '1234567890711',
          accountType: 'Savings',
          isAutoDiscovered: false,
          accentColor: Colors.orange,
        ),
      ];

      final resolvedId = resolver.resolveAccountId(
        sender: 'BOBSMS',
        messageText: 'Rs 1,000 debited from A/C XXXX0711',
        bank: bobBank,
        existingAccounts: accounts,
      );

      expect(resolvedId, 'real_user_account_id');
    });

    test('Repeated SMS scanning preserves transactions and never creates duplicate or unknown accounts', () async {
      final txRepo = MockTransactionRepo();
      final dueRepo = MockPendingDueRepo();
      final importer = SmsTransactionImporter(transactionRepo: txRepo, pendingDueRepo: dueRepo);

      final accounts = [
        Account(
          id: 'bob_canonical_id',
          name: 'Main BOB Account',
          bankName: 'Bank of Baroda',
          accountNumber: '1234560711',
          accountType: 'Savings',
          accentColor: Colors.orange,
        ),
      ];

      final msg = Message(
        id: 'msg_repeat_1',
        text: 'Rs. 450 debited from A/C XXXX0711 at Starbucks on 10-08-2026',
        timestamp: DateTime(2026, 8, 10, 15, 30),
        isMe: false,
      );

      // Scan 1
      final res1 = await importer.importMessage(msg, 'BOB Bank', resolver, dueRepo, accounts);
      expect(res1, SmsImportResult.imported);
      expect(txRepo.transactions.length, 1);
      expect(txRepo.transactions.values.first.accountId, 'bob_canonical_id');

      // Scan 2 to 10 (repeated scans)
      for (int i = 0; i < 10; i++) {
        final resRepeat = await importer.importMessage(msg, 'BOB Bank', resolver, dueRepo, accounts);
        expect(resRepeat, SmsImportResult.duplicate);
      }

      // Assert count is still exactly 1 transaction and account mapping is unchanged
      expect(txRepo.transactions.length, 1);
      expect(txRepo.transactions.values.first.accountId, 'bob_canonical_id');
    });
  });
}
