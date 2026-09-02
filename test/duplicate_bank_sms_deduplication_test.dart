import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/pending_due.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/repositories/pending_due_repository.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/services/analytics_service.dart';
import 'package:expense_tracker/services/transaction_identity_service.dart';
import 'package:expense_tracker/utils/expense_parser.dart';

class MockTxRepo implements TransactionRepository {
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
  Future<void> updateTransaction(model_tx.Transaction tx) async {
    transactions[tx.id] = tx;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    transactions.remove(id);
  }

  @override
  Future<List<model_tx.Transaction>> getTransactions() async {
    final list = transactions.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<List<model_tx.Transaction>> getTransactionsForAccount(String accountId) async {
    return transactions.values.where((t) => t.accountId == accountId).toList();
  }

  @override
  Future<model_tx.Transaction?> getTransactionById(String id) async => transactions[id];

  @override
  Future<void> updateTransactionCategory(String transactionId, String category) async {
    if (transactions.containsKey(transactionId)) {
      final normalized = model_tx.TransactionCategory.normalize(category);
      transactions[transactionId] = transactions[transactionId]!.copyWith(
        customCategory: normalized,
        category: normalized,
      );
    }
  }

  @override
  Future<void> updateTransactionTitle(String transactionId, String? customTitle) async {
    if (transactions.containsKey(transactionId)) {
      transactions[transactionId] = transactions[transactionId]!.copyWith(
        customTitle: customTitle,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAccRepo implements AccountRepository {
  final Map<String, Account> accounts = {};

  @override
  Future<List<Account>> getAccounts() async => accounts.values.toList();

  @override
  Future<Account?> getAccountById(String id) async => accounts[id];

  @override
  Future<void> updateAccount(Account account) async {
    accounts[account.id] = account;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDueRepo implements PendingDueRepository {
  @override
  Future<bool> addPendingDueIfAbsent(PendingDue due) async => true;

  @override
  Future<List<PendingDue>> getPendingDues() async => [];

  @override
  Future<void> deletePendingDue(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Bank SMS Deduplication & Conservative Identity System', () {
    late MockTxRepo txRepo;
    late MockAccRepo accRepo;
    late MockDueRepo dueRepo;
    late SmsTransactionImporter importer;

    final baseAccount = Account(
      id: 'acc_hdfc_544',
      name: 'HDFC Salary',
      bankName: 'HDFC Bank',
      accountNumber: 'XXXXXX544',
      accountType: 'Savings',
      balance: 10000.0,
      currentBalance: 10000.0,
      currency: 'INR',
      accentColor: const Color(0xFF004B8D),
      createdAt: DateTime(2026, 1, 1),
    );

    setUp(() {
      txRepo = MockTxRepo();
      accRepo = MockAccRepo();
      dueRepo = MockDueRepo();
      accRepo.accounts[baseAccount.id] = baseAccount;

      importer = SmsTransactionImporter(
        transactionRepo: txRepo,
        accountRepo: accRepo,
        pendingDueRepo: dueRepo,
      );
    });

    test('TEST 1: Same reference ID produces exactly ONE transaction', () async {
      final msgA = Message(
        id: 'sms_msg_001',
        text: 'Rs 500.00 debited from A/c XX544 on 01-Sep-2026 10:32:15 for Amazon. Ref 458921.',
        timestamp: DateTime(2026, 9, 1, 10, 32, 15),
        isMe: false,
      );
      final msgB = Message(
        id: 'sms_msg_002',
        text: 'HDFC Bank: Rs 500.00 debited from account ending 544 at 10:32:15 on 01-09-2026. Txn Ref: 458921.',
        timestamp: DateTime(2026, 9, 1, 10, 32, 16),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFC-Bank');
      expect(resA, SmsImportResult.imported);
      expect(txRepo.transactions.length, 1);

      final resB = await importer.importMessage(msgB, 'HDFCBK');
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    test('TEST 2: Different reference IDs remain separate transactions even with same amount and time', () async {
      final msgA = Message(
        id: 'sms_msg_101',
        text: 'Rs 500 debited from A/c XX544 at 10:30:01. Ref 12345.',
        timestamp: DateTime(2026, 9, 1, 10, 30, 1),
        isMe: false,
      );
      final msgB = Message(
        id: 'sms_msg_102',
        text: 'Rs 500 debited from A/c XX544 at 10:30:03. Ref 12346.',
        timestamp: DateTime(2026, 9, 1, 10, 30, 3),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.imported);
      expect(txRepo.transactions.length, 2);
    });

    test('TEST 3: Same SMS processed twice -> 1 transaction', () async {
      final msgA = Message(
        id: 'sms_msg_exact',
        text: 'Rs 150 debited from A/c XX544 on 02-09-2026 09:00:00. Ref 8899.',
        timestamp: DateTime(2026, 9, 2, 9, 0, 0),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgA, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    test('TEST 4: Different SMS IDs but same reference ID -> 1 transaction', () async {
      final msgA = Message(
        id: 'carrier_id_99991',
        text: 'Rs 1200 debited from A/c XX544. UPI Ref: 987654321.',
        timestamp: DateTime(2026, 9, 1, 15, 30, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'carrier_id_99992',
        text: 'Rs 1200 debited from A/c XX544. UPI Ref: 987654321.',
        timestamp: DateTime(2026, 9, 1, 15, 30, 2),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    test('TEST 5: No reference ID + identical timestamp -> 1 transaction', () async {
      final msgA = Message(
        id: 'sms_msg_201',
        text: 'Rs 300 debited from A/c XX544 on 01-09-2026 14:00:00 for Tea Stall.',
        timestamp: DateTime(2026, 9, 1, 14, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'sms_msg_202',
        text: 'Rs 300 debited from A/c XX544 on 01-09-2026 14:00:00 for Tea Stall.',
        timestamp: DateTime(2026, 9, 1, 14, 0, 0),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    test('TEST 6: Ambiguous Case A - ₹40 debit at 08:38:01 vs ₹40 debit at 08:38:04 no reference IDs -> MUST NOT blindly merge (remain 2 transactions)', () async {
      final msgA = Message(
        id: 'case_a_1',
        text: 'Rs 40 debited from A/c XX544 on 02-09-2026 08:38:01.',
        timestamp: DateTime(2026, 9, 2, 8, 38, 1),
        isMe: false,
      );
      final msgB = Message(
        id: 'case_a_2',
        text: 'Rs 40 debited from A/c XX544 on 02-09-2026 08:38:04.',
        timestamp: DateTime(2026, 9, 2, 8, 38, 4),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.imported);
      expect(txRepo.transactions.length, 2);
    });

    test('TEST 7: Ambiguous Case B - ₹40 debit at 08:38:01 Ref 12345 vs ₹40 debit at 08:38:04 Ref 12346 -> MUST remain TWO transactions', () async {
      final msgA = Message(
        id: 'case_b_1',
        text: 'Rs 40 debited from A/c XX544 on 02-09-2026 08:38:01. Ref 12345.',
        timestamp: DateTime(2026, 9, 2, 8, 38, 1),
        isMe: false,
      );
      final msgB = Message(
        id: 'case_b_2',
        text: 'Rs 40 debited from A/c XX544 on 02-09-2026 08:38:04. Ref 12346.',
        timestamp: DateTime(2026, 9, 2, 8, 38, 4),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.imported);
      expect(txRepo.transactions.length, 2);
    });

    test('TEST 8: Ambiguous Case C - ₹40 debit at 08:38:01 Ref 12345 vs ₹40 debit at 08:38:04 Ref 12345 -> ONE transaction', () async {
      final msgA = Message(
        id: 'case_c_1',
        text: 'Rs 40 debited from A/c XX544 on 02-09-2026 08:38:01. Ref 12345.',
        timestamp: DateTime(2026, 9, 2, 8, 38, 1),
        isMe: false,
      );
      final msgB = Message(
        id: 'case_c_2',
        text: 'Rs 40 debited from A/c XX544 on 02-09-2026 08:38:04. Ref 12345.',
        timestamp: DateTime(2026, 9, 2, 8, 38, 4),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    test('TEST 9: Ambiguous Case D - Exact same SMS content but different SMS message IDs -> ONE transaction', () async {
      final msgA = Message(
        id: 'carrier_msg_1001',
        text: 'Rs 200 debited from A/c XX544 on 02-09-2026 07:45:00 for Cafe.',
        timestamp: DateTime(2026, 9, 2, 7, 45, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'carrier_msg_1002',
        text: 'Rs 200 debited from A/c XX544 on 02-09-2026 07:45:00 for Cafe.',
        timestamp: DateTime(2026, 9, 2, 7, 45, 0),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    test('TEST 10: Ambiguous Case E - Slightly different SMS wording but same reliable reference ID + account -> ONE transaction', () async {
      final msgA = Message(
        id: 'msg_e_1',
        text: 'Rs 40 debited from A/c XX544. Ref 123456.',
        timestamp: DateTime(2026, 9, 2, 8, 38, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'msg_e_2',
        text: 'Your account XX544 has been debited by Rs 40. Transaction Ref 123456.',
        timestamp: DateTime(2026, 9, 2, 8, 38, 3),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    test('TEST 11: Duplicate transaction must change balance only once', () async {
      expect(accRepo.accounts[baseAccount.id]!.currentBalance, 10000.0);

      final msgA = Message(
        id: 'msg_bal_1',
        text: 'Rs 500 debited from A/c XX544. Ref 778899.',
        timestamp: DateTime(2026, 9, 1, 16, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'msg_bal_2',
        text: 'Rs 500 debited from A/c XX544. Ref 778899.',
        timestamp: DateTime(2026, 9, 1, 16, 0, 1),
        isMe: false,
      );

      await importer.importMessage(msgA, 'HDFCBK');
      expect(accRepo.accounts[baseAccount.id]!.currentBalance, 9500.0);

      await importer.importMessage(msgB, 'HDFCBK');
      expect(accRepo.accounts[baseAccount.id]!.currentBalance, 9500.0);
    });

    test('TEST 12: Duplicate transaction must affect Dashboard only once', () async {
      final msgA = Message(
        id: 'msg_dash_1',
        text: 'Rs 450 debited from A/c XX544 for Dinner. Ref 112233.',
        timestamp: DateTime(2026, 9, 1, 19, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'msg_dash_2',
        text: 'Rs 450 debited from A/c XX544 for Dinner. Ref 112233.',
        timestamp: DateTime(2026, 9, 1, 19, 0, 1),
        isMe: false,
      );

      await importer.importMessage(msgA, 'HDFCBK');
      await importer.importMessage(msgB, 'HDFCBK');

      final analytics = AnalyticsService();
      final txs = await txRepo.getTransactions();
      final totalSpend = analytics.calculateTotalExpenses(txs, month: 9, year: 2026);
      final catTotals = analytics.calculateCategoryTotals(txs, month: 9, year: 2026);

      expect(totalSpend, 450.0);
      expect(catTotals['Food'] ?? 0, 450.0);
    });

    test('TEST 13: Duplicate transaction appears only once in transaction collection', () async {
      final msgA = Message(
        id: 'msg_row_1',
        text: 'Rs 2 debited from A/c XX544 on 02-09-2026 09:23:00. Ref 223344.',
        timestamp: DateTime(2026, 9, 2, 9, 23, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'msg_row_2',
        text: 'Rs 2 debited from A/c XX544 on 02-09-2026 09:23:00. Ref 223344.',
        timestamp: DateTime(2026, 9, 2, 9, 23, 0),
        isMe: false,
      );

      await importer.importMessage(msgA, 'HDFCBK');
      await importer.importMessage(msgB, 'HDFCBK');

      final txs = await txRepo.getTransactions();
      expect(txs.length, 1);
      expect(txs.first.amount, 2.0);
    });

    test('TEST 14: Custom category survives duplicate processing', () async {
      final msgA = Message(
        id: 'msg_cat_1',
        text: 'Rs 800 debited from A/c XX544 for Shopping. Ref 990011.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 0),
        isMe: false,
      );

      await importer.importMessage(msgA, 'HDFCBK');
      final txId = txRepo.transactions.keys.first;

      await txRepo.updateTransactionCategory(txId, 'food');
      expect(txRepo.transactions[txId]!.displayCategory, 'Food');

      final msgB = Message(
        id: 'msg_cat_2',
        text: 'Rs 800 debited from A/c XX544 for Shopping. Ref 990011.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 1),
        isMe: false,
      );
      await importer.importMessage(msgB, 'HDFCBK');

      expect(txRepo.transactions[txId]!.displayCategory, 'Food');
    });

    test('TEST 15: Custom title survives duplicate processing', () async {
      final msgA = Message(
        id: 'msg_title_1',
        text: 'Rs 600 debited from A/c XX544. Ref 445566.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 0),
        isMe: false,
      );

      await importer.importMessage(msgA, 'HDFCBK');
      final txId = txRepo.transactions.keys.first;

      await txRepo.updateTransactionTitle(txId, 'Amazon India');
      expect(txRepo.transactions[txId]!.displayTitle, 'Amazon India');

      final msgB = Message(
        id: 'msg_title_2',
        text: 'Rs 600 debited from A/c XX544. Ref 445566.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 2),
        isMe: false,
      );
      await importer.importMessage(msgB, 'HDFCBK');

      expect(txRepo.transactions[txId]!.displayTitle, 'Amazon India');
    });

    test('TEST 16: Repeated SMS scan remains idempotent', () async {
      final conv = Conversation(
        id: 'conv_hdfc_test',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: const Color(0xFF004B8D),
        messages: [
          Message(id: '1', text: 'Rs 100 debited from A/c XX544. Ref 1001.', timestamp: DateTime(2026, 9, 1, 10, 0), isMe: false),
          Message(id: '2', text: 'Rs 200 debited from A/c XX544. Ref 1002.', timestamp: DateTime(2026, 9, 1, 11, 0), isMe: false),
          Message(id: '3', text: 'Rs 300 debited from A/c XX544. Ref 1003.', timestamp: DateTime(2026, 9, 1, 12, 0), isMe: false),
          Message(id: '4', text: 'Rs 100 debited from A/c XX544. Ref 1001.', timestamp: DateTime(2026, 9, 1, 10, 0, 2), isMe: false),
        ],
        isBankSender: true,
      );

      final summary1 = await importer.importAllBankMessages([conv]);
      expect(summary1.imported, 3);
      expect(summary1.duplicates, 1);
      expect(txRepo.transactions.length, 3);

      final summary2 = await importer.importAllBankMessages([conv]);
      expect(summary2.imported, 0);
      expect(summary2.duplicates, 4);
      expect(txRepo.transactions.length, 3);
    });

    test('TEST 17: Existing account ending in 544 is reused without creating unknown account', () async {
      final msg = Message(
        id: 'acc_test_1',
        text: 'Rs 750 debited from A/c ending in 544 on 01-Sep-2026. Ref 5566.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 0),
        isMe: false,
      );

      await importer.importMessage(msg, 'HDFC Bank');
      final tx = txRepo.transactions.values.first;

      expect(tx.accountId, 'acc_hdfc_544');
      expect(accRepo.accounts.length, 1);
    });

    test('TEST 18: Safe Duplicate Cleanup plan identifies duplicates and preserves user fields', () {
      final tx1 = model_tx.Transaction(
        id: 'tx_dup_1',
        amount: 40.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'others',
        date: DateTime(2026, 9, 2, 8, 38, 0),
        accountId: 'acc_hdfc_544',
        accountNumber: '544',
        upiReference: '458921',
        createdAt: DateTime(2026, 9, 2, 8, 38, 0),
      );

      final tx2 = model_tx.Transaction(
        id: 'tx_dup_2',
        amount: 40.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Tea Stall',
        category: 'food',
        customCategory: 'food',
        customTitle: 'Morning Tea',
        notes: 'Special chai',
        date: DateTime(2026, 9, 2, 8, 38, 0),
        accountId: 'acc_hdfc_544',
        accountNumber: '544',
        upiReference: '458921',
        createdAt: DateTime(2026, 9, 2, 8, 38, 1),
      );

      final plan = TransactionIdentityService.planDuplicateCleanup([tx1, tx2]);

      expect(plan.duplicatesFound, 1);
      expect(plan.duplicateIdsToDelete, contains('tx_dup_2'));
      expect(plan.transactionsToUpdate.length, 1);

      final updatedCanonical = plan.transactionsToUpdate.first;
      expect(updatedCanonical.id, 'tx_dup_1');
      expect(updatedCanonical.customTitle, 'Morning Tea');
      expect(updatedCanonical.customCategory, 'food');
      expect(updatedCanonical.notes, 'Special chai');
    });

    test('TEST 19: Safe Duplicate Cleanup leaves distinct valid transactions untouched', () {
      final tx1 = model_tx.Transaction(
        id: 'tx_1',
        amount: 40.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Shop A',
        category: 'shopping',
        date: DateTime(2026, 9, 2, 8, 38, 1),
        accountId: 'acc_hdfc_544',
        upiReference: '12345',
      );

      final tx2 = model_tx.Transaction(
        id: 'tx_2',
        amount: 40.0,
        type: model_tx.TransactionType.expense,
        merchant: 'Shop B',
        category: 'shopping',
        date: DateTime(2026, 9, 2, 8, 38, 4),
        accountId: 'acc_hdfc_544',
        upiReference: '12346',
      );

      final plan = TransactionIdentityService.planDuplicateCleanup([tx1, tx2]);

      expect(plan.duplicatesFound, 0);
      expect(plan.duplicateIdsToDelete, isEmpty);
      expect(plan.transactionsToUpdate, isEmpty);
    });

    test('TEST 20: Reference ID regex extraction covers common formats correctly', () {
      final samples = [
        ('Ref 123456', '123456'),
        ('Ref: 123456', '123456'),
        ('Ref No: 123456', '123456'),
        ('Reference: 123456', '123456'),
        ('Txn Ref: 123456', '123456'),
        ('Txn ID: 123456', '123456'),
        ('Transaction ID: 123456', '123456'),
        ('UPI Ref: 123456', '123456'),
        ('UPI Ref No: 123456', '123456'),
        ('UTR: 123456789012', '123456789012'),
      ];

      for (final sample in samples) {
        final parsed = ExpenseParser.extractMessageId('Rs 100 debited from A/c XX544. ${sample.$1}');
        expect(parsed, sample.$2, reason: 'Failed for pattern: ${sample.$1}');
      }
    });
  });
}

