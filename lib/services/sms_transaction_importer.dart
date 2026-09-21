import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/sms_models.dart';
import '../models/transaction.dart' as model_tx;
import '../models/transaction_candidate.dart';
import '../models/gemini_config.dart';
import '../models/gemini_decision.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/transaction_group_repository.dart';
import '../utils/expense_parser.dart';
import 'transaction_identity_service.dart';
import '../repositories/pending_due_repository.dart';
import '../models/pending_due.dart';
import '../models/account.dart';
import '../models/sms_recognition_rule.dart';
import '../repositories/account_repository.dart';
import '../repositories/sms_rule_repository.dart';
import 'bank_detection_service.dart';
import 'sms_account_index.dart';
import 'transaction_matcher.dart';
import 'gemini_transaction_service.dart';
import 'transaction_decision_validator.dart';
import 'transaction_group_resolver.dart';

enum SmsImportResult { imported, duplicate, skipped, failed }

class SmsImportSummary {
  int scanned = 0;
  int imported = 0;
  int duplicates = 0;
  int skipped = 0;
  int skippedUnmatched = 0; // SMS that had no configured account match
  int failed = 0;

  @override
  String toString() {
    return '$scanned scanned • $imported imported • $duplicates duplicates • '
        '$skipped skipped • $skippedUnmatched unmatched';
  }
}

class SmsTransactionImporter {
  final TransactionRepository transactionRepo;
  final PendingDueRepository? pendingDueRepo;
  final AccountRepository accountRepo;
  final SmsRuleRepository? ruleRepo;
  final TransactionGroupRepository groupRepo;
  final GeminiTransactionService geminiService;
  final TransactionMatcher matcher;
  final TransactionDecisionValidator validator;
  final TransactionGroupResolver resolver;

  SmsTransactionImporter({
    required this.transactionRepo,
    this.pendingDueRepo,
    AccountRepository? accountRepo,
    this.ruleRepo,
    TransactionGroupRepository? groupRepo,
    GeminiTransactionService? geminiService,
    TransactionMatcher? matcher,
    TransactionDecisionValidator? validator,
    TransactionGroupResolver? resolver,
  })  : accountRepo = accountRepo ?? AccountRepository(),
        groupRepo = groupRepo ?? TransactionGroupRepository(),
        geminiService = geminiService ?? GeminiTransactionService(),
        matcher = matcher ?? const TransactionMatcher(),
        validator = validator ?? const TransactionDecisionValidator(),
        resolver = resolver ?? const TransactionGroupResolver();

  // ---------------------------------------------------------------------------
  // Single message import (used by test-facing code and realtime SMS arrival)
  // ---------------------------------------------------------------------------

