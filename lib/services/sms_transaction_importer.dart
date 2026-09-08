import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/sms_models.dart';
import '../models/transaction.dart' as model_tx;
import '../repositories/transaction_repository.dart';
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

// NOTE: SmsAccountResolver and BankDetectionService are NO LONGER used for
// account matching in SMS transaction import. All account matching goes through
// SmsAccountIndex / AccountSmsMatcher which enforces the rule:
// "No configured account match = no transaction, no account creation."

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

  SmsTransactionImporter({
    required this.transactionRepo,
    this.pendingDueRepo,
    AccountRepository? accountRepo,
    this.ruleRepo,
  }) : accountRepo = accountRepo ?? AccountRepository();

  // ---------------------------------------------------------------------------
  // Single message import (used by test-facing code)
  // ---------------------------------------------------------------------------

  /// Imports a single SMS message using the new account-rule matching pipeline.
  ///
  /// IMPORTANT: If no user-configured account matches the sender + account
  /// identifier, this returns [SmsImportResult.skipped] — no account is
  /// created, no transaction is created.
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

      // Step 1: Find configured account using new matcher
      final matchResult = index.match(senderName, msg.text);
      if (matchResult == null) {
        // No configured account matched — DO NOT create account or transaction
        debugPrint('[SmsTransactionImporter] no configured account matched sender=$senderName — skipping');
        return SmsImportResult.skipped;
      }

      final accountId = matchResult.accountId;
      final account = index.getAccount(accountId);
      final accounts = index.allAccounts;

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
            '${accountId}_${parsedDue.amount}_${parsedDue.dueDate.toUtc().toIso8601String()}_$normalizedDesc';
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

      // Step 4: Deduplication BEFORE Firestore write
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

      // Step 5: Balance update for explicit SMS balance (even if duplicate)
      if (account != null && parsed.availableBalance != null) {
        _maybeUpdateBalance(
          account: account,
          accounts: accounts,
          newBalance: parsed.availableBalance!,
          txDate: txDate,
          accountId: accountId,
        );
      }

      if (idResult.isDuplicate) {
        return SmsImportResult.duplicate;
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
          accountId: accountId,
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

    if (index.enabledAccountCount == 0) {
      debugPrint('[SmsTransactionImporter] No accounts with SMS tracking enabled. Skipping all SMS.');
      for (final conv in conversations) {
        if (conv.isBankSender) {
          summary.scanned += conv.messages.length;
          summary.skippedUnmatched += conv.messages.length;
        }
      }
      return summary;
    }

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

    // 4. In-memory account balance tracking (avoid repeated Firestore reads)
    final Map<String, Account> accountMap = {
      for (final a in index.allAccounts) a.id: a
    };
    final Map<String, bool> accountHasReliableBalance = {
      for (final a in index.allAccounts)
        a.id: a.currentBalance != 0.0 || a.balanceUpdatedAt != null
    };

    // 5. Process messages chronologically
    for (final item in allMessages) {
      summary.scanned++;
      final msg = item.msg;
      final senderName = item.senderName;

      try {
        // Step A: Find configured account — THIS IS THE GATE
        final matchResult = index.match(senderName, msg.text);
        if (matchResult == null) {
          // No configured account matched. DO NOT create account or transaction.
          summary.skippedUnmatched++;
          continue;
        }

        final accountId = matchResult.accountId;

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
              '${accountId}_${parsedDue.amount}_${parsedDue.dueDate.toUtc().toIso8601String()}_$normalizedDesc';
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
          if (rawBalance != null && accountMap.containsKey(accountId)) {
            final acc = accountMap[accountId]!;
            final balDate = ExpenseParser.extractTransactionTimestamp(msg.text) ?? msg.timestamp;
            if (_statementAllows(acc, balDate)) {
              if (acc.balanceUpdatedAt == null || !balDate.isBefore(acc.balanceUpdatedAt!)) {
                accountMap[accountId] = acc.copyWith(
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

        // Step E: Deduplication BEFORE Firestore write
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

        bool isNewlyImported = false;

        if (!idResult.isDuplicate) {
          // Step F: Create transaction with canonical accountId
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
          if (success) {
            existingTxIds.add(idResult.canonicalId);
            existingTxList.add(transaction);
            summary.imported++;
            isNewlyImported = true;
          } else {
            summary.duplicates++;
          }
        } else {
          summary.duplicates++;
          // If the existing transaction had no accountId or an empty one, link it now
          if (idResult.matchedTransactionId != null) {
            final matchIdx = existingTxList.indexWhere((t) => t.id == idResult.matchedTransactionId);
            if (matchIdx != -1) {
              final existingTx = existingTxList[matchIdx];
              if (existingTx.accountId == null || existingTx.accountId!.isEmpty) {
                final linked = existingTx.copyWith(accountId: accountId);
                existingTxList[matchIdx] = linked;
                try {
                  await transactionRepo.updateTransaction(linked);
                } catch (_) {}
              }
            }
          }
        }

        // Step G: Update balance (only after duplicate check)
        if (accountMap.containsKey(accountId)) {
          final acc = accountMap[accountId]!;
          if (_statementAllows(acc, txDate)) {
            if (parsed.availableBalance != null) {
              // Explicit balance checkpoint: only apply if this checkpoint is not older than existing balanceUpdatedAt
              if (acc.balanceUpdatedAt == null || !txDate.isBefore(acc.balanceUpdatedAt!)) {
                accountMap[accountId] = acc.copyWith(
                  currentBalance: parsed.availableBalance!,
                  balanceSource: 'sms',
                  balanceUpdatedAt: txDate,
                );
                accountHasReliableBalance[accountId] = true;
              }
            } else if (isNewlyImported) {
              // Calculated delta for newly imported transactions:
              // Only apply delta if the transaction is on or after the last known balance checkpoint
              if (acc.balanceUpdatedAt == null || !txDate.isBefore(acc.balanceUpdatedAt!)) {
                final delta = parsed.type == model_tx.TransactionType.expense
                    ? -parsed.amount
                    : parsed.amount;
                final hasExplicit = accountHasReliableBalance[accountId] ?? false;
                accountMap[accountId] = acc.copyWith(
                  currentBalance: acc.currentBalance + delta,
                  balanceSource: hasExplicit ? 'sms' : 'calculated',
                  balanceUpdatedAt: txDate,
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[SmsTransactionImporter] error processing SMS from $senderName: $e');
        summary.failed++;
      }
    }

    // 6. Commit updated balances to Firestore (batch at end)
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

    // 7. Reconcile pending dues
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
}
