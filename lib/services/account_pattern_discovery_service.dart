import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/account_pattern_recommendation.dart';
import '../models/discovered_bank_account.dart';
import '../models/sms_models.dart';
import '../models/sms_recognition_rule.dart';
import '../repositories/account_discovery_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/sms_rule_repository.dart';
import '../utils/expense_parser.dart';
import 'bank_account_discovery_service.dart';
import 'bank_detection_service.dart';
import 'sms_account_index.dart';
import 'sms_account_resolver.dart';
import 'sms_service.dart';

/// Result of an account and pattern discovery scan.
class PatternDiscoveryResult {
  final List<AccountPatternRecommendation> recommendations;
  final List<DiscoveredBankAccount> newlyDiscoveredAccounts;
  final Map<String, List<String>> observedSenderVariations;

  const PatternDiscoveryResult({
    required this.recommendations,
    this.newlyDiscoveredAccounts = const [],
    this.observedSenderVariations = const {},
  });

  bool get isEmpty => recommendations.isEmpty && newlyDiscoveredAccounts.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// Service that analyzes SMS messages to discover new account recognition patterns,
/// such as stable Bank Identifiers, account representation patterns, and transaction wording.
///
/// Discovered patterns are returned as recommendations for user confirmation.
/// They are NEVER applied to account rules automatically.
class AccountPatternDiscoveryService {
  final AccountRepository _accountRepo;
  final SmsRuleRepository _ruleRepo;
  final BankDetectionService _bankDetectionService;
  final BankAccountDiscoveryService _bankAccountDiscoveryService;

  AccountPatternDiscoveryService({
    AccountRepository? accountRepo,
    SmsRuleRepository? ruleRepo,
    AccountDiscoveryRepository? discoveryRepo,
    BankDetectionService? bankDetectionService,
    BankAccountDiscoveryService? bankAccountDiscoveryService,
  })  : _accountRepo = accountRepo ?? AccountRepository(),
        _ruleRepo = ruleRepo ?? SmsRuleRepository(),
        _bankDetectionService = bankDetectionService ?? BankDetectionService(),
        _bankAccountDiscoveryService = bankAccountDiscoveryService ??
            BankAccountDiscoveryService(
              discoveryRepo: discoveryRepo ??
                  (Firebase.apps.isNotEmpty
                      ? AccountDiscoveryRepository()
                      : AccountDiscoveryRepository.inMemory()),
              accountRepo: accountRepo,
              bankDetectionService: bankDetectionService,
            );

  // ── Pattern Normalization Utilities ──────────────────────────────────────────

  /// Normalizes a string for comparison: removes punctuation, multiple spaces, and lowers case.
  static String normalizeText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Normalizes an account representation pattern (e.g. "A/C XXXX1234" -> "xxxx1234").
  static String normalizeAccountPattern(String pattern) {
    var p = pattern.trim().toLowerCase();
    p = p.replaceAll(RegExp(r'^(?:a/c|account|acct|card)\s*(?:no\.?|num)?\s*[-:#]?\s*', caseSensitive: false), '');
    p = p.replaceAll(RegExp(r'\s+'), ' ').trim();
    return p;
  }

  // Regexes for pattern extraction from message text
  static final RegExp _accountPatternRegex = RegExp(
    r'(?:(?:a/c|account|acct|card)\s*(?:no\.?|num)?\s*[-:#]?\s*(?:ending(?:\s+(?:in|with))?|ends\s+with)?\s*([xX\*\.\s-]*\d{3,6})|(?:ending(?:\s+(?:in|with))?|ends\s+with)\s*([xX\*\.\s-]*\d{3,6})|([xX\*]{2,}[\s-]*\d{3,6}))',
    caseSensitive: false,
  );

  static final List<RegExp> _transactionWordingRegexes = [
    RegExp(r'(?:has been debited|was debited|successfully debited|debited by|debited for)', caseSensitive: false),
    RegExp(r'(?:has been credited|was credited|successfully credited|credited to|credited by)', caseSensitive: false),
    RegExp(r'(?:UPI\s+transaction\s+successful|UPI\s+txn\s+successful|UPI\s+payment\s+successful)', caseSensitive: false),
    RegExp(r'(?:transaction\s+successful|transfer\s+successful|payment\s+successful)', caseSensitive: false),
    RegExp(r'(?:withdrawn\s+from|deposited\s+to|spent\s+on)', caseSensitive: false),
  ];

