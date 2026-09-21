import 'dart:math';
import '../models/transaction_candidate.dart';
import '../models/transaction_group.dart';

/// Result of matching a collection of transaction candidates.
class MatchResult {
  final List<TransactionGroup> deterministicGroups;
  final List<List<TransactionCandidate>> ambiguousGroups;
  final List<TransactionCandidate> unmergedCandidates;

  const MatchResult({
    required this.deterministicGroups,
    required this.ambiguousGroups,
    required this.unmergedCandidates,
  });
}

/// Implements multi-level deterministic matching before involving Gemini AI.
class TransactionMatcher {
  final Duration timeWindow;

  const TransactionMatcher({
    this.timeWindow = const Duration(minutes: 5),
  });

  /// Groups related candidates using:
  /// - Level 1: Exact reference matching
  /// - Level 2: Strong deterministic matching (same account, bank, amount, close time, matching merchant)
  /// - Level 3: Fuzzy matching & lifecycle progression
  /// - Ambiguous detection: candidates that are related but uncertain, passed to Gemini.
  MatchResult matchCandidates(List<TransactionCandidate> candidates) {
    if (candidates.isEmpty) {
      return const MatchResult(
        deterministicGroups: [],
        ambiguousGroups: [],
        unmergedCandidates: [],
      );
    }

    // Step 1: Group candidates by bucket (Account + Bank) to avoid cross-account/bank pollution
    final Map<String, List<TransactionCandidate>> buckets = {};
    for (final candidate in candidates) {
      final key = _makeBucketKey(candidate);
      buckets.putIfAbsent(key, () => []).add(candidate);
    }

    final List<TransactionGroup> deterministicGroups = [];
    final List<List<TransactionCandidate>> ambiguousGroups = [];
    final List<TransactionCandidate> unmergedCandidates = [];

    for (final bucket in buckets.values) {
      // Sort chronologically within bucket
      bucket.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

      final Set<String> processedCandidateIds = {};

      for (int i = 0; i < bucket.length; i++) {
        final current = bucket[i];
        if (processedCandidateIds.contains(current.candidateId)) continue;

        final List<TransactionCandidate> relatedGroup = [current];

        for (int j = i + 1; j < bucket.length; j++) {
          final other = bucket[j];
          if (processedCandidateIds.contains(other.candidateId)) continue;

          // Check if other is within time window from current (or subsequent related candidates)
          final timeDiff = other.transactionDate.difference(current.transactionDate).abs();
          if (timeDiff > timeWindow) {
            // Because bucket is sorted chronologically, candidates beyond timeWindow won't match current
            // unless linked by exact reference across a broader time
            if (!_hasMatchingReference(current, other)) {
              continue;
            }
          }

          final relation = evaluateRelationship(current, other);
          if (relation == CandidateRelation.exactReference ||
              relation == CandidateRelation.strongDeterministic ||
              relation == CandidateRelation.fuzzyLifecycle ||
              relation == CandidateRelation.ambiguous) {
            relatedGroup.add(other);
          }
        }

        if (relatedGroup.length == 1) {
          // Single standalone candidate
          unmergedCandidates.add(current);
          processedCandidateIds.add(current.candidateId);
        } else {
          // Multiple candidates grouped
          for (final c in relatedGroup) {
            processedCandidateIds.add(c.candidateId);
          }

          final groupClassification = _classifyGroup(relatedGroup);
          if (groupClassification.isAmbiguous) {
            ambiguousGroups.add(relatedGroup);
          } else {
            final group = _buildDeterministicGroup(
              candidates: relatedGroup,
              method: groupClassification.method,
            );
            deterministicGroups.add(group);
          }
        }
      }
    }

    return MatchResult(
      deterministicGroups: deterministicGroups,
      ambiguousGroups: ambiguousGroups,
      unmergedCandidates: unmergedCandidates,
    );
  }

