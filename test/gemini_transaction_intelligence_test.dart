import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/pending_due.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/models/sms_recognition_rule.dart';
import 'package:expense_tracker/models/transaction_group.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/repositories/transaction_group_repository.dart';
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/repositories/pending_due_repository.dart';
import 'package:expense_tracker/repositories/sms_rule_repository.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/services/transaction_matcher.dart';
import 'package:expense_tracker/services/gemini_transaction_service.dart';
import 'package:expense_tracker/services/gemini_config_service.dart';
import 'package:expense_tracker/services/transaction_decision_validator.dart';
import 'package:expense_tracker/services/transaction_group_resolver.dart';
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

class MockGroupRepo implements TransactionGroupRepository {
  final Map<String, TransactionGroup> groups = {};

  @override
  Future<void> saveGroup(TransactionGroup group) async {
    groups[group.groupId] = group;
  }

  @override
  Future<void> batchSaveGroups(List<TransactionGroup> list) async {
    for (final g in list) {
      groups[g.groupId] = g;
    }
  }

  @override
  Future<List<TransactionGroup>> getPendingReviewGroups() async {
    return groups.values
        .where((g) => g.status == TransactionGroupStatus.pendingReview)
        .toList();
  }

  @override
  Stream<List<TransactionGroup>> watchPendingReviewGroups() {
    return Stream.value(
      groups.values
          .where((g) => g.status == TransactionGroupStatus.pendingReview)
          .toList(),
    );
  }