  /// Imports a single SMS message using the account-rule matching pipeline and
  /// transaction intelligence deduplication.
  Future<SmsImportResult> importMessage(
    Message msg,
    String senderName, [
    dynamic indexOrResolver,
    PendingDueRepository? customDueRepo,
    List<Account>? providedAccounts,
  ]) async {
    try {
      final activeDueRepo = customDueRepo ?? (pendingDueRepo ?? PendingDueRepository());

      // Build or use provided index
      final SmsAccountIndex index;
      if (indexOrResolver is SmsAccountIndex) {
        index = indexOrResolver;
      } else if (providedAccounts != null) {
        final Map<String, List<SmsRecognitionRule>> rulesByAccount = {};
        final List<Account> accountsWithTracking = [];

        for (final acc in providedAccounts) {
          final enabledAcc = acc.copyWith(smsTrackingEnabled: true);
          accountsWithTracking.add(enabledAcc);

          final suffix = enabledAcc.last3Digits ??
              (enabledAcc.accountNumber.isNotEmpty ? enabledAcc.accountNumber : '');
          final patterns = <String>{
            enabledAcc.bankName,
            if (enabledAcc.name.isNotEmpty) enabledAcc.name,
          };
          final bankDef = BankDetectionService().identifyBank(enabledAcc.bankName, '') ??
              BankDetectionService().identifyBank(enabledAcc.name, '');
          if (bankDef != null) {
            patterns.addAll(bankDef.senderPatterns);
            patterns.add(bankDef.displayName);
          }

          final rule = SmsRecognitionRule(
            id: 'test_rule_${enabledAcc.id}',
            accountId: enabledAcc.id,
            ruleLabel: '${enabledAcc.bankName} Rule',
            accountIdentifier: suffix,
            senderPatterns: patterns.toList(),
            debitKeywords: const ['debited', 'spent', 'paid', 'withdrawn'],
            creditKeywords: const ['credited', 'received', 'deposited'],
            coversDebit: true,
            coversCredit: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          );
          rulesByAccount[enabledAcc.id] = [rule];
        }

        index = SmsAccountIndex.fromData(
          accounts: accountsWithTracking,
          rulesByAccount: rulesByAccount,
        );
      } else {
        index = await SmsAccountIndex.build(
          accountRepo: accountRepo,
          ruleRepo: ruleRepo,
        );
      }

      // Step 1: Find configured account using matcher (if any)
      final matchResult = index.match(senderName, msg.text);
      final accountId = matchResult?.accountId;
      final account = accountId != null ? index.getAccount(accountId) : null;
      final accounts = index.allAccounts;
      if (matchResult == null) {
        debugPrint('[SmsTransactionImporter] no configured account matched sender=$senderName (unresolved account - continuing transaction import)');
      }

      // Step 2: Parse transaction from SMS
      final parsedDue = ExpenseParser.parsePendingDue(msg.text, msg.timestamp);
      final parsed = ExpenseParser.parse(msg.text);

      // Step 3: Handle Pending Due
      if (parsedDue != null) {
        final normalizedDesc = (parsedDue.description ?? senderName)
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        final rawDueString =
            '${accountId ?? "unresolved"}_${parsedDue.amount}_${parsedDue.dueDate.toUtc().toIso8601String()}_$normalizedDesc';
        final dueBytes = utf8.encode(rawDueString);
        final dueDigest = sha256.convert(dueBytes);
        final dueDeterministicId = 'due_${dueDigest.toString()}';

        final pendingDue = PendingDue(
          id: dueDeterministicId,
          amount: parsedDue.amount,
          dueDate: parsedDue.dueDate,
          accountId: accountId,
          bankId: null,
          description: parsedDue.description ?? senderName,
          detectedAt: msg.timestamp,
          source: parsedDue.source,
        );

        await activeDueRepo.addPendingDueIfAbsent(pendingDue);
        return SmsImportResult.imported;
      }

      if (parsed == null) {
        return SmsImportResult.skipped;
      }

      final txDate = parsed.transactionTimestamp ?? msg.timestamp;

      // Step 4: SMS-level and Reference-level Deduplication BEFORE Firestore write
      List<model_tx.Transaction> existingTransactions = [];
      try {
        existingTransactions = await transactionRepo.getTransactions();
      } catch (_) {}

      final idResult = TransactionIdentityService.evaluateCandidate(
        parsed: parsed,
        txDate: txDate,
        accountId: accountId,
        bankId: null,
        senderName: senderName,
        rawText: msg.text,
        existingTransactions: existingTransactions,
      );

      // Balance update for explicit SMS balance (even if duplicate)
      if (account != null && parsed.availableBalance != null) {
        _maybeUpdateBalance(
          account: account,
          accounts: accounts,
          newBalance: parsed.availableBalance!,
          txDate: txDate,
          accountId: account.id,
        );
      }

      if (idResult.isDuplicate) {
        return SmsImportResult.duplicate;
      }

      // Step 5: Check against existing transactions using TransactionMatcher & Gemini
      final incomingCandidate = TransactionCandidate.fromParsed(
        text: msg.text,
        senderName: senderName,
        receivedAt: msg.timestamp,
        amount: parsed.amount,
        type: parsed.type,
        sourceSmsId: msg.id,
        merchant: parsed.merchant,
        accountId: accountId,
        accountLast4: parsed.accountNumber ?? account?.last3Digits,
        bankName: parsed.bankName ?? account?.bankName,
        referenceNumber: parsed.messageId,
        upiReference: parsed.messageId,
        balance: parsed.availableBalance,
        txDate: txDate,
      );

      for (final tx in existingTransactions) {
        // Construct existing candidate proxy
        final existingCand = TransactionCandidate(
          candidateId: tx.id,
          sender: tx.subtitle ?? '',
          receivedAt: tx.date,
          transactionDate: tx.date,
          amount: tx.amount,
          transactionType: tx.type,
          merchant: tx.merchant,
          accountId: tx.accountId,
          accountLast4: tx.accountNumber,
          referenceNumber: tx.upiReference,
          upiReference: tx.upiReference,
          rawMessageHash: '',
          normalizedMerchant: _normalizeMerchant(tx.merchant),
          normalizedDescription: '',
          lifecycleState: 'successful',
        );

        final relation = matcher.evaluateRelationship(incomingCandidate, existingCand);
        if (relation == CandidateRelation.exactReference ||
            relation == CandidateRelation.strongDeterministic ||
            relation == CandidateRelation.fuzzyLifecycle) {
          debugPrint('[MATCHER] Duplicate relationship found with existing transaction: ${tx.id}');
          return SmsImportResult.duplicate;
        } else if (relation == CandidateRelation.ambiguous && geminiService.configService.isEnabled) {
          debugPrint('[AI] Evaluating ambiguous candidate against existing transaction ${tx.id}');
          final decision = await geminiService.classifyCandidates([incomingCandidate, existingCand]);
          final validated = validator.validate(
            decision: decision,
            candidates: [incomingCandidate, existingCand],
            config: geminiService.configService.config,
          );
          if (validated.status == ValidationStatus.approvedAutoApply &&
              (decision.classification == GeminiClassification.sameTransaction ||
                  decision.classification == GeminiClassification.transactionUpdate)) {
            debugPrint('[AI] Gemini confirmed SAME_TRANSACTION with existing transaction ${tx.id}');
            return SmsImportResult.duplicate;
          }
        }
      }

      // Step 6: Create transaction with canonical accountId
      final transaction = model_tx.Transaction(
        id: idResult.canonicalId,
        amount: parsed.amount,
        type: parsed.type,
        merchant: parsed.merchant ?? 'Unknown Merchant',
        category: ExpenseParser.guessCategory(parsed.merchant),
        date: txDate,
        subtitle: parsed.bankName ?? senderName,
        rawMessage: msg.text,
        source: 'sms',
        transactionSource: 'sms',
        isManual: false,
        accountId: accountId, // Always the canonical user-created account ID
        accountNumber: parsed.accountNumber,
        upiReference: parsed.messageId,
      );

      final success = await transactionRepo.addTransactionIfAbsent(transaction);
      if (!success) {
        return SmsImportResult.duplicate;
      }

      // Step 7: Calculated balance update (only for NEW transactions)
      if (account != null && parsed.availableBalance == null) {
        _maybeUpdateBalanceDelta(
          account: account,
          accounts: accounts,
          parsed: parsed,
          txDate: txDate,
          accountId: account.id,
        );
      }

      return SmsImportResult.imported;
    } catch (e) {
      debugPrint('[SmsTransactionImporter] importMessage error: $e');
      return SmsImportResult.failed;
    }
  }

