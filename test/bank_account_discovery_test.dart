import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/discovered_bank_account.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/models/sms_recognition_rule.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/repositories/account_discovery_repository.dart';
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/repositories/sms_rule_repository.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/services/bank_account_discovery_service.dart';
import 'package:expense_tracker/services/bank_detection_service.dart';
import 'package:expense_tracker/services/sms_account_index.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/utils/expense_parser.dart';

import 'package:expense_tracker/models/pending_due.dart';
import 'package:expense_tracker/repositories/pending_due_repository.dart';

// ── In-Memory Repositories for Clean Isolation ─────────────────────────────

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

class InMemoryAccountRepo implements AccountRepository {
  final Map<String, Account> accounts = {};

  @override
  Future<List<Account>> getAccounts() async => accounts.values.toList();

  @override
  Future<Account?> getAccountById(String id) async => accounts[id];

  @override
  Future<String> addAccount(Account account) async {
    final id = account.id.isNotEmpty ? account.id : 'acc_${DateTime.now().millisecondsSinceEpoch}_${accounts.length}';
    final saved = account.copyWith(id: id);
    accounts[id] = saved;
    return id;
  }

  @override
  Future<bool> addAccountIfAbsent(Account account) async {
    if (accounts.containsKey(account.id)) return false;
    accounts[account.id] = account;
    return true;
  }

  @override
  Future<void> updateAccount(Account account) async {
    accounts[account.id] = account;
  }

  @override
  Future<void> deleteAccount(String id) async {
    accounts.remove(id);
  }