  @override
  Future<void> updateGroupStatus(String groupId, TransactionGroupStatus status) async {
    if (groups.containsKey(groupId)) {
      groups[groupId] = groups[groupId]!.copyWith(status: status);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gemini AI Transaction Intelligence & SMS Deduplication Tests', () {
    late MockTxRepo txRepo;
    late MockAccRepo accRepo;
    late MockDueRepo dueRepo;
    late MockGroupRepo groupRepo;
    late SmsRuleRepository ruleRepo;
    late GeminiConfigService configService;

    final baseAccount = Account(
      id: 'acc_hdfc_1234',
      name: 'HDFC Salary',
      bankName: 'HDFC Bank',
      accountNumber: 'XXXXXX1234',
      accountType: 'Savings',
      balance: 10000.0,
      currentBalance: 10000.0,
      currency: 'INR',
      accentColor: const Color(0xFF004B8D),
      smsTrackingEnabled: true,
      createdAt: DateTime(2026, 1, 1),
    );

    final secondAccount = Account(
      id: 'acc_sbi_5678',
      name: 'SBI Savings',
      bankName: 'State Bank of India',
      accountNumber: 'XXXXXX5678',
      accountType: 'Savings',
      balance: 5000.0,
      currentBalance: 5000.0,
      currency: 'INR',
      accentColor: const Color(0xFF1A5276),
      smsTrackingEnabled: true,
      createdAt: DateTime(2026, 1, 1),
    );

    setUp(() {
      txRepo = MockTxRepo();
      accRepo = MockAccRepo();
      dueRepo = MockDueRepo();
      groupRepo = MockGroupRepo();
      ruleRepo = SmsRuleRepository.inMemory();
      configService = GeminiConfigService();

      accRepo.accounts[baseAccount.id] = baseAccount;
      accRepo.accounts[secondAccount.id] = secondAccount;

      ruleRepo.addRule(SmsRecognitionRule(
        id: 'rule_hdfc_1234',
        accountId: baseAccount.id,
        ruleLabel: 'HDFC Rule',
        accountIdentifier: '1234',
        senderPatterns: ['HDFC', 'HDFCBK', 'HDFC-Bank', 'HDFC Bank'],
        debitKeywords: const ['debited', 'spent', 'paid', 'purchase'],
        creditKeywords: const ['credited', 'received', 'deposited'],
        coversDebit: true,
        coversCredit: true,
        createdAt: DateTime.now(),
      ));

      ruleRepo.addRule(SmsRecognitionRule(
        id: 'rule_sbi_5678',
        accountId: secondAccount.id,
        ruleLabel: 'SBI Rule',
        accountIdentifier: '5678',
        senderPatterns: ['SBI', 'SBINB', 'SBI Bank'],
        debitKeywords: const ['debited', 'spent', 'paid', 'purchase'],
        creditKeywords: const ['credited', 'received', 'deposited'],
        coversDebit: true,
        coversCredit: true,
        createdAt: DateTime.now(),
      ));
    });

    SmsTransactionImporter createImporter({GeminiApiCaller? mockCaller}) {
      final geminiService = GeminiTransactionService(
        configService: configService,
        mockCaller: mockCaller,
      );

      return SmsTransactionImporter(
        transactionRepo: txRepo,
        accountRepo: accRepo,
        pendingDueRepo: dueRepo,
        ruleRepo: ruleRepo,
        groupRepo: groupRepo,
        geminiService: geminiService,
        matcher: const TransactionMatcher(timeWindow: Duration(minutes: 5)),
        validator: const TransactionDecisionValidator(),
        resolver: const TransactionGroupResolver(),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1 — Exact duplicate SMS: Same SMS scanned twice -> One transaction
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 1 — Exact duplicate SMS scanned twice results in ONE transaction', () async {
      final importer = createImporter();
      final msg = Message(
        id: 'sms_exact_1',
        text: 'Rs.500 debited from A/c XX1234 on 21-Sep-2026 12:30:00 for AMAZON.',
        timestamp: DateTime(2026, 9, 21, 12, 30, 0),
        isMe: false,
      );

      final res1 = await importer.importMessage(msg, 'HDFCBK');
      final res2 = await importer.importMessage(msg, 'HDFCBK');

      expect(res1, SmsImportResult.imported);
      expect(res2, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2 — Multiple SMS for one transaction -> One transaction
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 2 — Three different bank SMS messages describing one ₹500 transaction -> ONE transaction', () async {
      final importer = createImporter(
        mockCaller: (prompt) async => jsonEncode({
          "classification": "SAME_TRANSACTION",
          "confidence": 0.98,
          "groupCandidateIds": ["c1", "c2", "c3"],
          "reason": "All messages describe the same debit of Rs 500 for account 1234",
          "canonicalCandidateId": "c3",
        }),
      );

      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'm1',
            text: 'Rs.500 debited from A/c XX1234 on 21-09-2026 12:31:00.',
            timestamp: DateTime(2026, 9, 21, 12, 31, 0),
            isMe: false,
          ),
          Message(
            id: 'm2',
            text: 'Your A/c XX1234 has been debited by Rs.500 on 21-09-2026 12:32:00. Available balance Rs.8500',
            timestamp: DateTime(2026, 9, 21, 12, 32, 0),
            isMe: false,
          ),
          Message(
            id: 'm3',
            text: 'UPI transaction of Rs.500 to AMAZON successful. UPI Ref 123456789 from A/c XX1234 on 21-09-2026 12:33:00.',
            timestamp: DateTime(2026, 9, 21, 12, 33, 0),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      expect(summary.imported, 1);
      expect(txRepo.transactions.length, 1);
      expect(txRepo.transactions.values.first.amount, 500.0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3 — Same amount but different transactions -> Two transactions
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 3 — Same amount but different transactions (Amazon vs Flipkart) -> TWO transactions', () async {
      final importer = createImporter();
      final msgA = Message(
        id: 'msg_amz',
        text: 'Rs.500 debited from A/c XX1234 on 21-09-2026 10:00:00 for AMAZON.',
        timestamp: DateTime(2026, 9, 21, 10, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'msg_fkrt',
        text: 'Rs.500 debited from A/c XX1234 on 21-09-2026 10:20:00 for FLIPKART.',
        timestamp: DateTime(2026, 9, 21, 10, 20, 0),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.imported);
      expect(txRepo.transactions.length, 2);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4 — Same amount and same account but different merchants
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 4 — Same amount and same account but different merchants -> do not merge automatically', () async {
      final importer = createImporter();
      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'm1',
            text: 'Rs.500 debited from A/c XX1234 on 21-09-2026 11:00:00 for Swiggy.',
            timestamp: DateTime(2026, 9, 21, 11, 0, 0),
            isMe: false,
          ),
          Message(
            id: 'm2',
            text: 'Rs.500 debited from A/c XX1234 on 21-09-2026 11:02:00 for Zomato.',
            timestamp: DateTime(2026, 9, 21, 11, 2, 0),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      expect(summary.imported, 2);
      expect(txRepo.transactions.length, 2);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5 — Payment initiated + successful -> One transaction/lifecycle
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 5 — Payment initiated + successful -> ONE transaction/lifecycle', () async {
      final importer = createImporter();
      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'init_1',
            text: 'UPI payment of Rs 500 initiated from A/c XX1234 on 21-09-2026 13:00:00 for Uber.',
            timestamp: DateTime(2026, 9, 21, 13, 0, 0),
            isMe: false,
          ),
          Message(
            id: 'succ_1',
            text: 'UPI payment of Rs 500 successful from A/c XX1234 on 21-09-2026 13:00:30 for Uber.',
            timestamp: DateTime(2026, 9, 21, 13, 0, 30),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      expect(summary.imported, 1);
      expect(txRepo.transactions.length, 1);
      expect(txRepo.transactions.values.first.amount, 500.0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6 — Payment reversed -> Correct reversal handling
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 6 — Payment reversed -> Correct reversal handling (no extra expense created)', () async {
      final importer = createImporter();
      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'deb_1',
            text: 'Rs 500.00 debited from A/c XX1234 on 21-09-2026 14:00:00 for Store. Ref 8899.',
            timestamp: DateTime(2026, 9, 21, 14, 0, 0),
            isMe: false,
          ),
          Message(
            id: 'rev_1',
            text: 'Rs 500.00 reversed to A/c XX1234 on 21-09-2026 14:01:00 for Store. Ref 8899.',
            timestamp: DateTime(2026, 9, 21, 14, 1, 0),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      expect(summary.imported, 1);
      expect(txRepo.transactions.length, 1);
      expect(txRepo.transactions.values.first.notes, contains('reversed'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 7 — Refund -> Correct credit/refund handling
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 7 — Refund processed -> Correct credit/refund handling', () async {
      final importer = createImporter();
      final msg = Message(
        id: 'ref_msg_1',
        text: 'Rs 500.00 credited to A/c XX1234 on 21-09-2026 15:00:00. Refund from Amazon Pay.',
        timestamp: DateTime(2026, 9, 21, 15, 0, 0),
        isMe: false,
      );

      final res = await importer.importMessage(msg, 'HDFCBK');
      expect(res, SmsImportResult.imported);
      expect(txRepo.transactions.length, 1);
      expect(txRepo.transactions.values.first.type, model_tx.TransactionType.income);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 8 — Balance SMS -> No expense created
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 8 — Informational balance SMS -> No expense created', () async {
      final importer = createImporter();
      final msg = Message(
        id: 'bal_msg_1',
        text: 'Dear Customer, available balance for your A/c XX1234 is Rs.14,500.50 on 21-09-2026.',
        timestamp: DateTime(2026, 9, 21, 16, 0, 0),
        isMe: false,
      );

      final res = await importer.importMessage(msg, 'HDFCBK');
      expect(res, SmsImportResult.skipped);
      expect(txRepo.transactions.length, 0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 9 — Gemini unavailable -> Continues using deterministic processing
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 9 — Gemini unavailable/offline -> Application continues using deterministic processing', () async {
      final importer = createImporter(
        mockCaller: (prompt) async => throw Exception('Network timeout / quota exceeded'),
      );

      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'exact_ref_1',
            text: 'Rs.300 debited from A/c XX1234. UPI Ref 99887766.',
            timestamp: DateTime(2026, 9, 21, 17, 0, 0),
            isMe: false,
          ),
          Message(
            id: 'exact_ref_2',
            text: 'HDFC Bank: Rs.300 debited from account ending 1234. Ref: 99887766.',
            timestamp: DateTime(2026, 9, 21, 17, 0, 2),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      // Level 1 deterministic exact reference matches even when AI throws!
      expect(summary.imported, 1);
      expect(txRepo.transactions.length, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 10 — Gemini invalid JSON -> No crash and safe fallback
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 10 — Gemini returns invalid JSON -> No crash and safe fallback', () async {
      final importer = createImporter(
        mockCaller: (prompt) async => 'NOT_VALID_JSON_RESPONSE {{{',
      );

      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'amb_1',
            text: 'Rs.450 debited from A/c XX1234 on 21-09-2026 18:00:00.',
            timestamp: DateTime(2026, 9, 21, 18, 0, 0),
            isMe: false,
          ),
          Message(
            id: 'amb_2',
            text: 'Rs.450 debited from A/c XX1234 on 21-09-2026 18:00:05.',
            timestamp: DateTime(2026, 9, 21, 18, 0, 5),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      // Should not crash, and falls back to separate transactions
      expect(summary.failed, 0);
      expect(txRepo.transactions.length, 2);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 11 — Unknown account -> No random account assignment
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 11 — Unknown/unmatched account -> No random account assignment or transaction created', () async {
      final importer = createImporter();
      final msg = Message(
        id: 'unknown_acc_msg',
        text: 'Rs.1000 debited from A/c XX9999 at 19:00:00.',
        timestamp: DateTime(2026, 9, 21, 19, 0, 0),
        isMe: false,
      );

      final res = await importer.importMessage(msg, 'SOMEBANK');
      expect(res, SmsImportResult.imported);
      expect(txRepo.transactions.length, 1);
      expect(txRepo.transactions.values.first.accountId, isNull);
      expect(accRepo.accounts.containsKey('acc_9999'), false);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 12 — Same UPI reference -> One transaction
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 12 — Different SMS with same UPI reference -> ONE transaction', () async {
      final importer = createImporter();
      final msgA = Message(
        id: 'sms_upi_a',
        text: 'Paid Rs 750 to Zomato from A/c XX1234. UPI Ref: 33445566.',
        timestamp: DateTime(2026, 9, 21, 20, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'sms_upi_b',
        text: 'Rs 750 debited from HDFC A/c XX1234 towards Zomato. UPI Ref 33445566.',
        timestamp: DateTime(2026, 9, 21, 20, 0, 5),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.duplicate);
      expect(txRepo.transactions.length, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 13 — Two genuine transactions with identical amounts
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 13 — Two genuine transactions with identical amounts -> TWO transactions', () async {
      final importer = createImporter();
      final msgA = Message(
        id: 'tx_genuine_1',
        text: 'Rs.250 debited from A/c XX1234 for Coffee Shop. Ref 1111.',
        timestamp: DateTime(2026, 9, 21, 09, 0, 0),
        isMe: false,
      );
      final msgB = Message(
        id: 'tx_genuine_2',
        text: 'Rs.250 debited from A/c XX1234 for Bakery. Ref 2222.',
        timestamp: DateTime(2026, 9, 21, 09, 0, 30),
        isMe: false,
      );

      final resA = await importer.importMessage(msgA, 'HDFCBK');
      final resB = await importer.importMessage(msgB, 'HDFCBK');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.imported);
      expect(txRepo.transactions.length, 2);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 14 — Different banks -> Do not merge merely because amount is equal
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 14 — Different banks -> Do not merge merely because amount is equal', () async {
      final importer = createImporter();
      final msgHdfc = Message(
        id: 'hdfc_msg_500',
        text: 'Rs.500 debited from HDFC Bank A/c XX1234 on 21-09-2026 12:00:00.',
        timestamp: DateTime(2026, 9, 21, 12, 0, 0),
        isMe: false,
      );
      final msgSbi = Message(
        id: 'sbi_msg_500',
        text: 'Rs.500 debited from State Bank of India A/c XX5678 on 21-09-2026 12:00:00.',
        timestamp: DateTime(2026, 9, 21, 12, 0, 0),
        isMe: false,
      );

      final resA = await importer.importMessage(msgHdfc, 'HDFCBK');
      final resB = await importer.importMessage(msgSbi, 'SBINB');

      expect(resA, SmsImportResult.imported);
      expect(resB, SmsImportResult.imported);
      expect(txRepo.transactions.length, 2);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 15 — Historical rescan -> Repeated scans do not increase totals
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 15 — Historical rescan repeatedly does not increase expense totals', () async {
      final importer = createImporter();
      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'hist_1',
            text: 'Rs 1500 debited from A/c XX1234 on 15-09-2026 10:00:00 for Groceries.',
            timestamp: DateTime(2026, 9, 15, 10, 0, 0),
            isMe: false,
          ),
          Message(
            id: 'hist_2',
            text: 'Rs 300 debited from A/c XX1234 on 16-09-2026 11:00:00 for Fuel.',
            timestamp: DateTime(2026, 9, 16, 11, 0, 0),
            isMe: false,
          ),
        ],
      );

      final scan1 = await importer.importAllBankMessages([conv]);
      expect(scan1.imported, 2);
      expect(txRepo.transactions.length, 2);

      final scan2 = await importer.importAllBankMessages([conv]);
      expect(scan2.imported, 0);
      expect(scan2.duplicates, 2);
      expect(txRepo.transactions.length, 2);

      // Dashboard calculation check
      final analytics = AnalyticsService();
      final totalExpenses = analytics.calculateTotalExpenses(txRepo.transactions.values.toList());
      expect(totalExpenses, 1800.0);
    });
  });
}
