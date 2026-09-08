import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines how MoneyTrack recognises and parses SMS messages for a specific
/// bank account. One account can have multiple rules (debit, credit, UPI…).
///
/// IMPORTANT: Rules store *structural* information about where to find values
/// in an SMS (keywords, patterns, position hints), NOT literal sample values.
/// A rule built from "Rs 25" will correctly parse "Rs 500" in the future.
class SmsRecognitionRule {
  final String id;

  /// Foreign key — the account this rule belongs to.
  final String accountId;

  /// Human-readable label: "Debit", "Credit", "UPI Debit", etc.
  final String ruleLabel;

  /// SMS sender IDs that trigger this rule.
  /// Examples: ["VK-KGBANK", "AD-KGBANK", "KGBANK"]
  final List<String> senderPatterns;

  /// Account-specific identifier extracted from SMS.
  /// Typically last 3–6 digits that appear in the SMS body.
  /// Example: "544" (matches "XXXXX544" in SMS body)
  final String accountIdentifier;

  /// Keywords that indicate a debit/expense.
  final List<String> debitKeywords;

  /// Keywords that indicate a credit/income.
  final List<String> creditKeywords;

  /// Whether this rule covers debit transactions.
  final bool coversDebit;

  /// Whether this rule covers credit transactions.
  final bool coversCredit;

  /// Hints describing how to find the amount in SMS.
  /// Stored as descriptive strings (e.g. "Rs/INR/₹ before amount").
  /// The actual parsing uses ExpenseParser; this is for display/audit.
  final String? amountHint;

  /// Hints for balance extraction.
  final String? balanceHint;

  /// Hints for reference ID extraction (UPI ref, Txn ref, Msg Id, etc.).
  final String? referenceHint;

  /// Hints for date/time extraction.
  final String? dateHint;

  /// A sample SMS message the user pasted when creating this rule.
  /// Stored for reference and future testing only — values in this SMS
  /// are NOT treated as fixed match criteria.
  final String? sampleSms;

  /// Whether this rule is active.
  final bool isEnabled;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const SmsRecognitionRule({
    required this.id,
    required this.accountId,
    required this.ruleLabel,
    required this.senderPatterns,
    required this.accountIdentifier,
    required this.debitKeywords,
    required this.creditKeywords,
    this.coversDebit = true,
    this.coversCredit = false,
    this.amountHint,
    this.balanceHint,
    this.referenceHint,
    this.dateHint,
    this.sampleSms,
    this.isEnabled = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates a copy with updated fields.
  SmsRecognitionRule copyWith({
    String? id,
    String? accountId,
    String? ruleLabel,
    List<String>? senderPatterns,
    String? accountIdentifier,
    List<String>? debitKeywords,
    List<String>? creditKeywords,
    bool? coversDebit,
    bool? coversCredit,
    String? amountHint,
    String? balanceHint,
    String? referenceHint,
    String? dateHint,
    String? sampleSms,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SmsRecognitionRule(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      ruleLabel: ruleLabel ?? this.ruleLabel,
      senderPatterns: senderPatterns ?? this.senderPatterns,
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      debitKeywords: debitKeywords ?? this.debitKeywords,
      creditKeywords: creditKeywords ?? this.creditKeywords,
      coversDebit: coversDebit ?? this.coversDebit,
      coversCredit: coversCredit ?? this.coversCredit,
      amountHint: amountHint ?? this.amountHint,
      balanceHint: balanceHint ?? this.balanceHint,
      referenceHint: referenceHint ?? this.referenceHint,
      dateHint: dateHint ?? this.dateHint,
      sampleSms: sampleSms ?? this.sampleSms,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'ruleLabel': ruleLabel,
      'senderPatterns': senderPatterns,
      'accountIdentifier': accountIdentifier,
      'debitKeywords': debitKeywords,
      'creditKeywords': creditKeywords,
      'coversDebit': coversDebit,
      'coversCredit': coversCredit,
      'amountHint': amountHint,
      'balanceHint': balanceHint,
      'referenceHint': referenceHint,
      'dateHint': dateHint,
      'sampleSms': sampleSms,
      'isEnabled': isEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory SmsRecognitionRule.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> parseStringList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return SmsRecognitionRule(
      id: map['id'] as String? ?? '',
      accountId: map['accountId'] as String? ?? '',
      ruleLabel: map['ruleLabel'] as String? ?? 'Rule',
      senderPatterns: parseStringList(map['senderPatterns']),
      accountIdentifier: map['accountIdentifier'] as String? ?? '',
      debitKeywords: parseStringList(map['debitKeywords']),
      creditKeywords: parseStringList(map['creditKeywords']),
      coversDebit: map['coversDebit'] as bool? ?? true,
      coversCredit: map['coversCredit'] as bool? ?? false,
      amountHint: map['amountHint'] as String?,
      balanceHint: map['balanceHint'] as String?,
      referenceHint: map['referenceHint'] as String?,
      dateHint: map['dateHint'] as String?,
      sampleSms: map['sampleSms'] as String?,
      isEnabled: map['isEnabled'] as bool? ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  /// Normalises a sender string for comparison (uppercase, alphanumeric only).
  static String normaliseSender(String sender) {
    return sender.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Returns true if [sender] matches any of this rule's senderPatterns.
  bool matchesSender(String sender) {
    if (senderPatterns.isEmpty) return false;
    final normSender = normaliseSender(sender);
    for (final pattern in senderPatterns) {
      final normPattern = normaliseSender(pattern);
      if (normPattern.isNotEmpty && normSender.contains(normPattern)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if [smsBody] contains the configured accountIdentifier.
  /// Uses last-N-digit suffix matching (consistent with MoneyTrack convention).
  bool matchesAccountIdentifier(String smsBody) {
    if (accountIdentifier.trim().isEmpty) return true;
    final digits = accountIdentifier.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return true;
    // Look for the digit sequence in the SMS body
    return smsBody.contains(digits);
  }
}