  static final List<RegExp> _balancePatternRegexes = [
    RegExp(r'(?:available\s+balance\s+(?:is|:)|avl\s+bal\s+(?:is|:)?|balance\s+is|total\s+balance\s+(?:is|:)?|bal\s+is)', caseSensitive: false),
    RegExp(r'(?:avl\s+bal|avail\s+bal|avbl\s+bal)', caseSensitive: false),
  ];

  /// Performs a fresh scan of SMS messages for new patterns and accounts.
  Future<PatternDiscoveryResult> scanMessagesForPatterns({
    required List<Conversation> conversations,
    List<Account>? existingAccounts,
  }) async {
    final userAccounts = existingAccounts ?? await _accountRepo.getAccounts();

    // 1. Check for brand-new bank accounts
    final newAccounts = await _bankAccountDiscoveryService.discoverAccounts(
      conversations: conversations,
      existingAccounts: userAccounts,
    );

    // 2. Preload existing rules for all accounts
    final Map<String, List<SmsRecognitionRule>> rulesByAccount = {};
    for (final acc in userAccounts) {
      rulesByAccount[acc.id] = await _ruleRepo.getRules(acc.id);
    }

    // Temporary storage for recommendations grouped by recommendationId
    final Map<String, _RecommendationAccumulator> accumulators = {};
    final Map<String, Set<String>> observedVariationsByBank = {};

    // 3. Scan all messages
    for (final conv in conversations) {
      final sender = conv.senderName.trim();
      if (sender.isEmpty) continue;

      for (final msg in conv.messages) {
        final text = msg.text.trim();
        if (text.isEmpty) continue;

        _processMessage(
          sender: sender,
          text: text,
          userAccounts: userAccounts,
          rulesByAccount: rulesByAccount,
          accumulators: accumulators,
          observedVariationsByBank: observedVariationsByBank,
        );
      }
    }

    // 4. Filter and build final recommendation list
    final List<AccountPatternRecommendation> recommendations = [];

    for (final acc in accumulators.values) {
      if (acc.confidence < 0.70) {
        continue; // Below confidence threshold
      }

      final observed = (observedVariationsByBank[acc.bankIdentifier] ?? {}).toList();

      recommendations.add(
        AccountPatternRecommendation(
          recommendationId: acc.recommendationId,
          accountId: acc.accountId,
          bankName: acc.bankName,
          bankIdentifier: acc.bankIdentifier,
          accountLast4: acc.accountLast4,
          patternType: acc.patternType,
          patternValue: acc.patternValue,
          sourceMessageCount: acc.messageCount,
          confidence: acc.confidence.clamp(0.0, 1.0),
          reason: acc.reason,
          status: 'pending',
          sampleMessages: acc.sampleMessages,
          observedSenderVariations: observed,
        ),
      );
    }

    // Sort: confident recommendations first (grouped by account), unresolved last
    recommendations.sort((a, b) {
      if (a.accountId != null && b.accountId == null) return -1;
      if (a.accountId == null && b.accountId != null) return 1;
      final accComp = (a.accountId ?? '').compareTo(b.accountId ?? '');
      if (accComp != 0) return accComp;
      return b.sourceMessageCount.compareTo(a.sourceMessageCount);
    });

    final observedMap = observedVariationsByBank.map((k, v) => MapEntry(k, v.toList()));

    return PatternDiscoveryResult(
      recommendations: recommendations,
      newlyDiscoveredAccounts: newAccounts,
      observedSenderVariations: observedMap,
    );
  }

