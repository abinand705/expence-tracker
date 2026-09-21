import 'dart:math';
import '../models/transaction.dart' as model_tx;
import '../models/transaction_candidate.dart';
import '../models/transaction_group.dart';
import '../models/gemini_decision.dart';
import '../utils/expense_parser.dart';
import 'transaction_decision_validator.dart';

class ResolvedBatch {
  final List<model_tx.Transaction> transactionsToSave;
  final List<TransactionGroup> groupsToSave;
  final List<TransactionGroup> pendingReviewGroups;

  const ResolvedBatch({
    required this.transactionsToSave,
    required this.groupsToSave,
    required this.pendingReviewGroups,
  });
}

/// Resolves candidates, groups, and AI validation outcomes into final financial transactions.
class TransactionGroupResolver {
  const TransactionGroupResolver();

  /// Resolves all deterministic groups, AI validated groups, and single candidates into final records.
  ResolvedBatch resolveBatch({
    required List<TransactionGroup> deterministicGroups,
    required List<({ValidatedDecision validated, List<TransactionCandidate> candidates})> aiDecisions,
    required List<TransactionCandidate> unmergedCandidates,
  }) {
    final List<model_tx.Transaction> transactions = [];
    final List<TransactionGroup> groups = [];
    final List<TransactionGroup> pendingReview = [];

    // 1. Process Deterministic Groups
    for (final group in deterministicGroups) {
      final canonicalCandidate = _pickCanonicalCandidate(group.candidates ?? []);
      final tx = _buildTransactionFromCandidate(
        candidate: canonicalCandidate,
        groupId: group.groupId,
        lifecycleStatus: _determineGroupLifecycle(group.candidates ?? []),
      );
      if (tx != null) {
        transactions.add(tx);
        groups.add(group.copyWith(canonicalTransactionId: tx.id));
      } else {
        groups.add(group);
      }
    }

    // 2. Process AI Decisions
    for (final item in aiDecisions) {
      final validated = item.validated;
      final candidates = item.candidates;
      final decision = validated.decision;

      if (validated.status == ValidationStatus.approvedAutoApply) {
        if (decision.classification == GeminiClassification.sameTransaction ||
            decision.classification == GeminiClassification.transactionUpdate) {
          // Merge candidates into ONE canonical transaction
          final canonical = _pickCanonicalFromId(candidates, decision.canonicalCandidateId);
          final groupId = _generateGroupId(canonical);
          final lifecycle = _determineGroupLifecycle(candidates);

          final tx = _buildTransactionFromCandidate(
            candidate: canonical,
            groupId: groupId,
            lifecycleStatus: lifecycle,
          );

          final group = TransactionGroup(
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
            confidence: decision.confidence,
            resolutionMethod: TransactionResolutionMethod.gemini,
            aiReason: decision.reason,
            canonicalTransactionId: tx?.id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            candidates: candidates,
          );

          if (tx != null) transactions.add(tx);
          groups.add(group);
        } else if (decision.classification == GeminiClassification.nonTransaction) {
          // Informational / Non-transaction SMS -> NO transaction created!
          final groupId = _generateGroupId(candidates.first);
          final group = TransactionGroup(
            groupId: groupId,
            candidateIds: candidates.map((c) => c.candidateId).toList(),
            canonicalAmount: candidates.first.amount,
            canonicalType: candidates.first.transactionType,
            canonicalMerchant: candidates.first.merchant ?? 'Informational SMS',
            accountId: candidates.first.accountId,
            bankName: candidates.first.bankName,
            transactionDate: candidates.first.transactionDate,
            status: TransactionGroupStatus.ignored,
            confidence: decision.confidence,
            resolutionMethod: TransactionResolutionMethod.gemini,
            aiReason: decision.reason,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            candidates: candidates,
          );
          groups.add(group);
        } else {
          // SEPARATE_TRANSACTIONS: Keep each candidate as a separate transaction
          for (final c in candidates) {
            final gId = _generateGroupId(c);
            final tx = _buildTransactionFromCandidate(candidate: c, groupId: gId);
            if (tx != null) transactions.add(tx);
            groups.add(TransactionGroup(
              groupId: gId,
              candidateIds: [c.candidateId],
              canonicalAmount: c.amount,
              canonicalType: c.transactionType,
              canonicalMerchant: c.merchant ?? 'Unknown Merchant',
              accountId: c.accountId,
              bankName: c.bankName,
              transactionDate: c.transactionDate,
              referenceNumber: c.upiReference ?? c.referenceNumber,
              status: TransactionGroupStatus.confirmed,
              confidence: decision.confidence,
              resolutionMethod: TransactionResolutionMethod.gemini,
              aiReason: decision.reason,
              canonicalTransactionId: tx?.id,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              candidates: [c],
            ));
          }
        }
      } else if (validated.status == ValidationStatus.needsReview) {
        // Create a Pending Review group
        final canonical = candidates.first;
        final groupId = _generateGroupId(canonical);
        final reviewGroup = TransactionGroup(
          groupId: groupId,
          candidateIds: candidates.map((c) => c.candidateId).toList(),
          canonicalAmount: canonical.amount,
          canonicalType: canonical.transactionType,
          canonicalMerchant: canonical.merchant ?? 'Unknown Merchant',
          accountId: canonical.accountId,
          bankName: canonical.bankName,
          transactionDate: canonical.transactionDate,
          referenceNumber: canonical.upiReference ?? canonical.referenceNumber,
          status: TransactionGroupStatus.pendingReview,
          confidence: decision.confidence,
          resolutionMethod: TransactionResolutionMethod.gemini,
          aiReason: decision.reason,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          candidates: candidates,
        );
        pendingReview.add(reviewGroup);
        groups.add(reviewGroup);

        // Keep candidates safe by writing them as individual separate transactions for now
        // so no financial data is ever lost before manual review
        for (final c in candidates) {
          final gId = _generateGroupId(c);
          final tx = _buildTransactionFromCandidate(candidate: c, groupId: gId);
          if (tx != null) transactions.add(tx);
        }
      } else {
        // REJECTED / UNCERTAIN -> Fallback: Keep as separate transactions
        for (final c in candidates) {
          final gId = _generateGroupId(c);
          final tx = _buildTransactionFromCandidate(candidate: c, groupId: gId);
          if (tx != null) transactions.add(tx);
          groups.add(TransactionGroup(
            groupId: gId,
            candidateIds: [c.candidateId],
            canonicalAmount: c.amount,
            canonicalType: c.transactionType,
            canonicalMerchant: c.merchant ?? 'Unknown Merchant',
            accountId: c.accountId,
            bankName: c.bankName,
            transactionDate: c.transactionDate,
            referenceNumber: c.upiReference ?? c.referenceNumber,
            status: TransactionGroupStatus.confirmed,
            confidence: 1.0,
            resolutionMethod: TransactionResolutionMethod.deterministicMatch,
            aiReason: 'AI rejected/uncertain fallback: ${validated.rejectionReason ?? 'Unknown'}',
            canonicalTransactionId: tx?.id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            candidates: [c],
          ));
        }
      }
    }

    // 3. Process Unmerged Candidates
    for (final c in unmergedCandidates) {
      final gId = _generateGroupId(c);
      final tx = _buildTransactionFromCandidate(candidate: c, groupId: gId);
      if (tx != null) transactions.add(tx);
      groups.add(TransactionGroup(
        groupId: gId,
        candidateIds: [c.candidateId],
        canonicalAmount: c.amount,
        canonicalType: c.transactionType,
        canonicalMerchant: c.merchant ?? 'Unknown Merchant',
        accountId: c.accountId,
        bankName: c.bankName,
        transactionDate: c.transactionDate,
        referenceNumber: c.upiReference ?? c.referenceNumber,
        status: TransactionGroupStatus.confirmed,
        confidence: 1.0,
        resolutionMethod: TransactionResolutionMethod.newTransaction,
        canonicalTransactionId: tx?.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        candidates: [c],
      ));
    }

    return ResolvedBatch(
      transactionsToSave: transactions,
      groupsToSave: groups,
      pendingReviewGroups: pendingReview,
    );
  }

