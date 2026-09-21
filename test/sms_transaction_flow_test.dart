import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/models/transaction_group.dart';
import 'package:expense_tracker/models/pending_due.dart';
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/repositories/pending_due_repository.dart';
import 'package:expense_tracker/repositories/transaction_group_repository.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/widgets/transaction_card.dart';

class FakeTxRepo implements TransactionRepository {
  final Map<String, model_tx.Transaction> transactions = {};
  final _controller = StreamController<List<model_tx.Transaction>>.broadcast();

  void _notify() {
    final list = transactions.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    _controller.add(list);
  }

  @override
  void setInstancesForTesting(FirebaseFirestore firestore, FirebaseAuth auth) {}

  @override
  Future<String> addTransaction(model_tx.Transaction tx) async {
    transactions[tx.id] = tx;
    _notify();
    return tx.id;
  }

  @override
  Future<bool> addTransactionIfAbsent(model_tx.Transaction tx) async {
    if (transactions.containsKey(tx.id)) return false;
    transactions[tx.id] = tx;
    _notify();
    return true;
  }

  @override
  Future<void> updateTransaction(model_tx.Transaction tx) async {
    transactions[tx.id] = tx;
    _notify();
  }

  @override
  Future<void> deleteTransaction(String id) async {
    transactions.remove(id);
    _notify();
  }

  @override
  Future<List<model_tx.Transaction>> getTransactions() async {
    final list = transactions.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<List<model_tx.Transaction>> getTransactionsForAccount(String accountId) async {
    return transactions.values.where((t) => t.accountId == accountId).toList();
  }

  @override
  Future<model_tx.Transaction?> getTransactionById(String id) async => transactions[id];

  @override
  Stream<List<model_tx.Transaction>> watchTransactions() {
    return _controller.stream;
  }

  @override
  Future<void> batchAddTransactions(List<model_tx.Transaction> txs) async {
    for (final t in txs) {
      transactions[t.id] = t;
    }
    _notify();
  }

  @override
  Future<void> updateTransactionCategory(String transactionId, String category) async {
    if (transactions.containsKey(transactionId)) {
      transactions[transactionId] = transactions[transactionId]!.copyWith(
        category: category,
      );
      _notify();
    }
  }

  @override
  Future<void> updateTransactionTitle(String transactionId, String? title) async {
    if (transactions.containsKey(transactionId)) {
      transactions[transactionId] = transactions[transactionId]!.copyWith(
        customTitle: title,
      );
      _notify();
    }
  }

  void dispose() {
    _controller.close();
  }
}

class FakeAccountRepo implements AccountRepository {
  final List<Account> _accounts = [];

  void setAccounts(List<Account> accs) {
    _accounts.clear();
    _accounts.addAll(accs);
  }

  @override
  void setInstancesForTesting(FirebaseFirestore firestore, FirebaseAuth auth) {}

  @override
  Stream<List<Account>> watchAccounts() => Stream.value(_accounts);

  @override
  Future<List<Account>> getAccounts() async => List.from(_accounts);

  @override
  Future<Account?> getAccountById(String id) async {
    return _accounts.where((a) => a.id == id).firstOrNull;
  }

  @override
  Future<String> addAccount(Account account) async {
    _accounts.add(account);
    return account.id;
  }

  @override
  Future<bool> addAccountIfAbsent(Account account) async {
    if (_accounts.any((a) => a.id == account.id)) return false;
    _accounts.add(account);
    return true;
  }

  @override
  Future<void> updateAccount(Account account) async {
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx != -1) {
      _accounts[idx] = account;
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
  }

  @override
  Future<int> migrateAndCleanupAutoDiscoveredAccounts() async => 0;

  @override
  Future<void> cleanupLegacyAutoDiscoveredAccounts(String canonicalAccountId, String bankId, String last4) async {}
}

class FakeGroupRepo extends TransactionGroupRepository {
  final List<TransactionGroup> savedGroups = [];

  @override
  Future<void> batchSaveGroups(List<TransactionGroup> groups) async {
    savedGroups.addAll(groups);
  }
}

class FakePendingDueRepo implements PendingDueRepository {
  final List<PendingDue> dues = [];

  @override
  Stream<List<PendingDue>> watchPendingDues() => Stream.value(dues);

  @override
  Future<bool> addPendingDueIfAbsent(PendingDue due) async {
    if (dues.any((d) => d.id == due.id)) return false;
    dues.add(due);
    return true;
  }

  @override
  Future<void> deletePendingDue(String id) async {
    dues.removeWhere((d) => d.id == id);
  }

