import 'dart:convert';
import 'dart:developer' as developer;
import 'package:crypto/crypto.dart';
import '../models/transaction.dart';
import '../utils/expense_parser.dart';
import 'sms_account_resolver.dart';

enum TransactionDuplicateReason {
  none,
  exactSms,
  referenceId,
  probableTimeWindow,
  ambiguous,
}

class TransactionIdentityResult {
  final bool isDuplicate;
  final TransactionDuplicateReason reason;
  final String? matchedTransactionId;
  final String canonicalId;

  const TransactionIdentityResult({
    required this.isDuplicate,
    required this.reason,
    this.matchedTransactionId,
    required this.canonicalId,
  });

  factory TransactionIdentityResult.newTransaction(String canonicalId) {
    return TransactionIdentityResult(
      isDuplicate: false,
      reason: TransactionDuplicateReason.none,
      canonicalId: canonicalId,
    );
  }

  factory TransactionIdentityResult.exactDuplicate({
    required String matchedId,
    required String canonicalId,
  }) {
    return TransactionIdentityResult(
      isDuplicate: true,
      reason: TransactionDuplicateReason.exactSms,
      matchedTransactionId: matchedId,
      canonicalId: canonicalId,
    );
  }

  factory TransactionIdentityResult.referenceDuplicate({
    required String matchedId,
    required String canonicalId,
  }) {
    return TransactionIdentityResult(
      isDuplicate: true,
      reason: TransactionDuplicateReason.referenceId,
      matchedTransactionId: matchedId,
      canonicalId: canonicalId,
    );
  }

  factory TransactionIdentityResult.probableDuplicate({
    required String matchedId,
    required String canonicalId,
  }) {
    return TransactionIdentityResult(
      isDuplicate: true,
      reason: TransactionDuplicateReason.probableTimeWindow,
      matchedTransactionId: matchedId,
      canonicalId: canonicalId,
    );
  }

  factory TransactionIdentityResult.ambiguous(String canonicalId) {
    return TransactionIdentityResult(
      isDuplicate: false,
      reason: TransactionDuplicateReason.ambiguous,
      canonicalId: canonicalId,
    );
  }
}

class DuplicateCleanupPlan {
  final List<Transaction> transactionsToUpdate;
  final List<String> duplicateIdsToDelete;
  final int duplicatesFound;

  const DuplicateCleanupPlan({
    required this.transactionsToUpdate,
    required this.duplicateIdsToDelete,
    required this.duplicatesFound,
  });
}

class TransactionIdentityService {
  /// Normalize reference IDs for robust comparison across SMS/statement formats
  static String normalizeReference(String? ref) {
    if (ref == null) return '';
    return ref.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Normalize raw SMS body text for byte-identical comparisons
  static String normalizeRawMessage(String? text) {
    if (text == null) return '';
    return text.trim();
  }

  /// Normalize account representation (extract last 3 digits or identifier)
  static String normalizeAccount(String? rawAccount) {
    if (rawAccount == null || rawAccount.trim().isEmpty) return 'unknown';
    final digits = rawAccount.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 3) {
      return digits.substring(digits.length - 3);
    }
    return rawAccount.trim().toLowerCase();
  }

  /// Builds a canonical reference key: ref_bank_account_referenceId
  static String computeReferenceKey({
    String? bank,
    String? account,
    required String referenceId,
  }) {
    final normBank = SmsAccountResolver.normalizeBankIdentifier(bank ?? '');
    final normAcc = normalizeAccount(account);
    final normRef = normalizeReference(referenceId);
    return 'ref_${normBank}_${normAcc}_$normRef';
  }

