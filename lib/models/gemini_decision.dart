/// Classification outcomes produced by Gemini AI transaction intelligence.
enum GeminiClassification {
  sameTransaction,
  separateTransactions,
  transactionUpdate,
  nonTransaction,
  uncertain,
}

/// Structured response from Gemini AI.
class GeminiDecision {
  final GeminiClassification classification;
  final double confidence;
  final List<String> groupCandidateIds;
  final String reason;
  final String? canonicalCandidateId;

  const GeminiDecision({
    required this.classification,
    required this.confidence,
    required this.groupCandidateIds,
    required this.reason,
    this.canonicalCandidateId,
  });

  factory GeminiDecision.uncertain({
    required List<String> candidateIds,
    required String reason,
    String? canonicalId,
  }) {
    return GeminiDecision(
      classification: GeminiClassification.uncertain,
      confidence: 0.0,
      groupCandidateIds: candidateIds,
      reason: reason,
      canonicalCandidateId: canonicalId ?? (candidateIds.isNotEmpty ? candidateIds.first : null),
    );
  }

  factory GeminiDecision.fromJson(Map<String, dynamic> json) {
    GeminiClassification parseClassification(String? val) {
      switch (val?.toUpperCase().trim()) {
        case 'SAME_TRANSACTION':
          return GeminiClassification.sameTransaction;
        case 'SEPARATE_TRANSACTIONS':
          return GeminiClassification.separateTransactions;
        case 'TRANSACTION_UPDATE':
          return GeminiClassification.transactionUpdate;
        case 'NON_TRANSACTION':
          return GeminiClassification.nonTransaction;
        case 'UNCERTAIN':
        default:
          return GeminiClassification.uncertain;
      }
    }

    final rawConfidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
    // Clamp confidence strictly between 0.0 and 1.0
    final clampedConfidence = rawConfidence.clamp(0.0, 1.0);

    final rawGroup = json['groupCandidateIds'];
    List<String> candidateIds = [];
    if (rawGroup is List) {
      candidateIds = rawGroup.map((e) => e.toString()).toList();
    }

    return GeminiDecision(
      classification: parseClassification(json['classification'] as String?),
      confidence: clampedConfidence,
      groupCandidateIds: candidateIds,
      reason: json['reason'] as String? ?? '',
      canonicalCandidateId: json['canonicalCandidateId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    String classificationString() {
      switch (classification) {
        case GeminiClassification.sameTransaction:
          return 'SAME_TRANSACTION';
        case GeminiClassification.separateTransactions:
          return 'SEPARATE_TRANSACTIONS';
        case GeminiClassification.transactionUpdate:
          return 'TRANSACTION_UPDATE';
        case GeminiClassification.nonTransaction:
          return 'NON_TRANSACTION';
        case GeminiClassification.uncertain:
          return 'UNCERTAIN';
      }
    }

    return {
      'classification': classificationString(),
      'confidence': confidence,
      'groupCandidateIds': groupCandidateIds,
      'reason': reason,
      'canonicalCandidateId': canonicalCandidateId,
    };
  }
}
