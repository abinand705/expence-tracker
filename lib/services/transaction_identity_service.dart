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
}

class TransactionIdentityService {
  static const Duration defaultTimeTolerance = Duration(seconds: 5);

  /// Normalize reference IDs for robust comparison across SMS/statement formats
  static String normalizeReference(String? ref) {
    if (ref == null) return '';
    return ref.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Normalize account representation (extract last 3-6 digits or identifier)
  static String normalizeAccount(String? rawAccount) {
    if (rawAccount == null || rawAccount.trim().isEmpty) return 'unknown';
    final digits = rawAccount.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 3) {
      return digits.substring(digits.length - (digits.length >= 4 ? 4 : 3));
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
  static String generateDeterministicId({
    required ParsedExpense parsed,
    required DateTime txDate,
    String? accountId,
    String? bankId,
    required String senderName,
    required String rawText,
  }) {
    if (parsed.messageId != null && parsed.messageId!.trim().isNotEmpty) {
      final refKey = computeReferenceKey(
        bank: bankId ?? parsed.bankName ?? senderName,
        account: parsed.accountNumber ?? accountId,
        referenceId: parsed.messageId!,
      );
      final digest = sha256.convert(utf8.encode(refKey));
      return 'sms_${digest.toString()}';
    }

    final normalizedSender = senderName.trim().toLowerCase();
    final normalizedBody = rawText.trim().replaceAll(RegExp(r'\s+'), ' ');
    final rawString = '${accountId ?? "null"}_${normalizedSender}_${parsed.type.name}_${parsed.amount.toStringAsFixed(2)}_${txDate.toUtc().toIso8601String()}_$normalizedBody';
    final digest = sha256.convert(utf8.encode(rawString));
    return 'sms_${digest.toString()}';
  }

  /// Evaluates an incoming parsed expense against existing transactions to detect duplicates
  static TransactionIdentityResult evaluateCandidate({
    required ParsedExpense parsed,
    required DateTime txDate,
    String? accountId,
    String? bankId,
    required String senderName,
    required String rawText,
    required Iterable<Transaction> existingTransactions,
    Set<String>? seenIds,
    Duration timeTolerance = defaultTimeTolerance,
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

      // 2. REFERENCE ID DEDUPLICATION (Priority 1: Strongest match)
      if (incomingRef.isNotEmpty && existingRef.isNotEmpty) {
        if (incomingRef == existingRef) {
          // Verify account / bank compatibility
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
          // SAFETY RULE: Two different valid reference IDs must NEVER be merged!
          continue;
        }
      }

      // If incoming has a reference ID but existing transaction has a DIFFERENT valid reference ID, skip
      if (incomingRef.isNotEmpty && existingRef.isNotEmpty && incomingRef != existingRef) {
        continue;
      }

      // 3. FALLBACK DEDUPLICATION: Account + Amount + Type + Time Window (Priority 3)
      // When either incoming or existing transaction lacks a reference ID
      final sameAmount = (tx.amount - parsed.amount).abs() < 0.001;
      final sameType = tx.type == parsed.type;

      if (sameAmount && sameType) {
        final txAccNorm = normalizeAccount(tx.accountNumber ?? tx.accountId);
        final sameAccount = (accountId != null && tx.accountId == accountId) ||
                            (incomingAccNorm != 'unknown' && txAccNorm != 'unknown' && incomingAccNorm == txAccNorm);

        if (sameAccount) {
          final timeDiff = tx.date.difference(txDate).abs();
          if (timeDiff <= timeTolerance) {
            // Check if one has a reference and the other doesn't, but they clearly represent the same financial event
            developer.log(
              '[TransactionIdentity] Probable duplicate detected\nAmount: ${parsed.amount}\nAccount: $incomingAccNorm\nTime difference: ${timeDiff.inSeconds} seconds\nExisting transaction: ${tx.id}',
              name: 'TransactionIdentity',
            );
            return TransactionIdentityResult.probableDuplicate(
              matchedId: tx.id,
              canonicalId: tx.id,
            );
          }
        }
      }
    }

    return TransactionIdentityResult.newTransaction(candidateId);
  }
}