  /// Generates deterministic document ID for a transaction
  /// Does NOT include SMS message ID, raw SMS text, title, category, or merchant name.
  static String generateDeterministicId({
    required ParsedExpense parsed,
    required DateTime txDate,
    String? accountId,
    String? bankId,
    required String senderName,
    required String rawText,
  }) {
    final normBank = SmsAccountResolver.normalizeBankIdentifier(bankId ?? parsed.bankName ?? senderName);
    final normAcc = normalizeAccount(parsed.accountNumber ?? accountId);

    if (parsed.messageId != null && parsed.messageId!.trim().isNotEmpty) {
      final refKey = computeReferenceKey(
        bank: normBank,
        account: normAcc,
        referenceId: parsed.messageId!,
      );
      final digest = sha256.convert(utf8.encode(refKey));
      return 'sms_${digest.toString()}';
    }

    // Conservative fallback without reference ID:
    // bank | accountSuffix | txDate (YYYY-MM-DD HH:mm:ss) | amount | type
    final dateStr = '${txDate.year.toString().padLeft(4, '0')}-${txDate.month.toString().padLeft(2, '0')}-${txDate.day.toString().padLeft(2, '0')} ${txDate.hour.toString().padLeft(2, '0')}:${txDate.minute.toString().padLeft(2, '0')}:${txDate.second.toString().padLeft(2, '0')}';
    final rawString = '$normBank|$normAcc|$dateStr|${parsed.amount.toStringAsFixed(2)}|${parsed.type.name}';
    final digest = sha256.convert(utf8.encode(rawString));
    return 'sms_${digest.toString()}';
  }