  @override
  Future<List<PendingDue>> getPendingDues() async => List.from(dues);
}

void main() {
  group('MoneyTrack — SMS Transaction Flow & Visibility Tests', () {
    late FakeTxRepo txRepo;
    late FakeAccountRepo accountRepo;
    late FakeGroupRepo groupRepo;
    late FakePendingDueRepo dueRepo;
    late SmsTransactionImporter importer;

    setUp(() {
      txRepo = FakeTxRepo();
      accountRepo = FakeAccountRepo();
      groupRepo = FakeGroupRepo();
      dueRepo = FakePendingDueRepo();
      importer = SmsTransactionImporter(
        transactionRepo: txRepo,
        accountRepo: accountRepo,
        groupRepo: groupRepo,
        pendingDueRepo: dueRepo,
      );
    });

    tearDown(() {
      txRepo.dispose();
    });

    test('1. End-to-End: Representative Bank SMS with unresolved account flows through to transactions', () async {
      const smsText = '₹500.00 debited from A/c XX1234 on 21-Sep-2026. UPI Ref 123456789.';
      final msg = Message(
        id: 'sms_101',
        text: smsText,
        timestamp: DateTime(2026, 9, 21, 14, 30),
        isMe: false,
      );

      // No accounts configured
      accountRepo.setAccounts([]);

      // Import the message
      final result = await importer.importMessage(msg, 'HDFCBK');
      expect(result, SmsImportResult.imported);

      // Verify transaction is in repository
      final allTxs = await txRepo.getTransactions();
      expect(allTxs.length, 1);

      final tx = allTxs.first;
      expect(tx.amount, 500.00);
      expect(tx.type, model_tx.TransactionType.expense);
      expect(tx.upiReference, '123456789');
      expect(tx.accountId, isNull); // Unresolved account is preserved safely
      expect(tx.transactionSource, 'sms');
    });

    test('2. Bulk import: Bank messages are parsed and imported even when zero accounts have SMS tracking enabled', () async {
      final conversations = [
        Conversation(
          id: 'HDFCBK',
          senderName: 'HDFCBK',
          senderNumber: 'HDFCBK',
          avatarColor: Colors.blue,
          isBankSender: true,
          messages: [
            Message(
              id: 'm1',
              text: 'Rs 1,500.00 spent on Card ending 4321 at Amazon on 21-Sep-2026. Avl Bal Rs 20,000.',
              timestamp: DateTime(2026, 9, 21, 10, 0),
              isMe: false,
            ),
            Message(
              id: 'm2',
              text: 'Rs 300.00 debited from A/c 4321 for Swiggy on 21-Sep-2026.',
              timestamp: DateTime(2026, 9, 21, 12, 0),
              isMe: false,
            ),
          ],
        ),
      ];

      // No accounts enabled
      accountRepo.setAccounts([]);

      final summary = await importer.importAllBankMessages(conversations);
      expect(summary.scanned, 2);
      expect(summary.imported, 2);

      final stored = await txRepo.getTransactions();
      expect(stored.length, 2);
      expect(stored.any((t) => t.amount == 1500.0), isTrue);
      expect(stored.any((t) => t.amount == 300.0), isTrue);
    });

    test('3. Deduplication: Identical SMS message is not imported twice', () async {
      const smsText = '₹750.00 debited from A/c XX9999 at Cafe on 21-Sep-2026. UPI Ref 987654321.';
      final msg = Message(
        id: 'sms_dup_1',
        text: smsText,
        timestamp: DateTime(2026, 9, 21, 15, 0),
        isMe: false,
      );

      final result1 = await importer.importMessage(msg, 'SBIBANK');
      expect(result1, SmsImportResult.imported);

      // Repeat import of the exact same message
      final result2 = await importer.importMessage(msg, 'SBIBANK');
      expect(result2, SmsImportResult.duplicate);

      final list = await txRepo.getTransactions();
      expect(list.length, 1);
    });

    test('4. Manual and SMS transactions coexist in the transaction stream', () async {
      // 1. Add manual expense
      final manualTx = model_tx.Transaction(
        id: 'manual_1',
        merchant: 'Cash Groceries',
        amount: 350.0,
        type: model_tx.TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 9, 21, 9, 0),
        isManual: true,
      );
      await txRepo.addTransaction(manualTx);

      // 2. Add manual income
      final incomeTx = model_tx.Transaction(
        id: 'income_1',
        merchant: 'Freelance Bonus',
        amount: 10000.0,
        type: model_tx.TransactionType.income,
        category: 'Income',
        date: DateTime(2026, 9, 21, 8, 0),
        isManual: true,
      );
      await txRepo.addTransaction(incomeTx);

      // 3. Import SMS expense
      final smsMsg = Message(
        id: 'sms_tx_2',
        text: 'Rs. 250.00 debited from A/c XX1234 at Bakery on 21-Sep-2026. UPI Ref 555666.',
        timestamp: DateTime(2026, 9, 21, 16, 0),
        isMe: false,
      );
      await importer.importMessage(smsMsg, 'HDFCBK');

      final allTxs = await txRepo.getTransactions();
      expect(allTxs.length, 3);
      expect(allTxs.any((t) => t.isManual && t.type == model_tx.TransactionType.expense), isTrue);
      expect(allTxs.any((t) => t.isManual && t.type == model_tx.TransactionType.income), isTrue);
      expect(allTxs.any((t) => !t.isManual && t.amount == 250.0), isTrue);
    });

    testWidgets('5. TransactionCard renders unresolved account SMS transaction correctly', (tester) async {
      final tx = model_tx.Transaction(
        id: 'tx_unresolved',
        merchant: 'Swiggy',
        amount: 450.0,
        type: model_tx.TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 9, 21, 13, 0),
        subtitle: 'HDFCBK',
        accountId: null,
        transactionSource: 'sms',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: tx),
          ),
        ),
      );

      expect(find.text('Swiggy'), findsOneWidget);
      expect(find.textContaining('HDFCBK'), findsOneWidget);
      expect(find.text('-₹ 450'), findsOneWidget);
    });
  });
}
