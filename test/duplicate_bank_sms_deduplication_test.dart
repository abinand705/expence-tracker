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
  group('Bank SMS Deduplication & Identity System', () {
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

    test('1. Same reference ID produces exactly ONE transaction', () async {
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

    test('2. Different reference IDs remain separate transactions even with same amount and time', () async {
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

    test('3. No reference ID, identical timestamp -> 1 transaction', () async {
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

    test('4. No reference ID, timestamp difference within 5s window -> 1 transaction', () async {
      final msgA = Message(
        id: 'sms_msg_301',
        text: 'Rs 250 spent on card/ac ending 544 at 20:21:36.',
        timestamp: DateTime(2026, 9, 1, 20, 21, 36),
        isMe: false,
      );
      final msgB = Message(
        id: 'sms_msg_302',
        text: 'Rs 250 debited from your A/c 544 at 20:21:38.',
        timestamp: DateTime(2026, 9, 1, 20, 21, 38),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    test('5. No reference ID, timestamp difference outside tolerance (> 5s) -> 2 transactions', () async {
      final msgA = Message(
        id: 'sms_msg_401',
        text: 'Rs 250 debited from A/c XX544 at 11:00:00.',
        timestamp: DateTime(2026, 9, 1, 11, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'sms_msg_402',
        text: 'Rs 250 debited from A/c XX544 at 11:01:00.',
        timestamp: DateTime(2026, 9, 1, 11, 1, 0),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.imported);
      expect(txRepo.transactions.length, 2);
    });

    test('6. Same amount but different accounts -> 2 transactions', () async {
      final secondAccount = Account(
        id: 'acc_sbi_890',
        name: 'SBI Savings',
        bankName: 'State Bank of India',
        accountNumber: 'XXXXXX890',
        accountType: 'Savings',
        balance: 5000.0,
        currentBalance: 5000.0,
        currency: 'INR',
        accentColor: const Color(0xFF1976D2),
        createdAt: DateTime(2026, 1, 1),
      );
      accRepo.accounts[secondAccount.id] = secondAccount;

      final msgA = Message(
        id: 'sms_msg_501',
        text: 'Rs 500 debited from HDFC A/c XX544 on 01-Sep-2026 12:00:00.',
        timestamp: DateTime(2026, 9, 1, 12, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'sms_msg_502',
        text: 'Rs 500 debited from SBI A/c XX890 on 01-Sep-2026 12:00:00.',
        timestamp: DateTime(2026, 9, 1, 12, 0, 0),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'SBIBANK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.imported);
      expect(txRepo.transactions.length, 2);
    });

    test('7. Same transaction with different SMS IDs -> 1 transaction', () async {
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

    test('8. Duplicate SMS must NOT double-update account balance', () async {
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
      // Balance MUST still be 9500, not 9000!
      expect(accRepo.accounts[baseAccount.id]!.currentBalance, 9500.0);
    });

    test('9. Duplicate SMS must not double-count Dashboard expenses', () async {
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

    test('10. Custom Category preservation when duplicate SMS arrives', () async {
      final msgA = Message(
        id: 'msg_cat_1',
        text: 'Rs 800 debited from A/c XX544 for Shopping. Ref 990011.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 0),
        isMe: false,
      );

      await importer.importMessage(msgA, 'HDFCBK');
      final txId = txRepo.transactions.keys.first;

      // User sets category to Food
      await txRepo.updateTransactionCategory(txId, 'food');
      expect(txRepo.transactions[txId]!.displayCategory, 'Food');

      // Duplicate SMS arrives
      final msgB = Message(
        id: 'msg_cat_2',
        text: 'Rs 800 debited from A/c XX544 for Shopping. Ref 990011.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 1),
        isMe: false,
      );
      await importer.importMessage(msgB, 'HDFCBK');

      expect(txRepo.transactions[txId]!.displayCategory, 'Food');
    });

    test('11. Custom Title preservation when duplicate SMS arrives', () async {
      final msgA = Message(
        id: 'msg_title_1',
        text: 'Rs 600 debited from A/c XX544. Ref 445566.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 0),
        isMe: false,
      );

      await importer.importMessage(msgA, 'HDFCBK');
      final txId = txRepo.transactions.keys.first;

      // User customizes title to "Amazon India"
      await txRepo.updateTransactionTitle(txId, 'Amazon India');
      expect(txRepo.transactions[txId]!.displayTitle, 'Amazon India');

      // Duplicate SMS arrives
      final msgB = Message(
        id: 'msg_title_2',
        text: 'Rs 600 debited from A/c XX544. Ref 445566.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 2),
        isMe: false,
      );
      await importer.importMessage(msgB, 'HDFCBK');

      expect(txRepo.transactions[txId]!.displayTitle, 'Amazon India');
    });

    test('12. Repeated SMS batch rescan is strictly idempotent', () async {
      final conv = Conversation(
        id: 'conv_hdfc_test',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: const Color(0xFF004B8D),
        messages: [
          Message(id: '1', text: 'Rs 100 debited from A/c XX544. Ref 1001.', timestamp: DateTime(2026, 9, 1, 10, 0), isMe: false),
          Message(id: '2', text: 'Rs 200 debited from A/c XX544. Ref 1002.', timestamp: DateTime(2026, 9, 1, 11, 0), isMe: false),
          Message(id: '3', text: 'Rs 300 debited from A/c XX544. Ref 1003.', timestamp: DateTime(2026, 9, 1, 12, 0), isMe: false),
          // Duplicate message in batch
          Message(id: '4', text: 'Rs 100 debited from A/c XX544. Ref 1001.', timestamp: DateTime(2026, 9, 1, 10, 0, 2), isMe: false),
        ],
        isBankSender: true,
      );

      // 1. First scan
      final summary1 = await importer.importAllBankMessages([conv]);
      expect(summary1.imported, 3);
      expect(summary1.duplicates, 1);
      expect(txRepo.transactions.length, 3);

      // 2. Second scan of exact same conversations
      final summary2 = await importer.importAllBankMessages([conv]);
      expect(summary2.imported, 0);
      expect(summary2.duplicates, 4);
      expect(txRepo.transactions.length, 3);
    });

    test('13. Two legitimate transactions with different refs count full sum', () async {
      final msgA = Message(
        id: 'legit_1',
        text: 'Rs 500 debited from A/c XX544. Ref A1.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'legit_2',
        text: 'Rs 500 debited from A/c XX544. Ref B2.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 1),
        isMe: false,
      );

      await importer.importMessage(msgA, 'HDFCBK');
      await importer.importMessage(msgB, 'HDFCBK');

      expect(txRepo.transactions.length, 2);
      final analytics = AnalyticsService();
      final total = analytics.calculateTotalExpenses(await txRepo.getTransactions());
      expect(total, 1000.0);
    });

    test('14. Account matching resolves to existing canonical account without unknown account creation', () async {
      final msg = Message(
        id: 'acc_test_1',
        text: 'Rs 750 debited from A/c ending in 544 on 01-Sep-2026.',
        timestamp: DateTime(2026, 9, 1, 10, 0, 0),
        isMe: false,
      );

      await importer.importMessage(msg, 'HDFC Bank');
      final tx = txRepo.transactions.values.first;

      expect(tx.accountId, 'acc_hdfc_544');
      expect(accRepo.accounts.length, 1); // No new unknown account created
    });
  });
}