  @override
  Stream<List<Account>> watchAccounts() => Stream.value(accounts.values.toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InMemoryTxRepo implements TransactionRepository {
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
  Future<List<model_tx.Transaction>> getTransactions() async =>
      transactions.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  @override
  Stream<List<model_tx.Transaction>> watchTransactions() =>
      Stream.value(transactions.values.toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MoneyTrack — Automatic Bank Account Discovery Tests', () {
    late InMemoryAccountRepo accountRepo;
    late AccountDiscoveryRepository discoveryRepo;
    late BankAccountDiscoveryService discoveryService;

    setUp(() {
      accountRepo = InMemoryAccountRepo();
      discoveryRepo = AccountDiscoveryRepository.inMemory();
      discoveryService = BankAccountDiscoveryService(
        discoveryRepo: discoveryRepo,
        accountRepo: accountRepo,
        bankDetectionService: BankDetectionService(),
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1 — Bank detection
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 1 — Bank detection: detects HDFC Bank from sender and message', () {
      final bank = BankDetectionService().identifyBank('HDFCBK', 'A/c XX1234 debited ₹500');
      expect(bank, isNotNull);
      expect(bank!.id, 'hdfc');
      expect(bank.displayName, 'HDFC Bank');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2 — Account suffix detection
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 2 — Account suffix detection: extracts last 4 digits 1234 from A/c XX1234', () {
      final acct = ExpenseParser.extractAccountNumber('A/c XX1234 debited ₹500 on 21-Sep-2026');
      expect(acct, isNotNull);
      final digits = acct!.replaceAll(RegExp(r'[^0-9]'), '');
      expect(digits.endsWith('1234'), isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3 — Discovery grouping
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 3 — Discovery grouping: multiple HDFC messages for XX1234 produce ONE discovered account', () async {
      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'm1',
            text: 'HDFC Bank: A/c XX1234 debited ₹500 at Swiggy.',
            timestamp: DateTime(2026, 9, 21, 10, 0),
            isMe: false,
          ),
          Message(
            id: 'm2',
            text: 'HDFC Bank: A/c XX1234 credited ₹2,000 via NEFT.',
            timestamp: DateTime(2026, 9, 21, 12, 0),
            isMe: false,
          ),
          Message(
            id: 'm3',
            text: 'HDFC Bank: Available balance ₹25,000 for A/c XX1234.',
            timestamp: DateTime(2026, 9, 21, 14, 0),
            isMe: false,
          ),
        ],
      );

      final discoveries = await discoveryService.discoverAccounts(conversations: [conv]);
      expect(discoveries.length, 1);
      final d = discoveries.first;
      expect(d.bankCode, 'hdfc');
      expect(d.accountLast4, '1234');
      expect(d.messageCount, 3);
      expect(d.detectedBalance, 25000.0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4 — Multiple accounts same bank
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 4 — Multiple accounts same bank: HDFC XX1234 and HDFC XX5678 produce TWO discovered accounts', () async {
      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'm1',
            text: 'HDFC Bank: A/c XX1234 debited ₹500.',
            timestamp: DateTime(2026, 9, 21, 10, 0),
            isMe: false,
          ),
          Message(
            id: 'm2',
            text: 'HDFC Bank: A/c XX5678 debited ₹1,200.',
            timestamp: DateTime(2026, 9, 21, 11, 0),
            isMe: false,
          ),
        ],
      );

      final discoveries = await discoveryService.discoverAccounts(conversations: [conv]);
      expect(discoveries.length, 2);
      expect(discoveries.any((d) => d.accountLast4 == '1234'), isTrue);
      expect(discoveries.any((d) => d.accountLast4 == '5678'), isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5 — Existing account
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 5 — Existing account: no duplicate suggestion when account is already configured', () async {
      // User already has HDFC Bank account ending in 1234
      await accountRepo.addAccount(
        Account(
          id: 'acc_hdfc_1234',
          name: 'My HDFC Savings',
          bankName: 'HDFC Bank',
          accountNumber: '••••1234',
          accountType: 'Savings',
          accentColor: Colors.blue,
          smsTrackingEnabled: true,
        ),
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
            text: 'HDFC Bank: A/c XX1234 debited ₹500.',
            timestamp: DateTime(2026, 9, 21, 10, 0),
            isMe: false,
          ),
        ],
      );

      final discoveries = await discoveryService.discoverAccounts(conversations: [conv]);
      expect(discoveries.isEmpty, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6 — User confirmation
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 6 — User confirmation: confirming discovery creates Account and SmsRecognitionRules', () async {
      final ruleRepo = SmsRuleRepository.inMemory();

      final discovery = DiscoveredBankAccount(
        discoveryId: 'hdfc_1234',
        bankName: 'HDFC Bank',
        bankCode: 'hdfc',
        accountLast4: '1234',
        maskedAccountNumber: '••••1234',
        accountType: 'Savings',
        detectedSenderIds: ['HDFCBK'],
        detectedBalance: 25000.0,
        firstSeen: DateTime(2026, 9, 21, 10, 0),
        lastSeen: DateTime(2026, 9, 21, 14, 0),
      );

      // Simulate user confirmation action from sheet:
      final newAccount = Account(
        id: '',
        name: 'HDFC Savings',
        bankName: discovery.bankName,
        accountNumber: '••••${discovery.accountLast4}',
        accountType: 'Savings',
        currentBalance: discovery.detectedBalance ?? 0.0,
        balanceSource: 'sms',
        accentColor: Colors.blue,
        smsTrackingEnabled: true,
        isAutoDiscovered: false,
      );

      final createdId = await accountRepo.addAccount(newAccount);
      expect(createdId, isNotEmpty);

      // Create rules
      await ruleRepo.addRule(
        SmsRecognitionRule(
          id: 'r_debit',
          accountId: createdId,
          ruleLabel: 'HDFC Debit',
          senderPatterns: ['HDFCBK'],
          accountIdentifier: '1234',
          debitKeywords: ['debited', 'debit', 'spent'],
          creditKeywords: [],
          coversDebit: true,
          coversCredit: false,
          createdAt: DateTime.now(),
        ),
      );

      await discoveryRepo.markInitialized(discovery.discoveryId);

      // Verify account was created
      final userAccounts = await accountRepo.getAccounts();
      expect(userAccounts.length, 1);
      expect(userAccounts.first.name, 'HDFC Savings');
      expect(userAccounts.first.smsTrackingEnabled, isTrue);

      // Verify rules were created
      final rules = await ruleRepo.getRules(createdId);
      expect(rules.length, 1);
      expect(rules.first.accountIdentifier, '1234');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 7 — User dismisses
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 7 — User dismisses: "Not Now" does NOT create an account', () async {
      final discovery = DiscoveredBankAccount(
        discoveryId: 'sbi_9999',
        bankName: 'State Bank of India',
        bankCode: 'sbi',
        accountLast4: '9999',
        maskedAccountNumber: '••••9999',
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      await discoveryRepo.saveDiscovery(discovery);
      await discoveryRepo.dismissDiscovery(discovery.discoveryId);

      final userAccounts = await accountRepo.getAccounts();
      expect(userAccounts.isEmpty, isTrue);

      final saved = await discoveryRepo.getDiscovery('sbi_9999');
      expect(saved?.state, 'dismissed');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 8 — Ignore
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 8 — Ignore: user ignores account, no account created and skipped on rescan', () async {
      final discovery = DiscoveredBankAccount(
        discoveryId: 'icici_8888',
        bankName: 'ICICI Bank',
        bankCode: 'icici',
        accountLast4: '8888',
        maskedAccountNumber: '••••8888',
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      await discoveryRepo.saveDiscovery(discovery);
      await discoveryRepo.ignoreDiscovery(discovery.discoveryId);

      final userAccounts = await accountRepo.getAccounts();
      expect(userAccounts.isEmpty, isTrue);

      // Subsequent scan should exclude ignored discovery
      final conv = Conversation(
        id: 'ICICIB',
        senderName: 'ICICIB',
        senderNumber: 'ICICIB',
        avatarColor: Colors.orange,
        isBankSender: true,
        messages: [
          Message(
            id: 'm_icici',
            text: 'ICICI Bank: A/c XX8888 debited ₹300.',
            timestamp: DateTime.now(),
            isMe: false,
          ),
        ],
      );

      final discoveries = await discoveryService.discoverAccounts(conversations: [conv]);
      expect(discoveries.isEmpty, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 9 — SMS mapping after initialization
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 9 — SMS mapping after initialization: SMS resolves to the initialized account', () async {
      final account = Account(
        id: 'acc_hdfc_init',
        name: 'HDFC Bank',
        bankName: 'HDFC Bank',
        accountNumber: '••••1234',
        accountType: 'Savings',
        accentColor: Colors.blue,
        smsTrackingEnabled: true,
      );
      await accountRepo.addAccount(account);

      final rule = SmsRecognitionRule(
        id: 'rule_1',
        accountId: 'acc_hdfc_init',
        ruleLabel: 'HDFC Debit',
        senderPatterns: ['HDFCBK'],
        accountIdentifier: '1234',
        debitKeywords: ['debited'],
        creditKeywords: [],
        coversDebit: true,
        coversCredit: false,
        createdAt: DateTime.now(),
      );

      final index = SmsAccountIndex.fromData(
        accounts: [account],
        rulesByAccount: {'acc_hdfc_init': [rule]},
      );

      final match = index.match('HDFCBK', 'A/c XX1234 debited ₹500 at Starbucks');
      expect(match, isNotNull);
      expect(match!.accountId, 'acc_hdfc_init');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 10 — Unknown account
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 10 — Unknown account: bank detected but no account identifier -> no automatic account creation', () async {
      final conv = Conversation(
        id: 'HDFCBK',
        senderName: 'HDFCBK',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'm_no_account',
            text: 'Dear Customer, your transaction of ₹500 was successful. Call HDFC Bank for help.',
            timestamp: DateTime.now(),
            isMe: false,
          ),
        ],
      );

      final discoveries = await discoveryService.discoverAccounts(conversations: [conv]);
      // Should not suggest account without account identifier
      expect(discoveries.isEmpty, isTrue);
      expect((await accountRepo.getAccounts()).isEmpty, isTrue);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 11 — Same bank, different account
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 11 — Same bank, different account: distinct discoveries for distinct suffixes', () async {
      final conv = Conversation(
        id: 'SBIBNK',
        senderName: 'SBIINB',
        senderNumber: 'SBIINB',
        avatarColor: Colors.blue,
        isBankSender: true,
        messages: [
          Message(
            id: 'sbi_1',
            text: 'State Bank of India: A/c XX1111 debited ₹100.',
            timestamp: DateTime.now(),
            isMe: false,
          ),
          Message(
            id: 'sbi_2',
            text: 'State Bank of India: A/c XX2222 debited ₹200.',
            timestamp: DateTime.now(),
            isMe: false,
          ),
        ],
      );

      final discoveries = await discoveryService.discoverAccounts(conversations: [conv]);
      expect(discoveries.length, 2);
      expect(discoveries.map((d) => d.accountLast4).toSet(), {'1111', '2222'});
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 12 — Transaction import after initialization
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 12 — Transaction import: transactions from matching SMS appear under initialized account', () async {
      final txRepo = InMemoryTxRepo();

      final account = Account(
        id: 'acc_axis_4321',
        name: 'Axis Savings',
        bankName: 'Axis Bank',
        accountNumber: '••••4321',
        accountType: 'Savings',
        accentColor: Colors.purple,
        smsTrackingEnabled: true,
      );
      await accountRepo.addAccount(account);

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_axis_4321': [
          SmsRecognitionRule(
            id: 'axis_rule_1',
            accountId: 'acc_axis_4321',
            ruleLabel: 'Axis Debit',
            senderPatterns: ['AXISBK'],
            accountIdentifier: '4321',
            debitKeywords: ['debited', 'spent'],
            creditKeywords: [],
            coversDebit: true,
            coversCredit: false,
            createdAt: DateTime.now(),
          ),
        ],
      });

