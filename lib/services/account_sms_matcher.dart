import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/sms_recognition_rule.dart';

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
/// Usage during SMS scanning:
/// ```dart
/// final matcher = AccountSmsMatcher(accounts, rules);
/// final match = matcher.match(senderName, smsBody);
/// if (match == null) return; // skip — no configured account matched
/// // proceed with transaction creation using match.accountId
/// ```
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
    final List<AccountMatchResult> candidates = [];

    for (final entry in _rulesByAccount.entries) {
      final accountId = entry.key;
      final rules = entry.value;

      // Check if this account has SMS tracking enabled
      final account = _accountById[accountId];
      if (account == null || !account.smsTrackingEnabled) continue;

      for (final rule in rules) {
        if (!rule.isEnabled) continue;

        // Step 1: Sender must match
        if (!rule.matchesSender(sender)) continue;

        // Step 2: Account identifier must appear in SMS body
        if (!rule.matchesAccountIdentifier(smsBody)) continue;

        // Both sender and account identifier match — this is a candidate
        candidates.add(AccountMatchResult(
          accountId: accountId,
          matchedRule: rule,
        ));
        break; // One rule per account is enough for matching
      }
    }

    if (candidates.isEmpty) {
      debugPrint('[AccountSmsMatcher] no configured account matched sender=$sender');
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
