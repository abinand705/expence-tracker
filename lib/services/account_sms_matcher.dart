import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/sms_recognition_rule.dart';
import 'bank_detection_service.dart';

/// Result of matching an incoming SMS to a configured account.
class AccountMatchResult {
  /// The canonical account ID of the matched user-created account.
  final String accountId;

  /// The specific rule that matched.
  final SmsRecognitionRule matchedRule;

  const AccountMatchResult({
    required this.accountId,
    required this.matchedRule,
  });
}

/// Matches incoming SMS messages to user-configured bank accounts.
///
/// FUNDAMENTAL GUARANTEE: This class NEVER creates accounts. It only
/// returns a match to an existing user-created account, or null.
///
/// No match = no transaction. This is enforced at this layer.
///
/// RECOGNITION HIERARCHY:
/// LEVEL 1: Bank Identifier (extracted from sender header, e.g. KGBANK from VK-KGBANK-S)
/// LEVEL 2: Account Identifier / Account Pattern (e.g. 1234 from A/c XX1234)
/// LEVEL 3: Transaction / Balance Pattern (e.g. debit/credit keywords)
/// LEVEL 4: Sender ID fallback (e.g. VK-KGBANK-S if bank identifier not matched)
class AccountSmsMatcher {
  /// Map from accountId to its list of enabled SMS rules.
  final Map<String, List<SmsRecognitionRule>> rulesByAccount;

  /// Map from accountId to Account (for quick lookup).
  final Map<String, Account> _accountById;

  AccountSmsMatcher({
    required List<Account> accounts,
    required this.rulesByAccount,
  })  : _accountById = {for (final a in accounts) a.id: a};

  Map<String, List<SmsRecognitionRule>> get _rulesByAccount => rulesByAccount;

  /// Attempts to match [sender] and [smsBody] to exactly one configured account.
  ///
  /// Returns:
  /// - [AccountMatchResult] if exactly one account matches
  /// - `null` if no match or ambiguous match
  ///
  /// NEVER returns a result that would cause account creation.
  AccountMatchResult? match(String sender, String smsBody) {
    final extractedBankId = BankDetectionService.extractBankIdentifier(sender);
    final List<AccountMatchResult> candidates = [];

    // Count how many enabled accounts could match this bank identifier
    int accountsSharingBank = 0;
    if (extractedBankId != null) {
      for (final entry in _rulesByAccount.entries) {
        final acc = _accountById[entry.key];
        if (acc == null || !acc.smsTrackingEnabled) continue;
        final hasBankRule = entry.value.any((r) =>
            r.isEnabled && (r.matchesBankIdentifier(extractedBankId) || r.matchesSender(sender)));
        if (hasBankRule) accountsSharingBank++;
      }
    }

    final multipleAccountsAtBank = accountsSharingBank > 1;

    for (final entry in _rulesByAccount.entries) {
      final accountId = entry.key;
      final rules = entry.value;

      // Check if this account has SMS tracking enabled
      final account = _accountById[accountId];
      if (account == null || !account.smsTrackingEnabled) continue;

      for (final rule in rules) {
        if (!rule.isEnabled) continue;

        // LEVEL 1: Check Bank Identifier match
        bool bankOrSenderMatched = false;
        if (extractedBankId != null && rule.bankIdentifier != null && rule.bankIdentifier!.isNotEmpty) {
          if (rule.matchesBankIdentifier(extractedBankId)) {
            bankOrSenderMatched = true;
          }
        }

        // LEVEL 4 (Fallback): Check Sender Pattern match
        if (!bankOrSenderMatched) {
          if (rule.matchesSender(sender)) {
            bankOrSenderMatched = true;
          }
        }

        if (!bankOrSenderMatched) continue;

        // Multiple accounts safety: If multiple accounts exist for this bank,
        // a specific account identifier in the SMS body is mandatory.
        if (multipleAccountsAtBank &&
            rule.accountIdentifier.trim().isEmpty &&
            rule.accountPatterns.isEmpty) {
          continue;
        }

        // LEVEL 2: Account identifier must appear in SMS body
        if (!rule.matchesAccountIdentifier(smsBody)) continue;

        // Both bank/sender and account identifier match — candidate found
        candidates.add(AccountMatchResult(
          accountId: accountId,
          matchedRule: rule,
        ));
        break; // One rule per account is enough for matching
      }
    }

    if (candidates.isEmpty) {
      debugPrint('[AccountSmsMatcher] no configured account matched sender=$sender (bankId=$extractedBankId)');
      return null;
    }

    if (candidates.length == 1) {
      final match = candidates.first;
      debugPrint('[AccountSmsMatcher] matched account=${match.accountId} rule=${match.matchedRule.ruleLabel}');
      return match;
    }

    // Multiple accounts matched — AMBIGUOUS. Do not guess.
    final ids = candidates.map((c) => c.accountId).join(', ');
    debugPrint('[AccountSmsMatcher] AMBIGUOUS match for sender=$sender — accounts: $ids. Skipping SMS.');
    return null;
  }

  /// Returns the account for a given accountId, or null.
  Account? getAccount(String accountId) => _accountById[accountId];
}
