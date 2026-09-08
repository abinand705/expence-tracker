import 'package:flutter/foundation.dart';
import '../models/sms_recognition_rule.dart';
import '../models/transaction.dart';
import '../utils/expense_parser.dart';
import 'bank_detection_service.dart';

/// Result of parsing a sample SMS for rule creation.
///
/// IMPORTANT: All fields here represent detected structure/patterns, NOT
/// hardcoded values. The amounts, balances, reference IDs and timestamps
/// detected from the sample are used to VALIDATE parsing only — not to
/// create literal match criteria. Future SMS with different values will
/// still be parsed correctly.
class SmsRuleSuggestion {
  /// Detected transaction type (debit/credit).
  final TransactionType? transactionType;

  /// Amount detected in the sample — shown for validation, NOT hardcoded.
  final double? detectedAmount;

  /// Account suffix detected in sample — used to pre-fill accountIdentifier.
  final String? detectedAccountSuffix;

  /// Balance detected in sample — shown for validation, NOT hardcoded.
  final double? detectedBalance;

  /// Date/time detected in sample — shown for validation, NOT hardcoded.
  final DateTime? detectedDateTime;

  /// Reference ID detected in sample — shown for validation, NOT hardcoded.
  final String? detectedReferenceId;

  /// Bank name detected in sample.
  final String? detectedBankName;

  /// Suggested debit keywords found in the sample SMS.
  final List<String> suggestedDebitKeywords;

  /// Suggested credit keywords found in the sample SMS.
  final List<String> suggestedCreditKeywords;

  /// Whether the sample could be parsed at all.
  final bool couldParse;

  /// Warning if parsing was partial.
  final String? parseWarning;

  const SmsRuleSuggestion({
    this.transactionType,
    this.detectedAmount,
    this.detectedAccountSuffix,
    this.detectedBalance,
    this.detectedDateTime,
    this.detectedReferenceId,
    this.detectedBankName,
    this.suggestedDebitKeywords = const [],
    this.suggestedCreditKeywords = const [],
    this.couldParse = false,
    this.parseWarning,
  });

  String get transactionTypeDisplay {
    if (transactionType == TransactionType.expense) return 'Debit';
    if (transactionType == TransactionType.income) return 'Credit';
    return 'Unknown';
  }
}

/// Builds an [SmsRecognitionRule] suggestion from a sample SMS message.
///
/// The builder uses the existing [ExpenseParser] to detect transaction
/// structure. The resulting rule stores PATTERN information (keywords,
/// sender, account identifier), not literal values.
///
/// GUARANTEE: Calling this with "Rs 25" as amount produces a rule that
/// will correctly parse "Rs 500", "₹1,000", "INR 42.50" in future SMS.
class SmsRuleBuilder {
  static const List<String> _defaultDebitKeywords = [
    'debited', 'debit', 'debit of', 'after debit',
    'spent', 'paid', 'payment', 'withdrawn', 'withdrawal',
    'purchase', 'transferred', 'sent', 'deducted',
    'upi debit', 'atm withdrawal', 'pos transaction',
    'DR', 'dr.',
  ];

  static const List<String> _defaultCreditKeywords = [
    'credited', 'credit', 'credit of',
    'received', 'deposited', 'deposit',
    'refund', 'cashback', 'salary credited',
    'amount received',
    'CR', 'cr.',
  ];

