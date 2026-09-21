import 'package:flutter/foundation.dart';
import '../models/gemini_config.dart';
import '../models/gemini_decision.dart';
import '../models/transaction_candidate.dart';

enum ValidationStatus {
  approvedAutoApply,
  needsReview,
  rejected,
}

class ValidatedDecision {
  final ValidationStatus status;
  final GeminiDecision decision;
  final String? rejectionReason;

  const ValidatedDecision({
    required this.status,
    required this.decision,
    this.rejectionReason,
  });
}

/// Validates Gemini decisions against financial consistency constraints and confidence thresholds.
class TransactionDecisionValidator {
  const TransactionDecisionValidator();

  ValidatedDecision validate({
    required GeminiDecision decision,
    required List<TransactionCandidate> candidates,
    required GeminiConfig config,
  }) {
    // 1. If Gemini was already uncertain or classified as separate
    if (decision.classification == GeminiClassification.uncertain) {
      return ValidatedDecision(
        status: ValidationStatus.needsReview,
        decision: decision,
      );
    }

    if (decision.classification == GeminiClassification.separateTransactions) {
      return ValidatedDecision(
        status: ValidationStatus.approvedAutoApply,
        decision: decision,
      );
    }

    // 2. Financial Consistency Checks for SAME_TRANSACTION and TRANSACTION_UPDATE
    if (decision.classification == GeminiClassification.sameTransaction ||
        decision.classification == GeminiClassification.transactionUpdate) {
      final groupCandidates = candidates
          .where((c) => decision.groupCandidateIds.contains(c.candidateId))
          .toList();

      if (groupCandidates.length < 2) {
        return ValidatedDecision(
          status: ValidationStatus.rejected,
          decision: decision,
          rejectionReason: 'Group has fewer than 2 valid candidates',
        );
      }

      // Check amount compatibility (allow at most 0.01 tolerance)
      final baseAmount = groupCandidates.first.amount;
      for (final c in groupCandidates) {
        if ((c.amount - baseAmount).abs() > 0.01) {
          debugPrint('[VALIDATOR] REJECTED: Incompatible amounts (${c.amount} vs $baseAmount)');
          return ValidatedDecision(
            status: ValidationStatus.rejected,
            decision: decision,
            rejectionReason: 'Incompatible amounts: ${c.amount} vs $baseAmount',
          );
        }
      }

      // Check account & bank compatibility
      for (int i = 0; i < groupCandidates.length; i++) {
        for (int j = i + 1; j < groupCandidates.length; j++) {
          final a = groupCandidates[i];
          final b = groupCandidates[j];

          // If accounts are explicitly conflicting
          if (a.accountId != null && b.accountId != null && a.accountId != b.accountId) {
            debugPrint('[VALIDATOR] REJECTED: Contradictory account IDs (${a.accountId} vs ${b.accountId})');
            return ValidatedDecision(
              status: ValidationStatus.rejected,
              decision: decision,
              rejectionReason: 'Contradictory account IDs',
            );
          }

          if (a.accountLast4 != null &&
              b.accountLast4 != null &&
              a.accountLast4!.isNotEmpty &&
              b.accountLast4!.isNotEmpty &&
              a.accountLast4 != b.accountLast4) {
            debugPrint('[VALIDATOR] REJECTED: Contradictory account suffixes (${a.accountLast4} vs ${b.accountLast4})');
            return ValidatedDecision(
              status: ValidationStatus.rejected,
              decision: decision,
              rejectionReason: 'Contradictory account suffixes',
            );
          }
        }
      }
    }

    // 3. Confidence Threshold Policy
    if (decision.confidence >= config.confidenceThreshold) {
      return ValidatedDecision(
        status: ValidationStatus.approvedAutoApply,
        decision: decision,
      );
    } else if (decision.confidence >= config.reviewThreshold) {
      return ValidatedDecision(
        status: ValidationStatus.needsReview,
        decision: decision,
      );
    } else {
      return ValidatedDecision(
        status: ValidationStatus.rejected,
        decision: decision,
        rejectionReason: 'Confidence too low (${decision.confidence} < ${config.reviewThreshold})',
      );
    }
  }
}