  /// Evaluates relationship between two candidates.
  CandidateRelation evaluateRelationship(TransactionCandidate a, TransactionCandidate b) {
    // 1. Account & Bank Compatibility Check
    if (!_areAccountsCompatible(a, b) || !_areBanksCompatible(a, b)) {
      return CandidateRelation.unrelated;
    }

    // 2. Reference Number Check
    final refA = _normalizeRef(a.upiReference ?? a.referenceNumber);
    final refB = _normalizeRef(b.upiReference ?? b.referenceNumber);

    if (refA.isNotEmpty && refB.isNotEmpty) {
      if (refA == refB) {
        // Level 1: Exact Reference Match
        if (_areAmountsCompatible(a.amount, b.amount)) {
          return CandidateRelation.exactReference;
        }
      } else {
        // STRICT RULE: Different non-empty references mean different transactions!
        return CandidateRelation.unrelated;
      }
    }

    // 3. Amount Compatibility Check
    // If amounts differ significantly (more than 1 paisa)
    if (!_areAmountsCompatible(a.amount, b.amount)) {
      return CandidateRelation.unrelated;
    }

    // 4. Time Window Check
    final timeDiff = a.transactionDate.difference(b.transactionDate).abs();
    if (timeDiff > timeWindow) {
      return CandidateRelation.unrelated;
    }

    // 5. Check Lifecycle
    if (_isLifecycleProgression(a, b)) {
      return CandidateRelation.fuzzyLifecycle;
    }

    // 6. Level 2: Strong Deterministic Match
    // If both have same normalized merchant and same transaction type
    if (a.normalizedMerchant.isNotEmpty &&
        b.normalizedMerchant.isNotEmpty &&
        a.normalizedMerchant == b.normalizedMerchant &&
        a.transactionType == b.transactionType) {
      return CandidateRelation.strongDeterministic;
    }

    // 7. Level 3: Fuzzy Merchant Match
    if (a.normalizedMerchant.isNotEmpty && b.normalizedMerchant.isNotEmpty) {
      if (_areMerchantsFuzzyMatch(a.normalizedMerchant, b.normalizedMerchant)) {
        return CandidateRelation.fuzzyLifecycle;
      }
      // Different known merchants (e.g. Amazon vs Flipkart) -> UNRELATED!
      return CandidateRelation.unrelated;
    }

    // 8. One candidate has merchant and other is missing / generic
    // (e.g. "Rs.500 debited" vs "Rs.500 to Amazon") -> AMBIGUOUS!
    // Requires Gemini to analyze transaction lifecycle context.
    return CandidateRelation.ambiguous;
  }

  bool _areAccountsCompatible(TransactionCandidate a, TransactionCandidate b) {
    if (a.accountId != null && b.accountId != null && a.accountId != b.accountId) {
      return false;
    }
    if (a.accountLast4 != null &&
        b.accountLast4 != null &&
        a.accountLast4!.isNotEmpty &&
        b.accountLast4!.isNotEmpty &&
        a.accountLast4 != b.accountLast4) {
      return false;
    }
    return true;
  }

  bool _areBanksCompatible(TransactionCandidate a, TransactionCandidate b) {
    if (a.bankName == null || b.bankName == null) return true;
    final bA = a.bankName!.trim().toLowerCase();
    final bB = b.bankName!.trim().toLowerCase();
    if (bA.isEmpty || bB.isEmpty) return true;
    return bA == bB || bA.contains(bB) || bB.contains(bA);
  }

  bool _areAmountsCompatible(double a, double b) {
    return (a - b).abs() < 0.01;
  }

  bool _hasMatchingReference(TransactionCandidate a, TransactionCandidate b) {
    final refA = _normalizeRef(a.upiReference ?? a.referenceNumber);
    final refB = _normalizeRef(b.upiReference ?? b.referenceNumber);
    return refA.isNotEmpty && refB.isNotEmpty && refA == refB;
  }