  void _processMessage({
    required String sender,
    required String text,
    required List<Account> userAccounts,
    required Map<String, List<SmsRecognitionRule>> rulesByAccount,
    required Map<String, _RecommendationAccumulator> accumulators,
    required Map<String, Set<String>> observedVariationsByBank,
  }) {
    // 1. Identify bank identifier and bank definition
    final bankId = BankDetectionService.extractBankIdentifier(sender);
    final bankDef = _bankDetectionService.identifyBank(sender, text);
    final detectedBankName = bankDef?.displayName ?? ExpenseParser.extractBankName(text) ?? bankId ?? 'Unknown Bank';

    // 2. Extract account identifier
    final rawAccount = ExpenseParser.extractAccountNumber(text);
    final digits = rawAccount?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final accountLast4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    final accountLast3 = digits.length >= 3
        ? digits.substring(digits.length - 3)
        : digits;

    // 3. Match against existing accounts
    final matchedAccounts = _findMatchingAccounts(
      bankName: detectedBankName,
      bankId: bankId,
      accountLast4: accountLast4,
      accountLast3: accountLast3,
      accounts: userAccounts,
      rulesByAccount: rulesByAccount,
    );

    if (matchedAccounts.length == 1) {
      // Confidently matched to a single existing account
      final targetAccount = matchedAccounts.first;
      final existingRules = rulesByAccount[targetAccount.id] ?? [];

      _evaluatePatternsForAccount(
        targetAccount: targetAccount,
        existingRules: existingRules,
        sender: sender,
        bankId: bankId,
        detectedBankName: detectedBankName,
        text: text,
        accountLast4: accountLast4,
        accumulators: accumulators,
        observedVariationsByBank: observedVariationsByBank,
      );
    } else if (matchedAccounts.length > 1) {
      // Ambiguous match across multiple accounts at same bank (or no account identifier to differentiate)
      _evaluateAmbiguousPattern(
        sender: sender,
        bankId: bankId,
        text: text,
        bankName: detectedBankName,
        accountLast4: accountLast4,
        accumulators: accumulators,
        observedVariationsByBank: observedVariationsByBank,
      );
    } else {
      // No existing account matched
      if (bankDef != null && accountLast4.isNotEmpty) {
        // Genuine new account candidate - handled by BankAccountDiscoveryService
      } else {
        // Unknown account or new bank identifier candidate
        _evaluateAmbiguousPattern(
          sender: sender,
          bankId: bankId,
          text: text,
          bankName: detectedBankName,
          accountLast4: accountLast4,
          accumulators: accumulators,
          observedVariationsByBank: observedVariationsByBank,
        );
      }
    }
  }

  List<Account> _findMatchingAccounts({
    required String? bankName,
    required String? bankId,
    required String accountLast4,
    required String accountLast3,
    required List<Account> accounts,
    required Map<String, List<SmsRecognitionRule>> rulesByAccount,
  }) {
    final List<Account> matches = [];

    for (final acc in accounts) {
      final accDigits = acc.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
      final accLast3 = acc.last3Digits ??
          (accDigits.length >= 3 ? accDigits.substring(accDigits.length - 3) : accDigits);

      bool bankMatches = false;
      if (bankId != null && bankId.isNotEmpty) {
        final rules = rulesByAccount[acc.id] ?? [];
        if (rules.any((r) => r.matchesBankIdentifier(bankId))) {
          bankMatches = true;
        } else if (acc.bankName.toUpperCase().contains(bankId.toUpperCase()) ||
                   bankId.toUpperCase().contains(acc.bankName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''))) {
          bankMatches = true;
        }
      }
      if (!bankMatches && bankName != null && bankName.trim().isNotEmpty) {
        if (SmsAccountResolver.bankMatches(acc, bankName)) {
          bankMatches = true;
        }
      }

      if (!bankMatches) continue;

      // If SMS has an account suffix, verify it matches this account
      if (accountLast3.isNotEmpty) {
        final suffixMatches = (accountLast4.isNotEmpty && accDigits.endsWith(accountLast4)) ||
            (accLast3.isNotEmpty && accLast3 == accountLast3);
        if (suffixMatches) {
          matches.add(acc);
        }
      } else {
        // SMS has NO account suffix.
        // If multiple accounts share this bank, adding all of them marks it ambiguous (> 1).
        matches.add(acc);
      }
    }

    return matches;
  }

