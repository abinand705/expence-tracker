import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/sms_recognition_rule.dart';
import '../repositories/account_repository.dart';
import '../repositories/sms_rule_repository.dart';
import 'account_sms_matcher.dart';

/// In-memory index for fast SMS → account matching during bulk SMS scanning.
///
/// Built ONCE at the start of an SMS scan session and reused for all messages
/// in that session. This avoids per-message Firestore queries.
///
/// PERFORMANCE: Load accounts + rules → build index → process N messages.
/// No Firestore calls during message processing.
class SmsAccountIndex {
  final AccountSmsMatcher matcher;
  final List<Account> accounts;
  final Map<String, List<SmsRecognitionRule>> rulesByAccount;


  /// Total number of accounts with SMS tracking enabled.
  int get enabledAccountCount => accounts.where((a) => a.smsTrackingEnabled).length;

  /// Total number of configured rules across all enabled accounts.
  int get totalRuleCount =>
      rulesByAccount.values.fold(0, (sum, rules) => sum + rules.length);

  SmsAccountIndex._({
    required this.matcher,
    required this.accounts,
    required this.rulesByAccount,
  });

  /// Builds an index from pre-loaded data — for use in unit tests.
  ///
  /// [accounts] should have smsTrackingEnabled=true for accounts to be matched.
  /// [rulesByAccount] maps accountId to its list of enabled rules.
  factory SmsAccountIndex.fromData({
    required List<Account> accounts,
    required Map<String, List<SmsRecognitionRule>> rulesByAccount,
  }) {
    final matcher = AccountSmsMatcher(
      accounts: accounts,
      rulesByAccount: rulesByAccount,
    );
    return SmsAccountIndex._(
      matcher: matcher,
      accounts: accounts,
      rulesByAccount: rulesByAccount,
    );
  }

  /// Builds the index by loading accounts and rules from Firestore.
  ///
  /// Call this ONCE before processing a batch of SMS messages.
  static Future<SmsAccountIndex> build({
    AccountRepository? accountRepo,
    SmsRuleRepository? ruleRepo,
  }) async {
    final repo = accountRepo ?? AccountRepository();
    final ruleRepository = ruleRepo ?? SmsRuleRepository();

    List<Account> accounts = [];
    Map<String, List<SmsRecognitionRule>> rulesByAccount = {};

    try {
      accounts = await repo.getAccounts();
      debugPrint('[SmsAccountIndex] loaded ${accounts.length} accounts');

      // Only load rules for accounts with SMS tracking enabled
      final enabledAccounts = accounts.where((a) => a.smsTrackingEnabled).toList();
      debugPrint('[SmsAccountIndex] ${enabledAccounts.length} accounts have SMS tracking enabled');

      if (enabledAccounts.isNotEmpty) {
        rulesByAccount = await ruleRepository.getAllRulesByAccount();
        final totalRules = rulesByAccount.values.fold(0, (s, r) => s + r.length);
        debugPrint('[SmsAccountIndex] loaded $totalRules rules across ${rulesByAccount.length} accounts');
      }
    } catch (e) {
      debugPrint('[SmsAccountIndex] build error: $e');
      // Return empty index — safe fallback (no SMS will create transactions)
    }

    final matcher = AccountSmsMatcher(
      accounts: accounts,
      rulesByAccount: rulesByAccount,
    );

    return SmsAccountIndex._(
      matcher: matcher,
      accounts: accounts,
      rulesByAccount: rulesByAccount,
    );
  }

  /// Matches an incoming SMS to a configured account.
  ///
  /// Returns [AccountMatchResult] if exactly one account matches, null otherwise.
  /// NEVER causes account creation.
  AccountMatchResult? match(String sender, String smsBody) {
    return matcher.match(sender, smsBody);
  }

  /// Returns the [Account] for [accountId], or null if not found.
  Account? getAccount(String accountId) => matcher.getAccount(accountId);

  /// Returns a copy of all loaded accounts (for balance update operations).
  List<Account> get allAccounts => List.unmodifiable(accounts);
}