  String _normalizeRef(String? ref) {
    if (ref == null) return '';
    return ref.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  bool _isLifecycleProgression(TransactionCandidate a, TransactionCandidate b) {
    final sA = a.lifecycleState;
    final sB = b.lifecycleState;
    // Initiated -> Successful
    if ((sA == 'initiated' && sB == 'successful') ||
        (sA == 'successful' && sB == 'initiated')) {
      return true;
    }
    // Debited -> Reversed
    if ((sA == 'debited' && sB == 'reversed') ||
        (sA == 'reversed' && sB == 'debited')) {
      return true;
    }
    // Debited -> Refund
    if ((sA == 'debited' && sB == 'refund') ||
        (sA == 'refund' && sB == 'debited')) {
      return true;
    }
    return false;
  }

  bool _areMerchantsFuzzyMatch(String m1, String m2) {
    if (m1 == m2) return true;
    // Token containment (e.g. "amazon" in "amazon india", "amazon pay")
    if (m1.contains(m2) || m2.contains(m1)) return true;

    // Levenshtein similarity
    final dist = _levenshtein(m1, m2);
    final maxLen = max(m1.length, m2.length);
    if (maxLen == 0) return true;
    final similarity = 1.0 - (dist / maxLen);
    return similarity >= 0.75;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i <= t.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }

  String _makeBucketKey(TransactionCandidate c) {
    final acc = c.accountId ?? c.accountLast4 ?? 'unknown_acc';
    final bank = c.bankName?.toLowerCase().replaceAll(RegExp(r'\s+'), '') ?? 'unknown_bank';
    return '$acc::$bank';
  }

  _GroupClassification _classifyGroup(List<TransactionCandidate> group) {
    bool hasExactRef = false;
    bool hasStrongMatch = false;
    bool hasAmbiguous = false;

    for (int i = 0; i < group.length; i++) {
      for (int j = i + 1; j < group.length; j++) {
        final rel = evaluateRelationship(group[i], group[j]);
        if (rel == CandidateRelation.exactReference) {
          hasExactRef = true;
        } else if (rel == CandidateRelation.strongDeterministic) {
          hasStrongMatch = true;
        } else if (rel == CandidateRelation.ambiguous) {
          hasAmbiguous = true;
        }
      }
    }

    if (hasExactRef) {
      return const _GroupClassification(
        isAmbiguous: false,
        method: TransactionResolutionMethod.exactReference,
      );
    }
    if (hasAmbiguous) {
      return const _GroupClassification(
        isAmbiguous: true,
        method: TransactionResolutionMethod.gemini,
      );
    }
    if (hasStrongMatch) {
      return const _GroupClassification(
        isAmbiguous: false,
        method: TransactionResolutionMethod.deterministicMatch,
      );
    }

    return const _GroupClassification(
      isAmbiguous: false,
      method: TransactionResolutionMethod.fuzzyMatch,
    );
  }

  TransactionGroup _buildDeterministicGroup({
    required List<TransactionCandidate> candidates,
    required TransactionResolutionMethod method,
  }) {
    // Pick the canonical candidate (the one with the richest merchant/reference)
    TransactionCandidate canonical = candidates.first;
    for (final c in candidates) {
      final cScore = (c.referenceNumber != null || c.upiReference != null ? 2 : 0) +
          (c.merchant != null && c.merchant!.isNotEmpty && c.merchant != 'Unknown Merchant' ? 2 : 0) +
          (c.balance != null ? 1 : 0);
      final canScore = (canonical.referenceNumber != null || canonical.upiReference != null ? 2 : 0) +
          (canonical.merchant != null && canonical.merchant!.isNotEmpty && canonical.merchant != 'Unknown Merchant' ? 2 : 0) +
          (canonical.balance != null ? 1 : 0);
      if (cScore > canScore) {
        canonical = c;
      }
    }

    // Generate deterministic group ID
    final groupHash = canonical.rawMessageHash.substring(0, min(16, canonical.rawMessageHash.length));
    final groupId = 'tg_${groupHash}_${canonical.transactionDate.millisecondsSinceEpoch}';

    return TransactionGroup(
      groupId: groupId,
      candidateIds: candidates.map((c) => c.candidateId).toList(),
      canonicalAmount: canonical.amount,
      canonicalType: canonical.transactionType,
      canonicalMerchant: canonical.merchant ?? 'Unknown Merchant',
      accountId: canonical.accountId,
      bankName: canonical.bankName,
      transactionDate: canonical.transactionDate,
      referenceNumber: canonical.upiReference ?? canonical.referenceNumber,
      status: TransactionGroupStatus.confirmed,
      confidence: 1.0,
      resolutionMethod: method,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      candidates: candidates,
    );
  }
}

enum CandidateRelation {
  exactReference,
  strongDeterministic,
  fuzzyLifecycle,
  ambiguous,
  unrelated,
}

class _GroupClassification {
  final bool isAmbiguous;
  final TransactionResolutionMethod method;

  const _GroupClassification({
    required this.isAmbiguous,
    required this.method,
  });
}