  void _evaluatePatternsForAccount({
    required Account targetAccount,
    required List<SmsRecognitionRule> existingRules,
    required String sender,
    required String? bankId,
    required String detectedBankName,
    required String text,
    required String accountLast4,
    required Map<String, _RecommendationAccumulator> accumulators,
    required Map<String, Set<String>> observedVariationsByBank,
  }) {
    // ── 1. Check Bank Identifier vs Sender Pattern ───────────────────────────
    if (bankId != null && bankId.isNotEmpty) {
      final bankAlreadyKnown = existingRules.any((r) => r.matchesBankIdentifier(bankId));

      if (bankAlreadyKnown) {
        // Bank identifier already known for this account!
        // Harmless sender variation observed (VK-KGBANK-S, JD-KGBANK-S, etc.)
        // Record in observed variations, but DO NOT create a sender recommendation.
        observedVariationsByBank.putIfAbsent(bankId, () => {}).add(sender);
      } else {
        // Target account does not yet have a rule with this bankIdentifier.
        // Recommend bank_identifier as the primary Level 1 recognition key.
        final recId = 'rec_${targetAccount.id}_bank_$bankId';
        final acc = accumulators.putIfAbsent(
          recId,
          () => _RecommendationAccumulator(
            recommendationId: recId,
            accountId: targetAccount.id,
            bankName: targetAccount.bankName,
            bankIdentifier: bankId,
            accountLast4: accountLast4.isNotEmpty ? accountLast4 : (targetAccount.last3Digits ?? ''),
            patternType: 'bank_identifier',
            patternValue: bankId,
            reason: 'Recognize all senders from $bankId with stable bank identifier',
            confidence: 0.95,
          ),
        );
        acc.addEvidence(text);
        observedVariationsByBank.putIfAbsent(bankId, () => {}).add(sender);
      }
    } else {
      // Fallback for senders where no reliable bank identifier could be extracted
      final normSender = SmsRecognitionRule.normaliseSender(sender);
      bool senderAlreadyKnown = existingRules.any((r) => r.matchesSender(sender));

      if (!senderAlreadyKnown && normSender.isNotEmpty) {
        final recId = 'rec_${targetAccount.id}_sender_$normSender';
        final acc = accumulators.putIfAbsent(
          recId,
          () => _RecommendationAccumulator(
            recommendationId: recId,
            accountId: targetAccount.id,
            bankName: targetAccount.bankName,
            bankIdentifier: '',
            accountLast4: accountLast4.isNotEmpty ? accountLast4 : (targetAccount.last3Digits ?? ''),
            patternType: 'sender_fallback',
            patternValue: sender,
            reason: 'New sender fallback pattern: $sender',
            confidence: 0.85,
          ),
        );
        acc.addEvidence(text);
      }
    }

    // ── 2. Check Account Representation Pattern ──────────────────────────────
    final acMatch = _accountPatternRegex.firstMatch(text);
    if (acMatch != null) {
      final matchedPhrase = (acMatch.group(0) ?? '').trim();
      final normPhrase = normalizeAccountPattern(matchedPhrase);

      // Check if already covered in existing rules
      bool patternAlreadyKnown = false;
      for (final rule in existingRules) {
        final normRuleIdent = normalizeAccountPattern(rule.accountIdentifier);
        if (normRuleIdent.isNotEmpty &&
            (normRuleIdent == normPhrase || normRuleIdent == normalizeText(matchedPhrase))) {
          patternAlreadyKnown = true;
          break;
        }
        for (final p in rule.accountPatterns) {
          if (normalizeAccountPattern(p) == normPhrase || normalizeText(p) == normalizeText(matchedPhrase)) {
            patternAlreadyKnown = true;
            break;
          }
        }
        if (patternAlreadyKnown) break;
      }

      if (!patternAlreadyKnown && matchedPhrase.isNotEmpty) {
        final displayPattern = _cleanAccountPatternDisplay(matchedPhrase, accountLast4);
        final recId = 'rec_${targetAccount.id}_acc_${normalizeText(displayPattern)}';
        final acc = accumulators.putIfAbsent(
          recId,
          () => _RecommendationAccumulator(
            recommendationId: recId,
            accountId: targetAccount.id,
            bankName: targetAccount.bankName,
            bankIdentifier: bankId ?? '',
            accountLast4: accountLast4.isNotEmpty ? accountLast4 : (targetAccount.last3Digits ?? ''),
            patternType: 'account_pattern',
            patternValue: displayPattern,
            reason: 'New account pattern found: "$displayPattern"',
            confidence: 0.90,
          ),
        );
        acc.addEvidence(text);
      }
    }

    // ── 3. Check Transaction Wording Patterns ─────────────────────────────────
    for (final reg in _transactionWordingRegexes) {
      final match = reg.firstMatch(text);
      if (match != null) {
        final matchedWording = match.group(0)!.trim();
        final normWording = normalizeText(matchedWording);

        bool wordingAlreadyKnown = false;
        for (final rule in existingRules) {
          for (final kw in [...rule.debitKeywords, ...rule.creditKeywords, ...rule.transactionPatterns]) {
            if (normalizeText(kw) == normWording || normWording.contains(normalizeText(kw))) {
              wordingAlreadyKnown = true;
              break;
            }
          }
          if (wordingAlreadyKnown) break;
        }

        if (!wordingAlreadyKnown) {
          final isDebit = matchedWording.toLowerCase().contains('debit');
          final isCredit = matchedWording.toLowerCase().contains('credit');
          final typeReason = isDebit
              ? 'New debit-message pattern found'
              : (isCredit ? 'New credit-message pattern found' : 'New transaction message pattern found');

          final recId = 'rec_${targetAccount.id}_txn_$normWording';
          final acc = accumulators.putIfAbsent(
            recId,
            () => _RecommendationAccumulator(
              recommendationId: recId,
              accountId: targetAccount.id,
              bankName: targetAccount.bankName,
              bankIdentifier: bankId ?? '',
              accountLast4: accountLast4.isNotEmpty ? accountLast4 : (targetAccount.last3Digits ?? ''),
              patternType: 'transaction_pattern',
              patternValue: matchedWording,
              reason: '$typeReason: "$matchedWording"',
              confidence: 0.85,
            ),
          );
          acc.addEvidence(text);
        }
      }
    }

    // ── 4. Check Balance Wording Patterns ─────────────────────────────────────
    for (final reg in _balancePatternRegexes) {
      final match = reg.firstMatch(text);
      if (match != null) {
        final matchedBalance = match.group(0)!.trim();
        final normBalance = normalizeText(matchedBalance);

        bool balanceAlreadyKnown = false;
        for (final rule in existingRules) {
          if (rule.balanceHint != null && normalizeText(rule.balanceHint!).contains(normBalance)) {
            balanceAlreadyKnown = true;
            break;
          }
          for (final bp in rule.balancePatterns) {
            if (normalizeText(bp) == normBalance || normBalance.contains(normalizeText(bp))) {
              balanceAlreadyKnown = true;
              break;
            }
          }
          if (balanceAlreadyKnown) break;
        }

        if (!balanceAlreadyKnown) {
          final recId = 'rec_${targetAccount.id}_bal_$normBalance';
          final acc = accumulators.putIfAbsent(
            recId,
            () => _RecommendationAccumulator(
              recommendationId: recId,
              accountId: targetAccount.id,
              bankName: targetAccount.bankName,
              bankIdentifier: bankId ?? '',
              accountLast4: accountLast4.isNotEmpty ? accountLast4 : (targetAccount.last3Digits ?? ''),
              patternType: 'balance_pattern',
              patternValue: matchedBalance,
              reason: 'New balance pattern found: "$matchedBalance"',
              confidence: 0.80,
            ),
          );
          acc.addEvidence(text);
        }
      }
    }
  }