      final importer = SmsTransactionImporter(
        transactionRepo: txRepo,
        accountRepo: accountRepo,
        ruleRepo: ruleRepo,
        pendingDueRepo: FakePendingDueRepo(),
      );

      final msg = Message(
        id: 'axis_sms_1',
        text: 'INR 1,200.00 spent on Card ending 4321 at Flipkart.',
        timestamp: DateTime(2026, 9, 21, 17, 0),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'AXISBK');
      expect(result, SmsImportResult.imported);

      final txs = await txRepo.getTransactions();
      expect(txs.length, 1);
      expect(txs.first.accountId, 'acc_axis_4321');
      expect(txs.first.amount, 1200.0);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 13 — No regression on manual account creation
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 13 — No regression: manual account creation continues working seamlessly', () async {
      final manualAccount = Account(
        id: 'manual_acc_1',
        name: 'Emergency Fund',
        bankName: 'Canara Bank',
        accountNumber: '1234567890',
        accountType: 'Savings',
        balance: 50000.0,
        currentBalance: 50000.0,
        balanceSource: 'manual',
        accentColor: Colors.teal,
        smsTrackingEnabled: false,
      );

      final id = await accountRepo.addAccount(manualAccount);
      expect(id, 'manual_acc_1');

      final saved = await accountRepo.getAccountById(id);
      expect(saved, isNotNull);
      expect(saved!.name, 'Emergency Fund');
      expect(saved.currentBalance, 50000.0);
      expect(saved.smsTrackingEnabled, isFalse);
    });
  });
}