  // ---------------------------------------------------------------------------
  // Bulk import (called from SmsService on device SMS load)
  // ---------------------------------------------------------------------------

  Future<SmsImportSummary> importAllBankMessages(
      List<Conversation> conversations) async {
    final summary = SmsImportSummary();
    final dueRepo = pendingDueRepo ?? PendingDueRepository();

    // 1. Build account+rule index ONCE for the entire scan
    final index = await SmsAccountIndex.build(
      accountRepo: accountRepo,
      ruleRepo: ruleRepo,
    );

    debugPrint('[IMPORTER] Accounts with SMS tracking enabled: ${index.enabledAccountCount}');

    // 2. Load existing transactions ONCE for fast deduplication
    final List<model_tx.Transaction> existingTxList = [];
    final Set<String> existingTxIds = {};
    try {
      final list = await transactionRepo.getTransactions();
      existingTxList.addAll(list);
      for (final tx in list) {
        existingTxIds.add(tx.id);
      }
    } catch (e) {
      debugPrint('[SmsTransactionImporter] failed to load existing transactions: $e');
    }

    // 3. Gather and sort all bank-sender messages chronologically
    final List<({Message msg, String senderName})> allMessages = [];
    for (final conv in conversations) {
      final matchesRuleSender = index.rulesByAccount.values.any(
        (rules) => rules.any((r) => r.matchesSender(conv.senderName)),
      );
      if (conv.isBankSender || matchesRuleSender) {
        for (final msg in conv.messages) {
          allMessages.add((msg: msg, senderName: conv.senderName));
        }
      }
    }
    DateTime effectiveMsgTime(Message m) {
      return ExpenseParser.extractTransactionTimestamp(m.text) ?? m.timestamp;
    }
    allMessages.sort((a, b) => effectiveMsgTime(a.msg).compareTo(effectiveMsgTime(b.msg)));

    // 4. In-memory account balance tracking
    final Map<String, Account> accountMap = {
      for (final a in index.allAccounts) a.id: a
    };
    final Map<String, bool> accountHasReliableBalance = {
      for (final a in index.allAccounts)
        a.id: a.currentBalance != 0.0 || a.balanceUpdatedAt != null
    };

    final List<TransactionCandidate> newCandidates = [];

    // 5. Phase 1: Parse, filter exact duplicates, handle dues and balance-only SMS
    for (final item in allMessages) {
      summary.scanned++;
      final msg = item.msg;
      final senderName = item.senderName;

      try {
        // Step A: Match configured account if available
        final matchResult = index.match(senderName, msg.text);
        final accountId = matchResult?.accountId;
        final account = accountId != null ? accountMap[accountId] : null;
        if (matchResult == null) {
          summary.skippedUnmatched++;
        }

        // Step B: Parse SMS
        final parsedDue = ExpenseParser.parsePendingDue(msg.text, msg.timestamp);
        final parsed = ExpenseParser.parse(msg.text);

        // Step C: Handle Pending Due
        if (parsedDue != null) {
          final normalizedDesc = (parsedDue.description ?? senderName)
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ');
          final rawDueString =
              '${accountId ?? "unresolved"}_${parsedDue.amount}_${parsedDue.dueDate.toUtc().toIso8601String()}_$normalizedDesc';
          final dueBytes = utf8.encode(rawDueString);
          final dueDigest = sha256.convert(dueBytes);
          final dueDeterministicId = 'due_${dueDigest.toString()}';

          final pendingDue = PendingDue(
            id: dueDeterministicId,
            amount: parsedDue.amount,
            dueDate: parsedDue.dueDate,
            accountId: accountId,
            bankId: null,
            description: parsedDue.description ?? senderName,
            detectedAt: msg.timestamp,
            source: parsedDue.source,
          );

          await dueRepo.addPendingDueIfAbsent(pendingDue);
          summary.imported++;
          continue;
        }

        // Step D: Balance-only SMS (no transaction)
        if (parsed == null) {
          final rawBalance = ExpenseParser.parseAvailableBalanceOnly(msg.text);
          if (rawBalance != null && account != null && accountId != null) {
            final balDate = ExpenseParser.extractTransactionTimestamp(msg.text) ?? msg.timestamp;
            if (_statementAllows(account, balDate)) {
              if (account.balanceUpdatedAt == null || !balDate.isBefore(account.balanceUpdatedAt!)) {
                accountMap[accountId] = account.copyWith(
                  currentBalance: rawBalance,
                  balanceSource: 'sms',
                  balanceUpdatedAt: balDate,
                );
                accountHasReliableBalance[accountId] = true;
              }
            }
          }
          summary.skipped++;
          continue;
        }

        final txDate = parsed.transactionTimestamp ?? msg.timestamp;

        // Step E: SMS-level deduplication against existing transactions
        final idResult = TransactionIdentityService.evaluateCandidate(
          parsed: parsed,
          txDate: txDate,
          accountId: accountId,
          bankId: null,
          senderName: senderName,
          rawText: msg.text,
          existingTransactions: existingTxList,
          seenIds: existingTxIds,
        );

        if (idResult.isDuplicate) {
          summary.duplicates++;
          continue;
        }

        // Check explicit balance in SMS
        if (account != null && parsed.availableBalance != null) {
          if (_statementAllows(account, txDate)) {
            if (account.balanceUpdatedAt == null || !txDate.isBefore(account.balanceUpdatedAt!)) {
              accountMap[account.id] = account.copyWith(
                currentBalance: parsed.availableBalance!,
                balanceSource: 'sms',
                balanceUpdatedAt: txDate,
              );
              accountHasReliableBalance[account.id] = true;
            }
          }
        }

        // Build candidate for batch intelligence
        final candidate = TransactionCandidate.fromParsed(
          text: msg.text,
          senderName: senderName,
          receivedAt: msg.timestamp,
          amount: parsed.amount,
          type: parsed.type,
          sourceSmsId: msg.id,
          merchant: parsed.merchant,
          accountId: accountId,
          accountLast4: parsed.accountNumber ?? account?.last3Digits,
          bankName: parsed.bankName ?? account?.bankName,
          referenceNumber: parsed.messageId,
          upiReference: parsed.messageId,
          balance: parsed.availableBalance,
          txDate: txDate,
        );

        newCandidates.add(candidate);
      } catch (e) {
        debugPrint('[SmsTransactionImporter] error processing SMS from $senderName: $e');
        summary.failed++;
      }
    }

    // 6. Phase 2: Run Transaction Intelligence (Matcher + Gemini AI)
    debugPrint('[IMPORTER] Candidates received: ${newCandidates.length}');
    final matchResult = matcher.matchCandidates(newCandidates);
    debugPrint('[MATCHER] Deterministic groups: ${matchResult.deterministicGroups.length}, '
        'Ambiguous groups: ${matchResult.ambiguousGroups.length}, '
        'Unmerged candidates: ${matchResult.unmergedCandidates.length}');

    final List<({ValidatedDecision validated, List<TransactionCandidate> candidates})> aiDecisions = [];

    for (final ambiguousGroup in matchResult.ambiguousGroups) {
      if (geminiService.configService.isEnabled) {
        debugPrint('[AI] Gemini required: true for group of ${ambiguousGroup.length} candidates');
        final decision = await geminiService.classifyCandidates(ambiguousGroup);
        final validated = validator.validate(
          decision: decision,
          candidates: ambiguousGroup,
          config: geminiService.configService.config,
        );
        aiDecisions.add((validated: validated, candidates: ambiguousGroup));
      } else {
        debugPrint('[AI] Gemini required: false (disabled or unavailable)');
        final fallbackDecision = GeminiDecision.uncertain(
          candidateIds: ambiguousGroup.map((c) => c.candidateId).toList(),
          reason: 'Gemini AI disabled or offline',
        );
        final validated = validator.validate(
          decision: fallbackDecision,
          candidates: ambiguousGroup,
          config: const GeminiConfig(),
        );
        aiDecisions.add((validated: validated, candidates: ambiguousGroup));
      }
    }

    // 7. Phase 3: Resolve groups into canonical transactions
    final resolved = resolver.resolveBatch(
      deterministicGroups: matchResult.deterministicGroups,
      aiDecisions: aiDecisions,
      unmergedCandidates: matchResult.unmergedCandidates,
    );

    // Count merged candidates as duplicates
    for (final group in resolved.groupsToSave) {
      if (group.candidateIds.length > 1) {
        summary.duplicates += (group.candidateIds.length - 1);
      }
    }

    debugPrint('[TRANSACTION_GROUP] Final transactions: ${resolved.transactionsToSave.length}, '
        'groups: ${resolved.groupsToSave.length}, '
        'pending review: ${resolved.pendingReviewGroups.length}');

    final candidateMap = {for (final c in newCandidates) c.candidateId: c};

    // 8. Phase 4: Write transactions to Firestore
    for (final tx in resolved.transactionsToSave) {
      if (existingTxIds.contains(tx.id)) {
        summary.duplicates++;
        continue;
      }

      final success = await transactionRepo.addTransactionIfAbsent(tx);
      if (success) {
        existingTxIds.add(tx.id);
        existingTxList.add(tx);
        summary.imported++;

        // Calculated balance delta for new transaction ONLY IF no explicit balance was provided
        final cand = candidateMap[tx.id];
        final accId = tx.accountId;
        if (accId != null && accountMap.containsKey(accId)) {
          final acc = accountMap[accId]!;
          if (_statementAllows(acc, tx.date)) {
            if (cand == null || cand.balance == null) {
              if (acc.balanceUpdatedAt == null || !tx.date.isBefore(acc.balanceUpdatedAt!)) {
                final delta = tx.type == model_tx.TransactionType.expense
                    ? -tx.amount
                    : tx.amount;
                final hasExplicit = accountHasReliableBalance[accId] ?? false;
                accountMap[accId] = acc.copyWith(
                  currentBalance: acc.currentBalance + delta,
                  balanceSource: hasExplicit ? 'sms' : 'calculated',
                  balanceUpdatedAt: tx.date,
                );
              }
            }
          }
        }
      } else {
        summary.duplicates++;
      }
    }

    // Save transaction groups
    try {
      await groupRepo.batchSaveGroups(resolved.groupsToSave);
    } catch (e) {
      debugPrint('[SmsTransactionImporter] failed to save groups: $e');
    }

    if (resolved.pendingReviewGroups.isNotEmpty) {
      geminiService.configService.setPendingReviewCount(resolved.pendingReviewGroups.length);
    }

    // 9. Commit updated balances to Firestore (batch at end)
    for (final originalAcc in index.allAccounts) {
      final updated = accountMap[originalAcc.id];
      if (updated != null) {
        if (updated.currentBalance != originalAcc.currentBalance ||
            updated.balanceUpdatedAt != originalAcc.balanceUpdatedAt ||
            updated.balanceSource != originalAcc.balanceSource) {
          try {
            await accountRepo.updateAccount(updated);
          } catch (e) {
            debugPrint('[SmsTransactionImporter] failed to update balance for ${originalAcc.id}: $e');
          }
        }
      }
    }

    // 10. Reconcile pending dues
    try {
      final pendingDues = await dueRepo.getPendingDues();
      if (pendingDues.isNotEmpty) {
        final recentTx = await transactionRepo.getTransactions();
        for (final due in pendingDues) {
          final hasMatchingDebit = recentTx.any((tx) {
            if (tx.type != model_tx.TransactionType.expense) return false;
            if (due.accountId != null && tx.accountId != null && due.accountId != tx.accountId) return false;
            if ((tx.amount - due.amount).abs() > 0.01) return false;
            if (tx.date.isBefore(due.detectedAt)) return false;
            return true;
          });
          if (hasMatchingDebit) {
            await dueRepo.deletePendingDue(due.id);
          }
        }
      }
    } catch (_) {}

    debugPrint('[IMPORTER] Transactions accepted: ${summary.imported}');
    debugPrint('[IMPORTER] Transactions skipped: ${summary.skipped + summary.duplicates}');
    debugPrint('[SmsTransactionImporter] scan complete: $summary');
    return summary;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _statementAllows(Account acc, DateTime txDate) {
    if (acc.balanceSource == 'statement') {
      final statementDate = acc.lastStatementImportAt ?? acc.balanceUpdatedAt;
      if (statementDate != null && !txDate.isAfter(statementDate)) return false;
    }
    return true;
  }

  void _maybeUpdateBalance({
    required Account account,
    required List<Account> accounts,
    required double newBalance,
    required DateTime txDate,
    required String accountId,
  }) {
    if (!_statementAllows(account, txDate)) return;
    if (account.balanceUpdatedAt != null && txDate.isBefore(account.balanceUpdatedAt!)) {
      return;
    }
    final updated = account.copyWith(
      currentBalance: newBalance,
      balanceSource: 'sms',
      balanceUpdatedAt: txDate,
    );
    accountRepo.updateAccount(updated).catchError((_) {});
  }

  void _maybeUpdateBalanceDelta({
    required Account account,
    required List<Account> accounts,
    required ParsedExpense parsed,
    required DateTime txDate,
    required String accountId,
  }) {
    if (!_statementAllows(account, txDate)) return;
    if (account.balanceUpdatedAt != null && txDate.isBefore(account.balanceUpdatedAt!)) {
      return;
    }
    final delta = parsed.type == model_tx.TransactionType.expense
        ? -parsed.amount
        : parsed.amount;
    final updated = account.copyWith(
      currentBalance: account.currentBalance + delta,
      balanceSource: 'sms',
      balanceUpdatedAt: txDate,
    );
    accountRepo.updateAccount(updated).catchError((_) {});
  }

  static String _normalizeMerchant(String? merchant) {
    if (merchant == null) return '';
    var m = merchant.trim().toLowerCase();
    if (m.contains('amazon') || m.contains('amzn')) return 'amazon';
    if (m.contains('flipkart') || m.contains('fkrt')) return 'flipkart';
    if (m.contains('swiggy')) return 'swiggy';
    if (m.contains('zomato')) return 'zomato';
    return m;
  }
}