  void _evaluateAmbiguousPattern({
    required String sender,
    required String? bankId,
    required String text,
    required String bankName,
    required String accountLast4,
    required Map<String, _RecommendationAccumulator> accumulators,
    required Map<String, Set<String>> observedVariationsByBank,
  }) {
    if (bankId != null && bankId.isNotEmpty) {
      observedVariationsByBank.putIfAbsent(bankId, () => {}).add(sender);
      final recId = 'rec_unresolved_bank_$bankId';
      final acc = accumulators.putIfAbsent(
        recId,
        () => _RecommendationAccumulator(
          recommendationId: recId,
          accountId: null, // Unresolved - Needs Review
          bankName: bankName,
          bankIdentifier: bankId,
          accountLast4: accountLast4,
          patternType: 'bank_identifier',
          patternValue: bankId,
          reason: 'Bank identifier "$bankId" found (needs manual review or account assignment)',
          confidence: 0.75,
        ),
      );
      acc.addEvidence(text);
    } else {
      final normSender = SmsRecognitionRule.normaliseSender(sender);
      if (normSender.isEmpty) return;

      final recId = 'rec_unresolved_$normSender';
      final acc = accumulators.putIfAbsent(
        recId,
        () => _RecommendationAccumulator(
          recommendationId: recId,
          accountId: null, // Unresolved - Needs Review
          bankName: bankName,
          bankIdentifier: '',
          accountLast4: accountLast4,
          patternType: 'sender_fallback',
          patternValue: sender,
          reason: 'Unable to determine account for sender "$sender"',
          confidence: 0.70,
        ),
      );
      acc.addEvidence(text);
    }
  }

