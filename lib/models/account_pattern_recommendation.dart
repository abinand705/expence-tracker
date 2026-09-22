/// Represents a recommended SMS recognition pattern discovered from messages.
///
/// Patterns can be new senders (e.g. "HDFCBN"), new account representations
/// (e.g. "Account ending 1234", "XXXX1234"), or new transaction wording
/// (e.g. "has been debited", "UPI transaction successful").
///
/// Recommendations require explicit user confirmation before being applied to rules.
class AccountPatternRecommendation {
  final String recommendationId;

  /// Foreign key to existing [Account.id], or null if ambiguous/unresolved.
  final String? accountId;

  final String bankName;
  final String bankIdentifier;
  final String accountLast4;

  /// Pattern types:
  /// - 'bank_identifier'
  /// - 'account_pattern'
  /// - 'transaction_pattern'
  /// - 'balance_pattern'
  /// - 'sender_fallback'
  /// - 'merchant_pattern'
  /// - 'sender' (legacy alias)
  final String patternType;

  /// The exact pattern value (e.g. "KGBANK", "Account ending 1234", "UPI transaction successful").
  final String patternValue;

  final int sourceMessageCount;
  final double confidence;
  final String reason;

  /// Status: 'pending', 'approved', 'rejected', 'ignored'
  final String status;

  final List<String> sampleMessages;

  /// Sender header variations observed for this bank that are already covered
  /// by the bank identifier (e.g. ["VK-KGBANK-S", "JD-KGBANK-S", "AD-KGBANK-S"]).
  final List<String> observedSenderVariations;

  const AccountPatternRecommendation({
    required this.recommendationId,
    this.accountId,
    required this.bankName,
    this.bankIdentifier = '',
    required this.accountLast4,
    required this.patternType,
    required this.patternValue,
    this.sourceMessageCount = 1,
    this.confidence = 0.9,
    required this.reason,
    this.status = 'pending',
    this.sampleMessages = const [],
    this.observedSenderVariations = const [],
  });

  AccountPatternRecommendation copyWith({
    String? recommendationId,
    String? accountId,
    String? bankName,
    String? bankIdentifier,
    String? accountLast4,
    String? patternType,
    String? patternValue,
    int? sourceMessageCount,
    double? confidence,
    String? reason,
    String? status,
    List<String>? sampleMessages,
    List<String>? observedSenderVariations,
  }) {
    return AccountPatternRecommendation(
      recommendationId: recommendationId ?? this.recommendationId,
      accountId: accountId ?? this.accountId,
      bankName: bankName ?? this.bankName,
      bankIdentifier: bankIdentifier ?? this.bankIdentifier,
      accountLast4: accountLast4 ?? this.accountLast4,
      patternType: patternType ?? this.patternType,
      patternValue: patternValue ?? this.patternValue,
      sourceMessageCount: sourceMessageCount ?? this.sourceMessageCount,
      confidence: confidence ?? this.confidence,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      sampleMessages: sampleMessages ?? this.sampleMessages,
      observedSenderVariations: observedSenderVariations ?? this.observedSenderVariations,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recommendationId': recommendationId,
      'accountId': accountId,
      'bankName': bankName,
      'bankIdentifier': bankIdentifier,
      'accountLast4': accountLast4,
      'patternType': patternType,
      'patternValue': patternValue,
      'sourceMessageCount': sourceMessageCount,
      'confidence': confidence,
      'reason': reason,
      'status': status,
      'sampleMessages': sampleMessages,
      'observedSenderVariations': observedSenderVariations,
    };
  }

  factory AccountPatternRecommendation.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return AccountPatternRecommendation(
      recommendationId: map['recommendationId'] as String? ?? '',
      accountId: map['accountId'] as String?,
      bankName: map['bankName'] as String? ?? '',
      bankIdentifier: map['bankIdentifier'] as String? ?? '',
      accountLast4: map['accountLast4'] as String? ?? '',
      patternType: map['patternType'] as String? ?? 'account_pattern',
      patternValue: map['patternValue'] as String? ?? '',
      sourceMessageCount: (map['sourceMessageCount'] as num?)?.toInt() ?? 1,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.9,
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      sampleMessages: parseList(map['sampleMessages']),
      observedSenderVariations: parseList(map['observedSenderVariations']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountPatternRecommendation &&
          runtimeType == other.runtimeType &&
          recommendationId == other.recommendationId;

  @override
  int get hashCode => recommendationId.hashCode;
}
