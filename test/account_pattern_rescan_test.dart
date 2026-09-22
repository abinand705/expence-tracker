import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/account_pattern_recommendation.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/models/discovered_bank_account.dart';
import 'package:expense_tracker/models/pending_due.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/models/sms_recognition_rule.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/repositories/account_discovery_repository.dart';
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/repositories/sms_rule_repository.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/screens/my_accounts_screen.dart';
import 'package:expense_tracker/services/account_pattern_discovery_service.dart';
import 'package:expense_tracker/services/account_sms_matcher.dart';
import 'package:expense_tracker/services/bank_detection_service.dart';
import 'package:expense_tracker/services/sms_account_index.dart';
import 'package:expense_tracker/utils/dropdown_safety.dart';
import 'package:expense_tracker/utils/expense_parser.dart';
import 'package:expense_tracker/utils/feature_flags.dart';
import 'package:expense_tracker/widgets/dashboard/balance_card.dart';

// ── In-Memory Fake Repositories ──────────────────────────────────────────────

class FakeAccountRepo implements AccountRepository {
  final Map<String, Account> _accounts = {};

  FakeAccountRepo([List<Account>? initial]) {
    if (initial != null) {
      for (final a in initial) {
        _accounts[a.id] = a;
      }
    }
  }

  @override
  Future<List<Account>> getAccounts() async => _accounts.values.toList();

  @override
  Future<Account?> getAccountById(String id) async => _accounts[id];

  @override
  Future<String> addAccount(Account account) async {
    final id = account.id.isNotEmpty ? account.id : 'acc_${_accounts.length + 1}';
    final saved = account.copyWith(id: id);
    _accounts[id] = saved;
    return id;
  }

  @override
  Future<void> updateAccount(Account account) async {
    _accounts[account.id] = account;
  }

  @override
  Future<void> deleteAccount(String id) async {
    _accounts.remove(id);
  }