  String _cleanAccountPatternDisplay(String raw, String last4) {
    var clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  /// Applies user-approved pattern recommendations to existing account rules.
  ///
  /// Never creates duplicate accounts or duplicate rules.
  /// Refreshes `SmsAccountIndex` after updating rules.
  Future<void> applyApprovedPatterns({
    required List<AccountPatternRecommendation> approvedPatterns,
    List<Account>? accounts,
  }) async {
    if (approvedPatterns.isEmpty) return;

    final userAccounts = accounts ?? await _accountRepo.getAccounts();
    final accountMap = {for (final a in userAccounts) a.id: a};

    // Group recommendations by target accountId
    final Map<String, List<AccountPatternRecommendation>> byAccount = {};
    for (final rec in approvedPatterns) {
      if (rec.accountId == null) continue; // Skip unresolved patterns without target account
      byAccount.putIfAbsent(rec.accountId!, () => []).add(rec);
    }

    for (final entry in byAccount.entries) {
      final accountId = entry.key;
      final recs = entry.value;
      final account = accountMap[accountId];
      if (account == null) continue;

      final existingRules = await _ruleRepo.getRules(accountId);

      if (existingRules.isNotEmpty) {
        // Update the existing primary rule(s)
        for (final rule in existingRules) {
          String? updatedBankId = rule.bankIdentifier;
          final updatedSenders = List<String>.from(rule.senderPatterns);
          final updatedAccountPatterns = List<String>.from(rule.accountPatterns);
          final updatedDebitKeywords = List<String>.from(rule.debitKeywords);
          final updatedCreditKeywords = List<String>.from(rule.creditKeywords);
          final updatedTxnPatterns = List<String>.from(rule.transactionPatterns);
          final updatedBalancePatterns = List<String>.from(rule.balancePatterns);

          bool ruleModified = false;

          for (final rec in recs) {
            switch (rec.patternType) {
              case 'bank_identifier':
                if (updatedBankId == null || updatedBankId.isEmpty) {
                  updatedBankId = rec.patternValue;
                  ruleModified = true;
                }
                break;

              case 'balance_pattern':
                final normRec = normalizeText(rec.patternValue);
                final alreadyHas = updatedBalancePatterns.any((b) => normalizeText(b) == normRec);
                if (!alreadyHas) {
                  updatedBalancePatterns.add(rec.patternValue);
                  ruleModified = true;
                }
                break;

              case 'sender':
              case 'sender_fallback':
                final normRec = SmsRecognitionRule.normaliseSender(rec.patternValue);
                final alreadyHas = updatedSenders.any(
                    (s) => SmsRecognitionRule.normaliseSender(s) == normRec);
                if (!alreadyHas) {
                  updatedSenders.add(rec.patternValue);
                  ruleModified = true;
                }
                break;

              case 'account_pattern':
                final normRec = normalizeAccountPattern(rec.patternValue);
                final alreadyHas = updatedAccountPatterns.any(
                    (p) => normalizeAccountPattern(p) == normRec);
                if (!alreadyHas && normalizeAccountPattern(rule.accountIdentifier) != normRec) {
                  updatedAccountPatterns.add(rec.patternValue);
                  ruleModified = true;
                }
                break;

              case 'transaction_pattern':
                final lower = rec.patternValue.toLowerCase();
                final normRec = normalizeText(rec.patternValue);

                if (lower.contains('debit') || lower.contains('withdrawn') || lower.contains('spent')) {
                  if (!updatedDebitKeywords.any((k) => normalizeText(k) == normRec)) {
                    updatedDebitKeywords.add(rec.patternValue);
                    ruleModified = true;
                  }
                } else if (lower.contains('credit') || lower.contains('received') || lower.contains('deposit')) {
                  if (!updatedCreditKeywords.any((k) => normalizeText(k) == normRec)) {
                    updatedCreditKeywords.add(rec.patternValue);
                    ruleModified = true;
                  }
                }

                if (!updatedTxnPatterns.any((p) => normalizeText(p) == normRec)) {
                  updatedTxnPatterns.add(rec.patternValue);
                  ruleModified = true;
                }
                break;
            }
          }

          if (ruleModified) {
            final updatedRule = rule.copyWith(
              bankIdentifier: updatedBankId,
              senderPatterns: updatedSenders,
              accountPatterns: updatedAccountPatterns,
              debitKeywords: updatedDebitKeywords,
              creditKeywords: updatedCreditKeywords,
              transactionPatterns: updatedTxnPatterns,
              balancePatterns: updatedBalancePatterns,
            );
            await _ruleRepo.updateRule(updatedRule);
            debugPrint('[AccountPatternDiscovery] Updated rule ${rule.id} for account $accountId');
          }
        }
      } else {
        // No existing rule for this account: create an initial rule with approved patterns
        String? initialBankId;
        final senders = <String>[];
        final accPatterns = <String>[];
        final debitKw = <String>['debited', 'spent', 'paid'];
        final creditKw = <String>['credited', 'received'];
        final txnPatterns = <String>[];
        final balPatterns = <String>[];

        for (final rec in recs) {
          if (rec.patternType == 'bank_identifier') initialBankId = rec.patternValue;
          if (rec.bankIdentifier.isNotEmpty) initialBankId ??= rec.bankIdentifier;
          if (rec.patternType == 'sender' || rec.patternType == 'sender_fallback') senders.add(rec.patternValue);
          if (rec.patternType == 'account_pattern') accPatterns.add(rec.patternValue);
          if (rec.patternType == 'balance_pattern') balPatterns.add(rec.patternValue);
          if (rec.patternType == 'transaction_pattern') {
            final lower = rec.patternValue.toLowerCase();
            if (lower.contains('credit')) {
              creditKw.add(rec.patternValue);
            } else {
              debitKw.add(rec.patternValue);
            }
            txnPatterns.add(rec.patternValue);
          }
        }

        final initialRule = SmsRecognitionRule(
          id: '',
          accountId: accountId,
          ruleLabel: '${account.bankName} Rule',
          bankIdentifier: initialBankId,
          senderPatterns: senders.isNotEmpty ? senders : [account.bankName],
          accountIdentifier: account.accountNumber,
          accountPatterns: accPatterns,
          debitKeywords: debitKw,
          creditKeywords: creditKw,
          transactionPatterns: txnPatterns,
          balancePatterns: balPatterns,
          coversDebit: true,
          coversCredit: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        await _ruleRepo.addRule(initialRule);
        debugPrint('[AccountPatternDiscovery] Created initial rule for account $accountId');
      }
    }

    // Refresh SmsAccountIndex and UI
    try {
      await SmsAccountIndex.build(
        accountRepo: _accountRepo,
        ruleRepo: _ruleRepo,
      );
      SmsService().refreshAccounts();
    } catch (e) {
      debugPrint('[AccountPatternDiscovery] Error refreshing index: $e');
    }
  }
}

class _RecommendationAccumulator {
  final String recommendationId;
  final String? accountId;
  final String bankName;
  final String bankIdentifier;
  final String accountLast4;
  final String patternType;
  final String patternValue;
  final String reason;
  final double confidence;

  int messageCount = 0;
  final List<String> sampleMessages = [];

  _RecommendationAccumulator({
    required this.recommendationId,
    this.accountId,
    required this.bankName,
    this.bankIdentifier = '',
    required this.accountLast4,
    required this.patternType,
    required this.patternValue,
    required this.reason,
    required this.confidence,
  });

  void addEvidence(String rawMessage) {
    messageCount++;
    if (sampleMessages.length < 3) {
      final masked = _maskSensitive(rawMessage);
      if (!sampleMessages.contains(masked)) {
        sampleMessages.add(masked);
      }
    }
  }

  String _maskSensitive(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?:A/c|acct|account|card)\s*(?:no\.?|num)?\s*[:=\-]?\s*([xX\*\.\s-]*\d{3,})',
          caseSensitive: false),
      (m) => 'A/c ••••$accountLast4',
    );
  }
}
