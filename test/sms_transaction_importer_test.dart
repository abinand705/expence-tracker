import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/repositories/pending_due_repository.dart';
import 'package:expense_tracker/models/pending_due.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/models/sms_recognition_rule.dart';
import 'package:expense_tracker/repositories/sms_rule_repository.dart';

class MockTransactionRepository implements TransactionRepository {
  final Map<String, model_tx.Transaction> transactions = {};

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPendingDueRepository implements PendingDueRepository {
  final Map<String, PendingDue> dues = {};

  @override
  Future<bool> addPendingDueIfAbsent(PendingDue due) async {
    if (dues.containsKey(due.id)) return false;
    dues[due.id] = due;
    return true;
  }

  @override
  Future<List<PendingDue>> getPendingDues() async {
    return dues.values.toList();
  }

  @override
  Future<void> deletePendingDue(String id) async {
    dues.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAccountRepository implements AccountRepository {
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

void main() {
  group('SmsTransactionImporter', () {
    late MockTransactionRepository repo;
    late MockPendingDueRepository dueRepo;
    late MockAccountRepository accRepo;
    late SmsRuleRepository ruleRepo;
    late SmsTransactionImporter importer;

    setUp(() {
      repo = MockTransactionRepository();
      dueRepo = MockPendingDueRepository();
      accRepo = MockAccountRepository();
      ruleRepo = SmsRuleRepository.inMemory();

      final defaultAccount = Account(
        id: 'acc_bank_a',
        name: 'BankA Savings',
        bankName: 'BankA',
        accountNumber: '1234',
        accountType: 'Savings',
        accentColor: const Color(0xFF000000),
        smsTrackingEnabled: true,
      );
      accRepo.accounts[defaultAccount.id] = defaultAccount;
      ruleRepo.addRule(SmsRecognitionRule(
        id: 'rule_bank_a',
        accountId: defaultAccount.id,
        ruleLabel: 'BankA Rule',
        accountIdentifier: '', // matches any SMS from BankA
        senderPatterns: ['BankA'],
        debitKeywords: const ['debited'],
        creditKeywords: const ['credited'],
        coversDebit: true,
        coversCredit: true,
        createdAt: DateTime.now(),
      ));

      importer = SmsTransactionImporter(
        transactionRepo: repo,
        pendingDueRepo: dueRepo,
        accountRepo: accRepo,
        ruleRepo: ruleRepo,
      );
    });

    test('imports valid expense sms', () async {
      final msg = Message(
        id: '1',
        text: 'Rs. 500 debited from a/c 1234 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'BankA');
      expect(result, SmsImportResult.imported);
      expect(repo.transactions.length, 1);
      
      final savedTx = repo.transactions.values.first;
      expect(savedTx.amount, 500.0);
      expect(savedTx.type, model_tx.TransactionType.expense);
    });

    test('imports valid income sms', () async {
      final msg = Message(
        id: '2',
        text: 'Rs. 5000 credited to a/c 1234 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'BankA');
      expect(result, SmsImportResult.imported);
      expect(repo.transactions.length, 1);
      
      final savedTx = repo.transactions.values.first;
      expect(savedTx.amount, 5000.0);
      expect(savedTx.type, model_tx.TransactionType.income);
    });

    test('prevents duplicate transactions with exactly same data', () async {
      final msg = Message(
        id: '3',
        text: 'Rs. 500 debited',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );

      final result1 = await importer.importMessage(msg, 'BankA');
      expect(result1, SmsImportResult.imported);

      final result2 = await importer.importMessage(msg, 'BankA');
      expect(result2, SmsImportResult.duplicate);

      expect(repo.transactions.length, 1);
    });

    test('allows same amount but different timestamps', () async {
      final msg1 = Message(
        id: '4',
        text: 'Rs. 500 debited',
        timestamp: DateTime(2026, 1, 1, 10, 0), // 10:00 AM
        isMe: false,
      );
      
      final msg2 = Message(
        id: '5',
        text: 'Rs. 500 debited',
        timestamp: DateTime(2026, 1, 1, 14, 0), // 2:00 PM
        isMe: false,
      );

      final result1 = await importer.importMessage(msg1, 'BankA');
      expect(result1, SmsImportResult.imported);

      final result2 = await importer.importMessage(msg2, 'BankA');
      expect(result2, SmsImportResult.imported);

      expect(repo.transactions.length, 2);
    });

    test('skips non-financial SMS', () async {
      final msg = Message(
        id: '6',
        text: 'Your OTP is 123456',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'BankA');
      expect(result, SmsImportResult.skipped);
      expect(repo.transactions.length, 0);
    });

    test('importAllBankMessages skips non-bank senders', () async {
      final conv = Conversation(
        id: 'c1',
        senderName: 'Alice',
        senderNumber: '123',
        avatarColor: const Color(0xFF000000),
        isBankSender: false,
        messages: [
          Message(
            id: 'm1',
            text: 'Rs. 500 debited',
            timestamp: DateTime.now(),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      expect(summary.scanned, 0);
      expect(summary.imported, 0);
      expect(repo.transactions.length, 0);
    });

    test('TEST 1 - Canonical mapping maps to random_uid', () async {
      final msg = Message(
        id: 'canonical_1',
        text: 'Rs. 500 debited from a/c 1234 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );
      final accounts = [
        Account(id: 'random_uid', name: 'HDFC', bankName: 'HDFC', accountNumber: '1234', accountType: 'Savings', accentColor: const Color(0xFF000000))
      ];
      final result = await importer.importMessage(msg, 'HDFC Bank', null, null, accounts);
      expect(result, SmsImportResult.imported);
      final savedTx = repo.transactions.values.last;
      expect(savedTx.accountId, 'random_uid');
    });

    test('TEST 2 - PendingDue mapping maps to random_uid', () async {
      final msg = Message(
        id: 'canonical_2',
        text: 'Upcoming EMI of Rs. 5000 due on 15-01-2026 from a/c 1234',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );
      final accounts = [
        Account(id: 'random_uid', name: 'HDFC', bankName: 'HDFC', accountNumber: '1234', accountType: 'Savings', accentColor: const Color(0xFF000000))
      ];
      final result = await importer.importMessage(msg, 'HDFC Bank', null, dueRepo, accounts);
      expect(result, SmsImportResult.imported);
      final savedDue = dueRepo.dues.values.last;
      expect(savedDue.accountId, 'random_uid');
    });

    test('TEST 4 - Ambiguous accounts leaves accountId null and skips SMS', () async {
      final msg = Message(
        id: 'canonical_4',
        text: 'Rs. 500 debited from a/c 1234 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );
      final accounts = [
        Account(id: 'acc1', name: 'HDFC1', bankName: 'HDFC', accountNumber: '1234', accountType: 'Savings', accentColor: const Color(0xFF000000)),
        Account(id: 'acc2', name: 'HDFC2', bankName: 'HDFC', accountNumber: '1234', accountType: 'Current', accentColor: const Color(0xFF000000))
      ];
      final result = await importer.importMessage(msg, 'HDFC Bank', null, null, accounts);
      expect(result, SmsImportResult.skipped);
    });

    test('TEST 5 - Different bank does not map and skips SMS', () async {
      final msg = Message(
        id: 'canonical_5',
        text: 'Rs. 500 debited from a/c 1234 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );
      final accounts = [
        Account(id: 'random_uid', name: 'SBI', bankName: 'SBI', accountNumber: '1234', accountType: 'Savings', accentColor: const Color(0xFF000000))
      ];
      // Detected bank is HDFC based on sender, existing account is SBI
      final result = await importer.importMessage(msg, 'HDFC Bank', null, null, accounts);
      expect(result, SmsImportResult.skipped);
    });

    test('3-digit suffix maps to registered account', () async {
      final msg = Message(
        id: 'msg_3digit',
        text: 'Rs 750 debited from account ending 123 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );
      final accounts = [
        Account(id: 'bob_123_uid', name: 'BOB', bankName: 'Bank of Baroda', accountNumber: '9876543123', accountType: 'Savings', accentColor: const Color(0xFF000000))
      ];
      final result = await importer.importMessage(msg, 'BOB Bank', null, null, accounts);
      expect(result, SmsImportResult.imported);
      final savedTx = repo.transactions.values.last;
      expect(savedTx.accountId, 'bob_123_uid');
    });

    test('5-digit suffix maps to registered account', () async {
      final msg = Message(
        id: 'msg_5digit',
        text: 'Rs 1200 debited from A/C XXXXX12345 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );
      final accounts = [
        Account(id: 'sbi_5digit_uid', name: 'SBI', bankName: 'State Bank of India', accountNumber: '0000012345', accountType: 'Savings', accentColor: const Color(0xFF000000))
      ];
      final result = await importer.importMessage(msg, 'SBI Bank', null, null, accounts);
      expect(result, SmsImportResult.imported);
      final savedTx = repo.transactions.values.last;
      expect(savedTx.accountId, 'sbi_5digit_uid');
    });

    test('3-digit pending due SIP format resolves account', () async {
      final msg = Message(
        id: 'sip_3digit',
        text: 'Rs 100.00 will be debited on 21 Aug 2026 from your 123-BANK OF BARODA for upcoming SIP #xxxxxxxx in HDFC Small Cap Fund. Ensure balance.',
        timestamp: DateTime(2026, 8, 20),
        isMe: false,
      );
      final accounts = [
        Account(id: 'bob_sip_acc', name: 'BOB', bankName: 'Bank of Baroda', accountNumber: '123', accountType: 'Savings', accentColor: const Color(0xFF000000))
      ];
      final result = await importer.importMessage(msg, 'BOB Bank', null, dueRepo, accounts);
      expect(result, SmsImportResult.imported);
      final savedDue = dueRepo.dues.values.last;
      expect(savedDue.accountId, 'bob_sip_acc');
      expect(savedDue.amount, 100.0);
    });

    test('Canara Bank bulk import resolves latest balance even when older messages exist', () async {
      final canaraAccount = Account(
        id: 'canara_acc',
        name: 'Canara Savings',
        bankName: 'Canara Bank',
        accountNumber: '99991234',
        accountType: 'Savings',
        accentColor: const Color(0xFF005DAA),
        smsTrackingEnabled: true,
      );
      accRepo.accounts['canara_acc'] = canaraAccount;
      ruleRepo.addRule(SmsRecognitionRule(
        id: 'canara_rule',
        accountId: 'canara_acc',
        ruleLabel: 'Canara Rule',
        accountIdentifier: '1234',
        senderPatterns: ['CANBNK', 'CANARA'],
        debitKeywords: const ['debited'],
        creditKeywords: const ['credited'],
        coversDebit: true,
        coversCredit: true,
        createdAt: DateTime.now(),
      ));

      // Messages in reverse chronological order (or out-of-order)
      final conv = Conversation(
        id: 'conv_canara',
        senderName: 'CANBNK',
        senderNumber: 'CANBNK',
        avatarColor: const Color(0xFF005DAA),
        isBankSender: true,
        messages: [
          // Newer message
          Message(
            id: 'msg_new',
            text: 'Canara Bank: Dear UPI user A/C XX1234 debited by 150.0 on date 08Sep26 trf to SWIGGY. Refno 123456789. Avl Bal Rs:14200.00',
            timestamp: DateTime(2026, 9, 8, 12, 0),
            isMe: false,
          ),
          // Older message with previous balance
          Message(
            id: 'msg_old',
            text: 'Your A/C XX1234 debited by Rs 500 on 01-08-2026. Available Balance:Rs.5000.00 - Canara Bank',
            timestamp: DateTime(2026, 8, 1, 10, 0),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      expect(summary.imported, 2);

      final updatedAcc = accRepo.accounts['canara_acc']!;
      expect(updatedAcc.currentBalance, 14200.00);
      expect(updatedAcc.balanceUpdatedAt, isNotNull);
      expect(updatedAcc.balanceUpdatedAt!.month, 9);
    });
  });
}