  /// Evaluates an incoming parsed expense against existing transactions to detect duplicates
  /// CONSERVATIVE RULES:
  /// 1. Both have reference IDs:
  ///    - Same normalized reference ID + same account/bank = SAME transaction.
  ///    - Different valid reference IDs = ALWAYS DIFFERENT transactions.
  /// 2. Only one has reference ID:
  ///    - Do not merge unless exact ID / SMS match.
  /// 3. Neither has reference ID:
  ///    - Exact deterministic ID match = SAME transaction.
  ///    - Different timestamps (even by seconds) without reference ID = SEPARATE transactions.
  ///    - Same amount + same day alone NEVER causes deduplication.
  static TransactionIdentityResult evaluateCandidate({
    required ParsedExpense parsed,
    required DateTime txDate,
    String? accountId,
    String? bankId,
    required String senderName,
    required String rawText,
    required Iterable<Transaction> existingTransactions,
    Set<String>? seenIds,
  }) {
    final candidateId = generateDeterministicId(
      parsed: parsed,
      txDate: txDate,
      accountId: accountId,
      bankId: bankId,
      senderName: senderName,
      rawText: rawText,
    );

    // 1. Exact ID match (In-memory seen IDs or matching transaction ID)
    if (seenIds != null && seenIds.contains(candidateId)) {
      developer.log(
        '[TransactionIdentity] Exact ID duplicate detected: $candidateId',
        name: 'TransactionIdentity',
      );
      return TransactionIdentityResult.exactDuplicate(
        matchedId: candidateId,
        canonicalId: candidateId,
      );
    }

    final incomingRef = normalizeReference(parsed.messageId);
    final incomingAccNorm = normalizeAccount(parsed.accountNumber ?? accountId);
    final incomingBankNorm = SmsAccountResolver.normalizeBankIdentifier(bankId ?? parsed.bankName ?? senderName);

    final List<Transaction> potentialMatches = [];

    for (final tx in existingTransactions) {
      if (tx.id == candidateId) {
        developer.log(
          '[TransactionIdentity] Exact transaction duplicate detected: ${tx.id}',
          name: 'TransactionIdentity',
        );
        return TransactionIdentityResult.exactDuplicate(
          matchedId: tx.id,
          canonicalId: candidateId,
        );
      }

      final existingRef = normalizeReference(tx.upiReference);

      // RULE 1: Both have reference IDs
      if (incomingRef.isNotEmpty && existingRef.isNotEmpty) {
        if (incomingRef == existingRef) {
          final txAccNorm = normalizeAccount(tx.accountNumber ?? tx.accountId);
          final txBankNorm = SmsAccountResolver.normalizeBankIdentifier(tx.subtitle ?? '');

          final accountMatches = incomingAccNorm == 'unknown' || txAccNorm == 'unknown' || incomingAccNorm == txAccNorm || (accountId != null && tx.accountId == accountId);
          final bankMatches = incomingBankNorm.isEmpty || txBankNorm.isEmpty || incomingBankNorm == txBankNorm;

          if (accountMatches || bankMatches) {
            developer.log(
              '[TransactionIdentity] Reference duplicate detected\nReference: $incomingRef\nAccount: $incomingAccNorm\nExisting transaction: ${tx.id}\nIncoming SMS ignored',
              name: 'TransactionIdentity',
            );
            return TransactionIdentityResult.referenceDuplicate(
              matchedId: tx.id,
              canonicalId: tx.id,
            );
          }
        } else {
          // STRICT RULE: Different valid reference IDs must NEVER be merged!
          continue;
        }
      }

      // RULE 2: If incoming has reference ID but existing has a different reference ID -> Skip
      if (incomingRef.isNotEmpty && existingRef.isNotEmpty && incomingRef != existingRef) {
        continue;
      }

      // RESEND GUARD: Check for carrier resend with identical normalized SMS body within 30 minutes
      // Runs regardless of whether account or reference ID resolved.
      final incomingNormalizedRaw = normalizeRawMessage(rawText);
      final existingNormalizedRaw = normalizeRawMessage(tx.rawMessage);
      if (incomingNormalizedRaw.isNotEmpty &&
          existingNormalizedRaw.isNotEmpty &&
          incomingNormalizedRaw == existingNormalizedRaw) {
        final diff = txDate.difference(tx.date).abs();
        if (diff <= const Duration(minutes: 30)) {
          developer.log(
            '[TransactionIdentity] Resend guard detected identical SMS within 30m window\nExisting transaction: ${tx.id}\nTime diff: ${diff.inSeconds}s',
            name: 'TransactionIdentity',
          );
          return TransactionIdentityResult.exactDuplicate(
            matchedId: tx.id,
            canonicalId: tx.id,
          );
        }
      }

      // RULE 3: Fallback when NEITHER has a reference ID
      if (incomingRef.isEmpty && existingRef.isEmpty) {
        final sameAmount = (tx.amount - parsed.amount).abs() < 0.001;
        final sameType = tx.type == parsed.type;

        if (sameAmount && sameType) {
          final txAccNorm = normalizeAccount(tx.accountNumber ?? tx.accountId);
          final sameAccount = (accountId != null && tx.accountId == accountId) ||
                              (incomingAccNorm != 'unknown' && txAccNorm != 'unknown' && incomingAccNorm == txAccNorm);

          if (sameAccount) {
            // Check exact timestamp match (seconds level)
            if (tx.date.year == txDate.year &&
                tx.date.month == txDate.month &&
                tx.date.day == txDate.day &&
                tx.date.hour == txDate.hour &&
                tx.date.minute == txDate.minute &&
                tx.date.second == txDate.second) {
              potentialMatches.add(tx);
            }
          }
        }
      }
    }

    if (potentialMatches.length == 1) {
      final match = potentialMatches.first;
      developer.log(
        '[TransactionIdentity] Probable duplicate detected (identical timestamp & account)\nAmount: ${parsed.amount}\nAccount: $incomingAccNorm\nExisting transaction: ${match.id}',
        name: 'TransactionIdentity',
      );
      return TransactionIdentityResult.probableDuplicate(
        matchedId: match.id,
        canonicalId: match.id,
      );
    } else if (potentialMatches.length > 1) {
      // Ambiguous match: multiple identical candidates exist. DO NOT MERGE.
      developer.log(
        '[TransactionIdentity] Ambiguous match: multiple candidates found. Treating as separate transaction.',
        name: 'TransactionIdentity',
      );
      return TransactionIdentityResult.ambiguous(candidateId);
    }

    developer.log(
      '[TransactionIdentity] New transaction identified: $candidateId',
      name: 'TransactionIdentity',
    );
    return TransactionIdentityResult.newTransaction(candidateId);
  }