  /// Parses [smsBody] from [sender] and returns a rule suggestion.
  ///
  /// [knownAccountIdentifier] is the account suffix the user already
  /// entered — used to cross-validate against what is found in the SMS.
  static SmsRuleSuggestion parseSampleSms({
    required String smsBody,
    required String sender,
    String? knownAccountIdentifier,
  }) {
    if (smsBody.trim().isEmpty) {
      return const SmsRuleSuggestion(
        couldParse: false,
        parseWarning: 'Please paste an SMS message.',
      );
    }

    try {
      final parsed = ExpenseParser.parse(smsBody);
      final bankInfo = BankDetectionService().identifyBank(sender, smsBody);
      
      // Detect account suffix from SMS
      String? detectedSuffix;
      final accountMatch = ExpenseParser.extractAccountNumber(smsBody);
      if (accountMatch != null) {
        final digits = accountMatch.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length >= 3) {
          detectedSuffix = digits.substring(digits.length - 3);
        }
      }

      // Determine which keywords appear in the sample
      final bodyLower = smsBody.toLowerCase();
      final foundDebitKeywords = _defaultDebitKeywords
          .where((kw) => bodyLower.contains(kw.toLowerCase()))
          .toList();
      final foundCreditKeywords = _defaultCreditKeywords
          .where((kw) => bodyLower.contains(kw.toLowerCase()))
          .toList();

      if (parsed == null) {
        // Still extract what we can
        final balance = ExpenseParser.parseAvailableBalanceOnly(smsBody);
        return SmsRuleSuggestion(
          detectedBalance: balance,
          detectedAccountSuffix: detectedSuffix,
          detectedBankName: bankInfo?.displayName,
          suggestedDebitKeywords: foundDebitKeywords.isNotEmpty
              ? foundDebitKeywords
              : _defaultDebitKeywords.take(5).toList(),
          suggestedCreditKeywords: foundCreditKeywords.isNotEmpty
              ? foundCreditKeywords
              : _defaultCreditKeywords.take(5).toList(),
          couldParse: false,
          parseWarning:
              'Could not detect a transaction amount. Verify the SMS contains a debit/credit amount.',
        );
      }

      // Validate account identifier against known suffix
      String? parseWarning;
      if (knownAccountIdentifier != null && knownAccountIdentifier.isNotEmpty && detectedSuffix != null) {
        final knownDigits = knownAccountIdentifier.replaceAll(RegExp(r'[^0-9]'), '');
        if (knownDigits.isNotEmpty && !detectedSuffix.endsWith(knownDigits.substring(knownDigits.length - (knownDigits.length > 3 ? 3 : knownDigits.length)))) {
          parseWarning = 'The account identifier in the SMS (•••$detectedSuffix) may not match your configured account number. Please verify.';
        }
      }

      return SmsRuleSuggestion(
        transactionType: parsed.type,
        detectedAmount: parsed.amount,
        detectedAccountSuffix: detectedSuffix ?? knownAccountIdentifier,
        detectedBalance: parsed.availableBalance,
        detectedDateTime: parsed.transactionTimestamp,
        detectedReferenceId: parsed.messageId,
        detectedBankName: parsed.bankName ?? bankInfo?.displayName,
        suggestedDebitKeywords: foundDebitKeywords.isNotEmpty
            ? foundDebitKeywords
            : _defaultDebitKeywords.take(5).toList(),
        suggestedCreditKeywords: foundCreditKeywords.isNotEmpty
            ? foundCreditKeywords
            : _defaultCreditKeywords.take(5).toList(),
        couldParse: true,
        parseWarning: parseWarning,
      );
    } catch (e) {
      debugPrint('[SmsRuleBuilder] parseSampleSms error: $e');
      return SmsRuleSuggestion(
        couldParse: false,
        parseWarning: 'An error occurred while parsing: $e',
      );
    }
  }

  /// Converts a confirmed [SmsRuleSuggestion] into an [SmsRecognitionRule].
  ///
  /// The resulting rule stores STRUCTURAL information (keywords, patterns)
  /// so that future SMS with different amounts/dates/references are parsed
  /// correctly. Sample values are stored only in [sampleSms] for reference.
  static SmsRecognitionRule buildRule({
    required String accountId,
    required String ruleLabel,
    required List<String> senderPatterns,
    required String accountIdentifier,
    required SmsRuleSuggestion suggestion,
    required TransactionType transactionType,
    String? sampleSmsForReference,
    List<String>? customDebitKeywords,
    List<String>? customCreditKeywords,
  }) {
    final isDebit = transactionType == TransactionType.expense;
    final isCredit = transactionType == TransactionType.income;

    return SmsRecognitionRule(
      id: '',
      accountId: accountId,
      ruleLabel: ruleLabel,
      senderPatterns: senderPatterns,
      accountIdentifier: accountIdentifier,
      debitKeywords: customDebitKeywords ?? suggestion.suggestedDebitKeywords,
      creditKeywords: customCreditKeywords ?? suggestion.suggestedCreditKeywords,
      coversDebit: isDebit,
      coversCredit: isCredit,
      // Hints are descriptive, not literal match values
      amountHint: 'Rs/INR/₹ followed by numeric amount',
      balanceHint: suggestion.detectedBalance != null
          ? 'Bal/Balance/Avl Bal followed by numeric amount'
          : null,
      referenceHint: suggestion.detectedReferenceId != null
          ? 'UPI Ref/Txn Ref/Msg Id/UTR followed by alphanumeric reference'
          : null,
      dateHint: suggestion.detectedDateTime != null
          ? 'Date/time in dd-MM-yyyy HH:mm:ss or similar format'
          : null,
      sampleSms: sampleSmsForReference,
      isEnabled: true,
      createdAt: DateTime.now(),
    );
  }

  /// Validates a rule before saving.
  static String? validateRule(SmsRecognitionRule rule) {
    if (rule.senderPatterns.isEmpty) {
      return 'At least one sender pattern is required (e.g. VK-KGBANK).';
    }
    if (rule.accountIdentifier.trim().isEmpty) {
      return 'Account identifier is required (e.g. last 3 digits of account number).';
    }
    final identifierDigits = rule.accountIdentifier.replaceAll(RegExp(r'[^0-9]'), '');
    if (identifierDigits.length < 3) {
      return 'Account identifier must contain at least 3 digits.';
    }
    if (rule.debitKeywords.isEmpty && rule.creditKeywords.isEmpty) {
      return 'At least one debit or credit keyword is required.';
    }
    return null; // valid
  }
}