  model_tx.Transaction? _buildTransactionFromCandidate({
    required TransactionCandidate candidate,
    required String groupId,
    String? lifecycleStatus,
  }) {
    // If the candidate was a pure reversal/refund without net debit, or failed payment
    if (candidate.lifecycleState == 'failed') {
      return null;
    }

    // If lifecycle indicates reversed, mark description or handle appropriately
    String? customTitle = candidate.merchant;
    String? notes;
    if (lifecycleStatus == 'reversed') {
      notes = 'Transaction reversed';
      customTitle = '${candidate.merchant ?? 'Transaction'} (Reversed)';
    }

    return model_tx.Transaction(
      id: candidate.candidateId,
      amount: candidate.amount,
      type: candidate.transactionType,
      merchant: candidate.merchant ?? 'Unknown Merchant',
      category: ExpenseParser.guessCategory(candidate.merchant),
      date: candidate.transactionDate,
      subtitle: candidate.bankName ?? candidate.sender,
      rawMessage: candidate.rawMessage,
      source: 'sms',
      transactionSource: 'sms',
      isManual: false,
      accountId: candidate.accountId,
      accountNumber: candidate.accountLast4,
      upiReference: candidate.upiReference ?? candidate.referenceNumber,
      sourceId: groupId,
      notes: notes,
      customTitle: customTitle,
    );
  }

  TransactionCandidate _pickCanonicalCandidate(List<TransactionCandidate> list) {
    if (list.isEmpty) throw ArgumentError('Candidate list cannot be empty');
    TransactionCandidate best = list.first;
    for (final c in list) {
      final cScore = (c.upiReference != null || c.referenceNumber != null ? 3 : 0) +
          (c.merchant != null && c.merchant!.isNotEmpty && c.merchant != 'Unknown Merchant' ? 2 : 0) +
          (c.balance != null ? 1 : 0);
      final bestScore = (best.upiReference != null || best.referenceNumber != null ? 3 : 0) +
          (best.merchant != null && best.merchant!.isNotEmpty && best.merchant != 'Unknown Merchant' ? 2 : 0) +
          (best.balance != null ? 1 : 0);
      if (cScore > bestScore) {
        best = c;
      }
    }
    return best;
  }

  TransactionCandidate _pickCanonicalFromId(List<TransactionCandidate> list, String? id) {
    if (id != null) {
      final match = list.where((c) => c.candidateId == id).firstOrNull;
      if (match != null) return match;
    }
    return _pickCanonicalCandidate(list);
  }

  String _determineGroupLifecycle(List<TransactionCandidate> candidates) {
    final states = candidates.map((c) => c.lifecycleState).toSet();
    if (states.contains('reversed')) return 'reversed';
    if (states.contains('refund')) return 'refund';
    if (states.contains('successful')) return 'successful';
    if (states.contains('initiated')) return 'initiated';
    return 'debited';
  }

  String _generateGroupId(TransactionCandidate c) {
    final hashSub = c.rawMessageHash.substring(0, min(16, c.rawMessageHash.length));
    return 'tg_${hashSub}_${c.transactionDate.millisecondsSinceEpoch}';
  }
}