  /// Plans a safe duplicate cleanup over existing transactions.
  /// Identifies canonical transactions, merges user custom titles/categories/notes,
  /// and marks redundant duplicate IDs for deletion.
  static DuplicateCleanupPlan planDuplicateCleanup(List<Transaction> allTransactions) {
    final Map<String, List<Transaction>> refGroups = {};
    final Map<String, List<Transaction>> fallbackGroups = {};

    for (final tx in allTransactions) {
      final ref = normalizeReference(tx.upiReference);
      if (ref.isNotEmpty) {
        final bank = SmsAccountResolver.normalizeBankIdentifier(tx.subtitle ?? '');
        final acc = normalizeAccount(tx.accountNumber ?? tx.accountId);
        final key = 'ref_${bank}_${acc}_$ref';
        refGroups.putIfAbsent(key, () => []).add(tx);
      } else {
        final bank = SmsAccountResolver.normalizeBankIdentifier(tx.subtitle ?? '');
        final acc = normalizeAccount(tx.accountNumber ?? tx.accountId);
        final dateStr = '${tx.date.year.toString().padLeft(4, '0')}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')} ${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}:${tx.date.second.toString().padLeft(2, '0')}';
        final key = 'fallback_${bank}_${acc}_${dateStr}_${tx.amount.toStringAsFixed(2)}_${tx.type.name}';
        fallbackGroups.putIfAbsent(key, () => []).add(tx);
      }
    }

    final List<Transaction> toUpdate = [];
    final List<String> toDelete = [];
    int duplicatesCount = 0;

    void processGroup(List<Transaction> group) {
      if (group.length <= 1) return;

      // Select canonical: oldest created transaction
      Transaction canonical = group.first;
      for (final candidate in group) {
        final candDate = candidate.createdAt ?? candidate.date;
        final canonDate = canonical.createdAt ?? canonical.date;
        if (candDate.isBefore(canonDate)) {
          canonical = candidate;
        }
      }

      // Merge user fields from duplicates into canonical if canonical lacks them
      String? mergedCustomTitle = canonical.customTitle;
      String? mergedCustomCategory = canonical.customCategory;
      String? mergedNotes = canonical.notes;

      for (final other in group) {
        if (other.id == canonical.id) continue;

        if ((mergedCustomTitle == null || mergedCustomTitle.trim().isEmpty) &&
            other.customTitle != null && other.customTitle!.trim().isNotEmpty) {
          mergedCustomTitle = other.customTitle;
        }

        if ((mergedCustomCategory == null || mergedCustomCategory.trim().isEmpty) &&
            other.customCategory != null && other.customCategory!.trim().isNotEmpty) {
          mergedCustomCategory = other.customCategory;
        }

        if ((mergedNotes == null || mergedNotes.trim().isEmpty) &&
            other.notes != null && other.notes!.trim().isNotEmpty) {
          mergedNotes = other.notes;
        }

        toDelete.add(other.id);
        duplicatesCount++;
      }

      if (mergedCustomTitle != canonical.customTitle ||
          mergedCustomCategory != canonical.customCategory ||
          mergedNotes != canonical.notes) {
        canonical = canonical.copyWith(
          customTitle: mergedCustomTitle,
          customCategory: mergedCustomCategory,
          notes: mergedNotes,
        );
        toUpdate.add(canonical);
      }
    }

    for (final group in refGroups.values) {
      processGroup(group);
    }

    for (final group in fallbackGroups.values) {
      processGroup(group);
    }

    return DuplicateCleanupPlan(
      transactionsToUpdate: toUpdate,
      duplicateIdsToDelete: toDelete,
      duplicatesFound: duplicatesCount,
    );
  }
}