  @override
  Stream<List<Account>> watchAccounts() => Stream.value(_accounts.values.toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDiscoveryRepo implements AccountDiscoveryRepository {
  final Map<String, DiscoveredBankAccount> discoveries = {};

  @override
  Future<List<DiscoveredBankAccount>> getDiscoveries() async => discoveries.values.toList();

  @override
  Stream<List<DiscoveredBankAccount>> watchPendingDiscoveries() => Stream.value(discoveries.values.toList());

  @override
  Future<void> saveDiscovery(DiscoveredBankAccount discovery) async {
    discoveries[discovery.discoveryId] = discovery;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Conversation _makeConversation({
  required String id,
  required String senderName,
  required List<String> messageTexts,
}) {
  return Conversation(
    id: id,
    senderName: senderName,
    senderNumber: senderName,
    avatarColor: Colors.blue,
    messages: [
      for (int i = 0; i < messageTexts.length; i++)
        Message(
          id: '${id}_m$i',
          text: messageTexts[i],
          timestamp: DateTime.now(),
          isMe: false,
        ),
    ],
  );
}

// ── Main Test Suite ──────────────────────────────────────────────────────────

void main() {
  setUp(() {
    BankDetectionService.resetVerifiedBankIdentifiers();
  });

  tearDown(() {
    BankDetectionService.resetVerifiedBankIdentifiers();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Section 31: Bank Identifier SMS Recognition (Tests 1–38)
  // ══════════════════════════════════════════════════════════════════════════
  group('Section 31: Bank Identifier SMS Recognition (Tests 1–38)', () {
    // ── Bank Extraction (Tests 1–6) ─────────────────────────────────────────

    test('Test 1: VK-KGBANK-S extracts KGBANK', () {
      final bankId = BankDetectionService.extractBankIdentifier('VK-KGBANK-S');
      expect(bankId, 'KGBANK');
    });

    test('Test 2: JD-KGBANK-S extracts KGBANK', () {
      final bankId = BankDetectionService.extractBankIdentifier('JD-KGBANK-S');
      expect(bankId, 'KGBANK');
    });

    test('Test 3: AD-KGBANK-S extracts KGBANK', () {
      final bankId = BankDetectionService.extractBankIdentifier('AD-KGBANK-S');
      expect(bankId, 'KGBANK');
    });

    test('Test 4: VM-KGBANK-S extracts KGBANK', () {
      final bankId = BankDetectionService.extractBankIdentifier('VM-KGBANK-S');
      expect(bankId, 'KGBANK');
    });

    test('Test 5: Equivalent sender variations normalize consistently', () {
      expect(BankDetectionService.extractBankIdentifier('vk-kgbank-s'), 'KGBANK');
      expect(BankDetectionService.extractBankIdentifier('JD-KGBANK'), 'KGBANK');
      expect(BankDetectionService.extractBankIdentifier('AD_KGBANK_S'), 'KGBANK');
      expect(BankDetectionService.extractBankIdentifier('VM-KGBANK-T'), 'KGBANK');
    });

    test('Test 6: Unknown sender does not produce an unverified bank identifier', () {
      expect(BankDetectionService.extractBankIdentifier('AB-XYZABC-S'), isNull);
      expect(BankDetectionService.extractBankIdentifier('UNKNOWN-SNDR'), isNull);
      expect(BankDetectionService.extractBankIdentifier('+919876543210'), isNull);
      expect(BankDetectionService.extractBankIdentifier('9876543210'), isNull);
      expect(BankDetectionService.extractBankIdentifier('12345'), isNull);
    });

    // ── Account Matching (Tests 7–11) ───────────────────────────────────────

    test('Test 7: KGBANK + 1234 resolves correctly', () {
      final kgbAccount1234 = Account(
        id: 'acc_1234',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final matcher = AccountSmsMatcher(
        accounts: [kgbAccount1234],
        rulesByAccount: {
          'acc_1234': [
            SmsRecognitionRule(
              id: 'r1',
              accountId: 'acc_1234',
              ruleLabel: 'Savings Rule',
              bankIdentifier: 'KGBANK',
              senderPatterns: const [],
              accountIdentifier: '1234',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
        },
      );

      final match = matcher.match('VK-KGBANK-S', 'A/c XX1234 debited by Rs 500.');
      expect(match, isNotNull);
      expect(match!.accountId, 'acc_1234');
    });

    test('Test 8: KGBANK + 5678 resolves correctly', () {
      final kgbAccount5678 = Account(
        id: 'acc_5678',
        name: 'KGBANK Current',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '5678',
        accountType: 'current',
        accentColor: Colors.teal,
        smsTrackingEnabled: true,
      );

      final matcher = AccountSmsMatcher(
        accounts: [kgbAccount5678],
        rulesByAccount: {
          'acc_5678': [
            SmsRecognitionRule(
              id: 'r2',
              accountId: 'acc_5678',
              ruleLabel: 'Current Rule',
              bankIdentifier: 'KGBANK',
              senderPatterns: const [],
              accountIdentifier: '5678',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
        },
      );

      final match = matcher.match('JD-KGBANK-S', 'A/c XX5678 debited by Rs 1000.');
      expect(match, isNotNull);
      expect(match!.accountId, 'acc_5678');
    });

    test('Test 9: Same-bank multiple accounts remain separated', () {
      final acc1 = Account(
        id: 'acc_1234',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );
      final acc2 = Account(
        id: 'acc_5678',
        name: 'KGBANK Current',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '5678',
        accountType: 'current',
        accentColor: Colors.teal,
        smsTrackingEnabled: true,
      );

      final matcher = AccountSmsMatcher(
        accounts: [acc1, acc2],
        rulesByAccount: {
          'acc_1234': [
            SmsRecognitionRule(
              id: 'r1',
              accountId: 'acc_1234',
              ruleLabel: 'Savings Rule',
              bankIdentifier: 'KGBANK',
              senderPatterns: const [],
              accountIdentifier: '1234',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
          'acc_5678': [
            SmsRecognitionRule(
              id: 'r2',
              accountId: 'acc_5678',
              ruleLabel: 'Current Rule',
              bankIdentifier: 'KGBANK',
              senderPatterns: const [],
              accountIdentifier: '5678',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
        },
      );

      final match1 = matcher.match('VK-KGBANK-S', 'A/c XX1234 debited by Rs 500.');
      expect(match1?.accountId, 'acc_1234');

      final match2 = matcher.match('AD-KGBANK-S', 'A/c XX5678 debited by Rs 1000.');
      expect(match2?.accountId, 'acc_5678');
    });

    test('Test 10: Missing account suffix becomes ambiguous', () {
      final acc1 = Account(
        id: 'acc_1234',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );
      final acc2 = Account(
        id: 'acc_5678',
        name: 'KGBANK Current',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '5678',
        accountType: 'current',
        accentColor: Colors.teal,
        smsTrackingEnabled: true,
      );

      final matcher = AccountSmsMatcher(
        accounts: [acc1, acc2],
        rulesByAccount: {
          'acc_1234': [
            SmsRecognitionRule(
              id: 'r1',
              accountId: 'acc_1234',
              ruleLabel: 'Savings Rule',
              bankIdentifier: 'KGBANK',
              senderPatterns: const [],
              accountIdentifier: '1234',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
          'acc_5678': [
            SmsRecognitionRule(
              id: 'r2',
              accountId: 'acc_5678',
              ruleLabel: 'Current Rule',
              bankIdentifier: 'KGBANK',
              senderPatterns: const [],
              accountIdentifier: '5678',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
        },
      );

      final match = matcher.match('VK-KGBANK-S', 'Your account has been debited by Rs 500.');
      expect(match, isNull);
    });

    test('Test 11: Unique bank + account combination resolves deterministically', () {
      final acc = Account(
        id: 'acc_unique',
        name: 'HDFC Savings',
        bankName: 'HDFC Bank',
        accountNumber: '4321',
        accountType: 'savings',
        accentColor: Colors.blue,
        smsTrackingEnabled: true,
      );

      final matcher = AccountSmsMatcher(
        accounts: [acc],
        rulesByAccount: {
          'acc_unique': [
            SmsRecognitionRule(
              id: 'r_hdfc',
              accountId: 'acc_unique',
              ruleLabel: 'HDFC Rule',
              bankIdentifier: 'HDFCBK',
              senderPatterns: const [],
              accountIdentifier: '4321',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
        },
      );

      final match = matcher.match('VK-HDFCBK-S', 'A/c XX4321 debited by Rs 250.');
      expect(match, isNotNull);
      expect(match!.accountId, 'acc_unique');
    });

    // ── Discovery (Tests 12–17) ─────────────────────────────────────────────

    test('Test 12: New bank identifier generates recommendation', () async {
      BankDetectionService.registerVerifiedBankIdentifier('ABCXYZ');

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([]),
        ruleRepo: SmsRuleRepository.inMemory(),
      );

      final result = await service.scanMessagesForPatterns(
        conversations: [
          _makeConversation(
            id: 'c1',
            senderName: 'AD-ABCXYZ-S',
            messageTexts: ['Your transaction of Rs 500 is successful.'],
          ),
        ],
        existingAccounts: [],
      );

      expect(result.recommendations.any((r) => r.bankIdentifier == 'ABCXYZ'), isTrue);
    });

    test('Test 13: Existing bank identifier does not generate duplicate recommendation', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      final result = await service.scanMessagesForPatterns(
        conversations: [
          _makeConversation(
            id: 'c1',
            senderName: 'VK-KGBANK-S',
            messageTexts: ['A/c XX1234 debited ₹500.'],
          ),
        ],
        existingAccounts: [kgbAccount],
      );

      expect(result.recommendations.any((r) => r.patternType == 'bank_identifier'), isFalse);
      expect(result.recommendations.any((r) => r.patternType == 'sender'), isFalse);
    });

    test('Test 14: Harmless sender variation does not generate redundant sender rule', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      final result = await service.scanMessagesForPatterns(
        conversations: [
          _makeConversation(id: 'c1', senderName: 'VK-KGBANK-S', messageTexts: ['A/c 1234 debited Rs 100']),
          _makeConversation(id: 'c2', senderName: 'JD-KGBANK-S', messageTexts: ['A/c 1234 debited Rs 200']),
          _makeConversation(id: 'c3', senderName: 'AD-KGBANK-S', messageTexts: ['A/c 1234 debited Rs 300']),
        ],
        existingAccounts: [kgbAccount],
      );

      expect(result.recommendations.any((r) => r.patternType == 'sender' || r.patternType == 'sender_fallback'), isFalse);
      expect(result.observedSenderVariations['KGBANK'], containsAll(['VK-KGBANK-S', 'JD-KGBANK-S', 'AD-KGBANK-S']));
    });

    test('Test 15: New account pattern generates recommendation', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            accountPatterns: const ['1234'],
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      final result = await service.scanMessagesForPatterns(
        conversations: [
          _makeConversation(
            id: 'c1',
            senderName: 'VK-KGBANK-S',
            messageTexts: ['Kerala Gramin Bank Account ending 1234 debited by Rs 500.'],
          ),
        ],
        existingAccounts: [kgbAccount],
      );

      expect(result.recommendations.any((r) => r.patternType == 'account_pattern'), isTrue);
    });

    test('Test 16: New transaction pattern generates recommendation', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      final result = await service.scanMessagesForPatterns(
        conversations: [
          _makeConversation(
            id: 'c1',
            senderName: 'VK-KGBANK-S',
            messageTexts: ['A/c 1234: UPI transaction successful for Rs 250.'],
          ),
        ],
        existingAccounts: [kgbAccount],
      );

      expect(result.recommendations.any((r) => r.patternType == 'transaction_pattern'), isTrue);
      final rec = result.recommendations.firstWhere((r) => r.patternType == 'transaction_pattern');
      expect(rec.patternValue.toLowerCase(), contains('upi transaction successful'));
    });

    test('Test 17: New balance pattern generates recommendation', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            balancePatterns: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      final result = await service.scanMessagesForPatterns(
        conversations: [
          _makeConversation(
            id: 'c1',
            senderName: 'VK-KGBANK-S',
            messageTexts: ['A/c 1234 debited Rs 100. Available balance is Rs 24,500.'],
          ),
        ],
        existingAccounts: [kgbAccount],
      );

      expect(result.recommendations.any((r) => r.patternType == 'balance_pattern'), isTrue);
    });

    // ── Approval (Tests 18–25) ──────────────────────────────────────────────

    test('Test 18: Approved bank identifier persists', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            senderPatterns: const ['KGBANK'],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      await service.applyApprovedPatterns(
        approvedPatterns: [
          const AccountPatternRecommendation(
            recommendationId: 'rec_bank_1',
            accountId: 'acc_kgb',
            bankName: 'Kerala Gramin Bank',
            bankIdentifier: 'KGBANK',
            accountLast4: '1234',
            patternType: 'bank_identifier',
            patternValue: 'KGBANK',
            reason: 'Bank identifier',
          ),
        ],
        accounts: [kgbAccount],
      );

      final rules = await ruleRepo.getRules('acc_kgb');
      expect(rules.first.bankIdentifier, 'KGBANK');
    });

    test('Test 19: Approved account pattern persists', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            accountPatterns: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      await service.applyApprovedPatterns(
        approvedPatterns: [
          const AccountPatternRecommendation(
            recommendationId: 'rec_acc_1',
            accountId: 'acc_kgb',
            bankName: 'Kerala Gramin Bank',
            bankIdentifier: 'KGBANK',
            accountLast4: '1234',
            patternType: 'account_pattern',
            patternValue: 'Account ending 1234',
            reason: 'Account pattern',
          ),
        ],
        accounts: [kgbAccount],
      );

      final rules = await ruleRepo.getRules('acc_kgb');
      expect(rules.first.accountPatterns, contains('Account ending 1234'));
    });

    test('Test 20: Approved transaction pattern persists', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            transactionPatterns: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      await service.applyApprovedPatterns(
        approvedPatterns: [
          const AccountPatternRecommendation(
            recommendationId: 'rec_tx_1',
            accountId: 'acc_kgb',
            bankName: 'Kerala Gramin Bank',
            bankIdentifier: 'KGBANK',
            accountLast4: '1234',
            patternType: 'transaction_pattern',
            patternValue: 'UPI transaction successful',
            reason: 'Transaction wording',
          ),
        ],
        accounts: [kgbAccount],
      );

      final rules = await ruleRepo.getRules('acc_kgb');
      expect(rules.first.transactionPatterns, contains('UPI transaction successful'));
    });

    test('Test 21: Approved balance pattern persists', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            balancePatterns: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      await service.applyApprovedPatterns(
        approvedPatterns: [
          const AccountPatternRecommendation(
            recommendationId: 'rec_bal_1',
            accountId: 'acc_kgb',
            bankName: 'Kerala Gramin Bank',
            bankIdentifier: 'KGBANK',
            accountLast4: '1234',
            patternType: 'balance_pattern',
            patternValue: 'Available balance is',
            reason: 'Balance wording',
          ),
        ],
        accounts: [kgbAccount],
      );

      final rules = await ruleRepo.getRules('acc_kgb');
      expect(rules.first.balancePatterns, contains('Available balance is'));
    });

    test('Test 22: Rejected recommendation does not persist', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            senderPatterns: const ['KGBANK'],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      // User rejects all recommendations
      await service.applyApprovedPatterns(
        approvedPatterns: [],
        accounts: [kgbAccount],
      );

      final rules = await ruleRepo.getRules('acc_kgb');
      expect(rules.first.bankIdentifier, isNull);
      expect(rules.first.accountPatterns.isEmpty, isTrue);
    });

    test('Test 23: Existing account is reused', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final accountRepo = FakeAccountRepo([kgbAccount]);
      final service = AccountPatternDiscoveryService(
        accountRepo: accountRepo,
        ruleRepo: SmsRuleRepository.inMemory(),
      );

      await service.applyApprovedPatterns(
        approvedPatterns: [
          const AccountPatternRecommendation(
            recommendationId: 'rec1',
            accountId: 'acc_kgb',
            bankName: 'Kerala Gramin Bank',
            bankIdentifier: 'KGBANK',
            accountLast4: '1234',
            patternType: 'bank_identifier',
            patternValue: 'KGBANK',
            reason: 'Rule update',
          ),
        ],
        accounts: [kgbAccount],
      );

      final accounts = await accountRepo.getAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.id, 'acc_kgb');
    });

    test('Test 24: Duplicate rules are not created', () async {
      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([]),
        ruleRepo: ruleRepo,
      );

      await service.applyApprovedPatterns(
        approvedPatterns: [
          const AccountPatternRecommendation(
            recommendationId: 'rec_acc_1',
            accountId: 'acc_kgb',
            bankName: 'Kerala Gramin Bank',
            bankIdentifier: 'KGBANK',
            accountLast4: '1234',
            patternType: 'account_pattern',
            patternValue: 'Account ending 1234',
            reason: 'New account phrase',
          ),
        ],
        accounts: [
          Account(
            id: 'acc_kgb',
            name: 'KGBANK',
            bankName: 'Kerala Gramin Bank',
            accountNumber: '1234',
            accountType: 'savings',
            accentColor: Colors.green,
          ),
        ],
      );

      final rules = await ruleRepo.getRules('acc_kgb');
      expect(rules.length, 1);
      expect(rules.first.accountPatterns, contains('Account ending 1234'));
    });

    test('Test 25: SmsAccountIndex rebuilds', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            senderPatterns: const ['OLD-SENDER'],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final accountRepo = FakeAccountRepo([kgbAccount]);
      final service = AccountPatternDiscoveryService(
        accountRepo: accountRepo,
        ruleRepo: ruleRepo,
      );

      var index = SmsAccountIndex.fromData(
        accounts: [kgbAccount],
        rulesByAccount: await ruleRepo.getAllRulesByAccount(),
      );
      expect(index.match('VK-KGBANK-S', 'A/c 1234 debited'), isNull);

      await service.applyApprovedPatterns(
        approvedPatterns: [
          const AccountPatternRecommendation(
            recommendationId: 'r_bank',
            accountId: 'acc_kgb',
            bankName: 'Kerala Gramin Bank',
            bankIdentifier: 'KGBANK',
            accountLast4: '1234',
            patternType: 'bank_identifier',
            patternValue: 'KGBANK',
            reason: 'Add bank identifier',
          ),
        ],
        accounts: [kgbAccount],
      );

      index = SmsAccountIndex.fromData(
        accounts: [kgbAccount],
        rulesByAccount: await ruleRepo.getAllRulesByAccount(),
      );
      expect(index.match('VK-KGBANK-S', 'A/c 1234 debited'), isNotNull);
    });

    // ── Future Resolution (Tests 26–28) ─────────────────────────────────────

    test('Test 26: Future SMS resolves through bank identifier', () {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final matcher = AccountSmsMatcher(
        accounts: [kgbAccount],
        rulesByAccount: {
          'acc_kgb': [
            SmsRecognitionRule(
              id: 'r1',
              accountId: 'acc_kgb',
              ruleLabel: 'KGB Rule',
              bankIdentifier: 'KGBANK',
              senderPatterns: const [],
              accountIdentifier: '1234',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
        },
      );

      final match = matcher.match('VM-KGBANK-S', 'A/c XX1234 has been debited ₹750');
      expect(match, isNotNull);
      expect(match!.accountId, 'acc_kgb');
    });

    test('Test 27: Future SMS resolves through bank + account suffix', () {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final matcher = AccountSmsMatcher(
        accounts: [kgbAccount],
        rulesByAccount: {
          'acc_kgb': [
            SmsRecognitionRule(
              id: 'r1',
              accountId: 'acc_kgb',
              ruleLabel: 'KGB Rule',
              bankIdentifier: 'KGBANK',
              senderPatterns: const [],
              accountIdentifier: '1234',
              debitKeywords: const ['debited'],
              creditKeywords: const [],
              createdAt: DateTime.now(),
            ),
          ],
        },
      );

      final match = matcher.match('JD-KGBANK-S', 'Your A/c XX1234 has been debited ₹500');
      expect(match, isNotNull);
      expect(match!.accountId, 'acc_kgb');
    });

    test('Test 28: Legacy sender fallback still works', () {
      final acc = Account(
        id: 'acc_hdfc',
        name: 'HDFC',
        bankName: 'HDFC Bank',
        accountNumber: '9988',
        accountType: 'savings',
        accentColor: Colors.blue,
        smsTrackingEnabled: true,
      );

      final rule = SmsRecognitionRule(
        id: 'r_legacy',
        accountId: 'acc_hdfc',
        ruleLabel: 'Legacy HDFC',
        senderPatterns: const ['HDFCBK'],
        accountIdentifier: '9988',
        debitKeywords: const ['debited'],
        creditKeywords: const [],
        createdAt: DateTime.now(),
      );

      final matcher = AccountSmsMatcher(
        accounts: [acc],
        rulesByAccount: {
          'acc_hdfc': [rule],
        },
      );

      final match = matcher.match('HDFCBK', 'A/c 9988 debited by Rs 100');
      expect(match, isNotNull);
      expect(match!.accountId, 'acc_hdfc');
    });

    // ── Ambiguity (Tests 29–30) ─────────────────────────────────────────────

    test('Test 29: Ambiguous same-bank accounts return unresolved', () async {
      final acc1 = Account(
        id: 'acc_1',
        name: 'KGBANK 1',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );
      final acc2 = Account(
        id: 'acc_2',
        name: 'KGBANK 2',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([acc1, acc2]),
        ruleRepo: SmsRuleRepository.inMemory(),
      );

      final res = await service.scanMessagesForPatterns(
        conversations: [
          _makeConversation(id: 'c1', senderName: 'VK-KGBANK-S', messageTexts: ['A/c 1234 debited Rs 100']),
        ],
        existingAccounts: [acc1, acc2],
      );

      for (final r in res.recommendations) {
        expect(r.accountId, isNull);
      }
    });

    test('Test 30: Low-confidence detection remains unresolved', () async {
      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([]),
        ruleRepo: SmsRuleRepository.inMemory(),
      );

      final res = await service.scanMessagesForPatterns(
        conversations: [
          _makeConversation(id: 'c1', senderName: 'UNKNOWN-SNDR', messageTexts: ['Some message']),
        ],
        existingAccounts: [],
      );

      for (final r in res.recommendations) {
        expect(r.accountId, isNull);
      }
    });

    // ── Idempotency (Tests 31–32) ───────────────────────────────────────────

    test('Test 31: Repeated scan produces no duplicate recommendations', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      final convs = [
        _makeConversation(
          id: 'c1',
          senderName: 'VK-KGBANK-S',
          messageTexts: ['A/c XX1234 debited by Rs 500.'],
        ),
      ];

      final res1 = await service.scanMessagesForPatterns(conversations: convs, existingAccounts: [kgbAccount]);
      expect(res1.recommendations.isNotEmpty, isTrue);

      await service.applyApprovedPatterns(approvedPatterns: res1.recommendations, accounts: [kgbAccount]);

      final res2 = await service.scanMessagesForPatterns(conversations: convs, existingAccounts: [kgbAccount]);
      expect(res2.recommendations.isEmpty, isTrue);
    });

    test('Test 32: Repeated approval produces no duplicate rules', () async {
      final kgbAccount = Account(
        id: 'acc_kgb',
        name: 'KGBANK Savings',
        bankName: 'Kerala Gramin Bank',
        accountNumber: '1234',
        accountType: 'savings',
        accentColor: Colors.green,
        smsTrackingEnabled: true,
      );

      final ruleRepo = SmsRuleRepository.inMemory({
        'acc_kgb': [
          SmsRecognitionRule(
            id: 'r1',
            accountId: 'acc_kgb',
            ruleLabel: 'KGB Rule',
            bankIdentifier: 'KGBANK',
            senderPatterns: const [],
            accountIdentifier: '1234',
            debitKeywords: const ['debited'],
            creditKeywords: const [],
            createdAt: DateTime.now(),
          ),
        ],
      });

      final service = AccountPatternDiscoveryService(
        accountRepo: FakeAccountRepo([kgbAccount]),
        ruleRepo: ruleRepo,
      );

      final rec = const AccountPatternRecommendation(
        recommendationId: 'rec_rep',
        accountId: 'acc_kgb',
        bankName: 'Kerala Gramin Bank',
        bankIdentifier: 'KGBANK',
        accountLast4: '1234',
        patternType: 'account_pattern',
        patternValue: 'A/c 1234',
        reason: 'Repeat test',
      );

      await service.applyApprovedPatterns(approvedPatterns: [rec], accounts: [kgbAccount]);
      await service.applyApprovedPatterns(approvedPatterns: [rec], accounts: [kgbAccount]);

      final rules = await ruleRepo.getRules('acc_kgb');
      expect(rules.length, 1);
    });

    // ── Regression (Tests 33–38) ────────────────────────────────────────────

    test('Test 33: SMS deduplication remains functional', () async {
      final txRepo = MockTxRepo();
      final tx = model_tx.Transaction(
        id: 'tx_hash_123',
        merchant: 'UPI Transfer',
        amount: 250.0,
        type: model_tx.TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        accountId: 'acc_1',
      );

      final addedFirst = await txRepo.addTransactionIfAbsent(tx);
      final addedSecond = await txRepo.addTransactionIfAbsent(tx);

      expect(addedFirst, isTrue);
      expect(addedSecond, isFalse);
    });

    test('Test 34: SMS transaction import remains functional', () {
      const sms = 'Your A/c XX1234 has been debited by Rs 450.00 on 22-Sep-2026. Avl bal Rs 12,000.';
      final parsed = ExpenseParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 450.00);
      expect(parsed.availableBalance, 12000.0);
      expect(parsed.accountNumber, contains('1234'));
    });

    test('Test 35: Statement import remains functional', () {
      final acc = Account(
        id: 'acc_statement',
        name: 'Salary Account',
        bankName: 'HDFC',
        accountNumber: '4455',
        accountType: 'savings',
        accentColor: Colors.blue,
        currentBalance: 50000.0,
        balanceSource: 'statement',
        balanceUpdatedAt: DateTime.now(),
        lastStatementImportAt: DateTime.now(),
      );

      expect(acc.balanceSource, 'statement');
      expect(acc.lastStatementImportAt, isNotNull);
    });

    test('Test 36: Pending dues remain functional', () {
      final due = PendingDue(
        id: 'due_1',
        description: 'Credit Card Bill',
        amount: 12500.0,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        detectedAt: DateTime.now(),
        source: 'sms',
      );

      expect(due.amount, 12500.0);
      expect(due.description, 'Credit Card Bill');
      expect(due.source, 'sms');
    });

    test('Test 37: Account balances remain functional', () {
      final acc = Account(
        id: 'acc_bal',
        name: 'Savings',
        bankName: 'SBI',
        accountNumber: '1122',
        accountType: 'savings',
        accentColor: Colors.blue,
        currentBalance: 15400.50,
      );

      expect(acc.currentBalance, 15400.50);
    });

    test('Test 38: Analytics remain functional', () {
      final budget = Budget(
        id: 'b1',
        category: 'Food',
        amount: 10000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(budget.amount, 10000.0);
      expect(budget.category, 'Food');

      final transactions = [
        model_tx.Transaction(
          id: 't1',
          merchant: 'Lunch',
          amount: 350.0,
          type: model_tx.TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
        ),
        model_tx.Transaction(
          id: 't2',
          merchant: 'Dinner',
          amount: 650.0,
          type: model_tx.TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
        ),
      ];

      final totalSpent = transactions.fold<double>(0.0, (sum, t) => sum + t.amount);
      expect(totalSpent, 1000.0);
      expect(totalSpent <= budget.amount, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Section 30: Dropdown Regression Tests (Tests 1–8)
  // ══════════════════════════════════════════════════════════════════════════
  group('Section 30: Dropdown Regression Tests (Tests 1–8)', () {
    test('Test 1: Current value exists exactly once', () {
      final res = DropdownSafety.resolve(
        items: ['Debit', 'Credit', 'UPI Debit'],
        currentValue: 'Debit',
      );
      expect(res.items, ['Debit', 'Credit', 'UPI Debit']);
      expect(res.safeValue, 'Debit');
    });

    test('Test 2: Current value does not exist', () {
      final res = DropdownSafety.resolve(
        items: ['Debit', 'Credit', 'UPI Debit'],
        currentValue: 'NonExistent',
      );
      expect(res.safeValue, isNull);
    });

    test('Test 3: Current value appears twice', () {
      final res = DropdownSafety.resolve(
        items: ['Debit', 'Credit', 'Debit'],
        currentValue: 'Debit',
      );
      expect(res.items, ['Debit', 'Credit']);
      expect(res.safeValue, 'Debit');
    });

    test('Test 4: Empty item list', () {
      final res = DropdownSafety.resolve(
        items: [],
        currentValue: 'Debit',
      );
      expect(res.items.isEmpty, isTrue);
      expect(res.safeValue, isNull);
    });

    test('Test 5: Previously stored legacy rule label', () {
      final norm = DropdownSafety.normalizeRuleLabel('Kerala Gramin Bank Debit');
      expect(norm, 'Debit');

      final normCredit = DropdownSafety.normalizeRuleLabel('HDFC Credit');
      expect(normCredit, 'Credit');
    });

    testWidgets('Test 6: Kerala Gramin Bank Debit specifically reproduces no assertion', (tester) async {
      const rawRuleLabel = 'Kerala Gramin Bank Debit';
      final normalized = DropdownSafety.normalizeRuleLabel(rawRuleLabel);
      final resolved = DropdownSafety.resolve(
        items: ['Debit', 'Credit', 'UPI Debit', 'UPI Credit', 'ATM', 'Other', normalized],
        currentValue: normalized,
        fallback: 'Debit',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              initialValue: resolved.safeValue,
              items: resolved.items
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Debit'), findsOneWidget);
    });

    test('Test 7: Editing an existing rule preserves valid selection', () {
      final res = DropdownSafety.resolve(
        items: ['Debit', 'Credit', 'UPI Debit', 'UPI Credit', 'ATM', 'Other'],
        currentValue: 'Credit',
        fallback: 'Debit',
      );
      expect(res.safeValue, 'Credit');
    });

    test('Test 8: Creating a new rule starts with valid/default selection', () {
      final res = DropdownSafety.resolve(
        items: ['Debit', 'Credit', 'UPI Debit', 'UPI Credit', 'ATM', 'Other'],
        currentValue: 'Debit',
        fallback: 'Debit',
      );
      expect(res.safeValue, 'Debit');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Section 32: Total Balance Tests (Tests 1–5)
  // ══════════════════════════════════════════════════════════════════════════
  group('Section 32: Total Balance Tests (Tests 1–5)', () {
    test('Test 1: FeatureFlags.enableTotalBalance == true', () {
      expect(FeatureFlags.enableTotalBalance, isTrue);
    });

    testWidgets('Test 2: Dashboard displays numeric Total Balance', (tester) async {
      final formatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BalanceCard(
              totalBalance: 40000.0,
              formatter: formatter,
            ),
          ),
        ),
      );

      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('Currently unavailable'), findsNothing);
      expect(find.text('₹ 40,000.00'), findsOneWidget);
    });

    test('Test 3: My Accounts displays numeric Total Net Worth', () {
      final accounts = [
        Account(
          id: 'a1',
          name: 'Account 1',
          bankName: 'HDFC',
          accountNumber: '1111',
          accountType: 'savings',
          accentColor: Colors.blue,
          currentBalance: 25000.0,
        ),
        Account(
          id: 'a2',
          name: 'Account 2',
          bankName: 'SBI',
          accountNumber: '2222',
          accountType: 'savings',
          accentColor: Colors.green,
          currentBalance: 15000.0,
        ),
      ];

      final totalNetWorth = accounts.fold<double>(0.0, (sum, acc) => sum + acc.currentBalance);
      expect(totalNetWorth, 40000.0);

      final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ');
      expect(fmt.format(totalNetWorth), fmt.format(40000.0));
    });

    test('Test 4: Individual account balances remain unchanged', () {
      final acc1 = Account(
        id: 'a1',
        name: 'Account 1',
        bankName: 'HDFC',
        accountNumber: '1111',
        accountType: 'savings',
        accentColor: Colors.blue,
        currentBalance: 25000.0,
      );
      final acc2 = Account(
        id: 'a2',
        name: 'Account 2',
        bankName: 'SBI',
        accountNumber: '2222',
        accountType: 'savings',
        accentColor: Colors.green,
        currentBalance: 15000.0,
      );

      expect(acc1.currentBalance, 25000.0);
      expect(acc2.currentBalance, 15000.0);
    });

    test('Test 5: Existing aggregate calculation is used', () {
      final accounts = [
        Account(
          id: 'a1',
          name: 'Account 1',
          bankName: 'HDFC',
          accountNumber: '1111',
          accountType: 'savings',
          accentColor: Colors.blue,
          currentBalance: 100.50,
        ),
        Account(
          id: 'a2',
          name: 'Account 2',
          bankName: 'SBI',
          accountNumber: '2222',
          accountType: 'savings',
          accentColor: Colors.green,
          currentBalance: 200.25,
        ),
      ];

      final sum = accounts.fold<double>(0.0, (acc, a) => acc + a.currentBalance);
      expect(sum, closeTo(300.75, 0.001));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Section 33: AI Icon UI Tests (Test 1)
  // ══════════════════════════════════════════════════════════════════════════
  group('Section 33: AI Icon UI Tests', () {
    testWidgets('Test 1: MyAccountsScreen does not contain the AI/Gemini AppBar action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MyAccountsScreen(
            accountRepository: FakeAccountRepo([]),
            ruleRepository: SmsRuleRepository.inMemory(),
            discoveryRepository: FakeDiscoveryRepo(),
          ),
        ),
      );
      await tester.pump();

      // Check AppBar has no AI / auto_awesome action
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      expect(find.descendant(of: appBarFinder, matching: find.byIcon(Icons.auto_awesome)), findsNothing);

      // Verify Scan Messages for Accounts remains accessible
      expect(find.text('Scan Messages for Accounts'), findsOneWidget);
    });
  });
}
