import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/sms_models.dart';
import '../models/transaction.dart' as model_tx;
import '../repositories/transaction_repository.dart';
import '../services/bank_detection_service.dart';
import '../utils/expense_parser.dart';
import 'sms_account_resolver.dart';
import 'transaction_identity_service.dart';
import '../repositories/pending_due_repository.dart';
import '../models/pending_due.dart';
import '../models/account.dart';
import '../repositories/account_repository.dart';

enum SmsImportResult { imported, duplicate, skipped, failed }

class SmsImportSummary {
  int scanned = 0;
  int imported = 0;
  int duplicates = 0;
  int skipped = 0;
  int failed = 0;

  @override
  String toString() {
    return '$scanned scanned • $imported imported • $duplicates duplicates • $skipped skipped';
  }
}

class SmsTransactionImporter {
  final TransactionRepository transactionRepo;
  final PendingDueRepository? pendingDueRepo;
  final AccountRepository accountRepo;

  SmsTransactionImporter({
    required this.transactionRepo, 
    this.pendingDueRepo,
    AccountRepository? accountRepo,
  }) : accountRepo = accountRepo ?? AccountRepository();

  String? resolveTrueAccountId(String? preliminaryAccountId, String? last4, String bankId, List<Account>? existingAccounts) {
    if (existingAccounts == null || existingAccounts.isEmpty) return null;
    
    String? searchSuffix = last4;
    if (searchSuffix == null && preliminaryAccountId != null && preliminaryAccountId.contains('_')) {
      final parts = preliminaryAccountId.split('_');
      if (parts.length > 1) {
        searchSuffix = parts[1];
      }
    }
    
    return SmsAccountResolver().resolveAccount(
      bankIdOrName: bankId,
      rawAccountOrSuffix: searchSuffix,
      accounts: existingAccounts,
    );
  }

  Future<SmsImportResult> importMessage(
    Message msg, 
    String senderName, [
    SmsAccountResolver? resolver,
    PendingDueRepository? customDueRepo,
    List<Account>? providedAccounts,
  ]) async {
    try {
      final activeResolver = resolver ?? SmsAccountResolver();
      final activeDueRepo = customDueRepo ?? (pendingDueRepo ?? PendingDueRepository());
      
      // Load accounts to accurately resolve accountId
      List<Account> accounts = providedAccounts ?? [];
      if (providedAccounts == null) {
        try {
          accounts = await accountRepo.getAccounts();
        } catch (_) {}
      }

      // Identify Bank
      var bank = BankDetectionService().identifyBank(senderName, msg.text);

      // Check Pending Due first
      final parsedDue = ExpenseParser.parsePendingDue(msg.text, msg.timestamp);
      if (parsedDue?.bankName != null) {
        final explicitBank = BankDetectionService().identifyBank('', parsedDue!.bankName!);
        if (explicitBank != null) bank = explicitBank;
      }

      // Check Standard Expense
      final parsed = ExpenseParser.parse(msg.text);
      if (bank == null && parsed?.bankName != null) {
        final explicitBank = BankDetectionService().identifyBank('', parsed!.bankName!);
        if (explicitBank != null) bank = explicitBank;
      }

      // Account matching
      String? accountId;
      if (accounts.isNotEmpty) {
        final rawAccount = parsedDue?.accountSuffix ?? parsed?.accountNumber;
        if (rawAccount != null) {
          accountId = activeResolver.resolveAccount(
            bankIdOrName: bank?.id,
            rawAccountOrSuffix: rawAccount,
            accounts: accounts,
          );
        } else if (bank != null) {
          accountId = activeResolver.resolveAccountId(
            sender: senderName,
            messageText: msg.text,
            bank: bank,
            existingAccounts: accounts,
          );
        }
      }

      // Handle Pending Due
      if (parsedDue != null) {
        final normalizedDesc = (parsedDue.description ?? senderName).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        final rawDueString = '${accountId ?? "unknown"}_${bank?.id ?? "unknown"}_${parsedDue.amount}_${parsedDue.dueDate.toUtc().toIso8601String()}_$normalizedDesc';
        final dueBytes = utf8.encode(rawDueString);
        final dueDigest = sha256.convert(dueBytes);
        final dueDeterministicId = 'due_${dueDigest.toString()}';

        final pendingDue = PendingDue(
          id: dueDeterministicId,
          amount: parsedDue.amount,
          dueDate: parsedDue.dueDate,
          accountId: accountId,
          bankId: bank?.id,
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

      // Load existing transactions to evaluate deduplication
      List<model_tx.Transaction> existingTransactions = [];
      try {
        if (accountId != null) {
          existingTransactions = await transactionRepo.getTransactionsForAccount(accountId);
        } else {
          existingTransactions = await transactionRepo.getTransactions();
        }
      } catch (_) {}

      // Multi-level Transaction Identity Evaluation
      final idResult = TransactionIdentityService.evaluateCandidate(
        parsed: parsed,
        txDate: txDate,
        accountId: accountId,
        bankId: bank?.id,
        senderName: senderName,
        rawText: msg.text,
        existingTransactions: existingTransactions,
      );

      // Handle balance checkpoint even if transaction is duplicate, as long as explicit availableBalance exists
      if (accountId != null && accounts.isNotEmpty && parsed.availableBalance != null) {
        final accIdx = accounts.indexWhere((a) => a.id == accountId);
        if (accIdx != -1) {
          final acc = accounts[accIdx];
          bool statementAllows = true;
          if (acc.balanceSource == 'statement') {
            final statementDate = acc.lastStatementImportAt ?? acc.balanceUpdatedAt;
            if (statementDate != null && !txDate.isAfter(statementDate)) {
              statementAllows = false;
            }
          }

          if (statementAllows) {
            final updatedAcc = Account(
              id: acc.id,
              name: acc.name,
              bankName: acc.bankName,
              accountNumber: acc.accountNumber,
              accountType: acc.accountType,
              balance: acc.balance,
              currentBalance: parsed.availableBalance!,
              balanceSource: 'sms',
              balanceUpdatedAt: txDate,
              lastStatementImportAt: acc.lastStatementImportAt,
              currency: acc.currency,
              accentColor: acc.accentColor,
              isAutoDiscovered: acc.isAutoDiscovered,
              createdAt: acc.createdAt,
            );
            try {
              await accountRepo.updateAccount(updatedAcc);
              accounts[accIdx] = updatedAcc;
            } catch (_) {}
          }
        }
      }

      if (idResult.isDuplicate) {
        return SmsImportResult.duplicate;
      }

      // Convert to Transaction with canonical deterministic ID
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
        accountId: accountId,
        accountNumber: parsed.accountNumber,
        upiReference: parsed.messageId,
      );

      // Duplicate prevention: Atomic write
      final success = await transactionRepo.addTransactionIfAbsent(transaction);
      final isNewTransaction = success;

      if (!isNewTransaction) {
        return SmsImportResult.duplicate;
      }

      // Update calculated balance ONLY for newly imported transactions without explicit balance
      if (accountId != null && accounts.isNotEmpty && parsed.availableBalance == null) {
        final accIdx = accounts.indexWhere((a) => a.id == accountId);
        if (accIdx != -1) {
          final acc = accounts[accIdx];
          bool statementAllows = true;
          if (acc.balanceSource == 'statement') {
            final statementDate = acc.lastStatementImportAt ?? acc.balanceUpdatedAt;
            if (statementDate != null && !txDate.isAfter(statementDate)) {
              statementAllows = false;
            }
          }

          if (statementAllows) {
            final delta = parsed.type == model_tx.TransactionType.expense ? -parsed.amount : parsed.amount;
            final newBal = acc.currentBalance + delta;
            final updatedAcc = Account(
              id: acc.id,
              name: acc.name,
              bankName: acc.bankName,
              accountNumber: acc.accountNumber,
              accountType: acc.accountType,
              balance: acc.balance,
              currentBalance: newBal,
              balanceSource: 'sms',
              balanceUpdatedAt: txDate,
              lastStatementImportAt: acc.lastStatementImportAt,
              currency: acc.currency,
              accentColor: acc.accentColor,
              isAutoDiscovered: acc.isAutoDiscovered,
              createdAt: acc.createdAt,
            );
            try {
              await accountRepo.updateAccount(updatedAcc);
              accounts[accIdx] = updatedAcc;
            } catch (_) {}
          }
        }
      }

      return SmsImportResult.imported;
    } catch (e) {
      return SmsImportResult.failed;
    }
  }

  Future<SmsImportSummary> importAllBankMessages(List<Conversation> conversations) async {
    final summary = SmsImportSummary();
    final resolver = SmsAccountResolver();
    final dueRepo = pendingDueRepo ?? PendingDueRepository();
    
    // 1. Load accounts once
    List<Account> existingAccounts = [];
    try {
      existingAccounts = await accountRepo.getAccounts();
    } catch (e) {
      debugPrint('[SmsTransactionImporter] failed to load accounts: $e');
    }

    final Map<String, Account> accountMap = {
      for (var a in existingAccounts) a.id: a
    };

    // 2. Load existing transactions once for fast deduplication check
    final List<model_tx.Transaction> existingTxList = [];
    final Set<String> existingTxIds = {};
    try {
      final list = await transactionRepo.getTransactions();
      existingTxList.addAll(list);
      for (var tx in list) {
        existingTxIds.add(tx.id);
      }
    } catch (e) {
      debugPrint('[SmsTransactionImporter] failed to load existing transactions: $e');
    }

    // 3. Gather all bank messages and sort chronologically (oldest to newest)
    final List<({Message msg, String senderName})> allMessages = [];
    for (var conv in conversations) {
      if (conv.isBankSender) {
        for (var msg in conv.messages) {
          allMessages.add((msg: msg, senderName: conv.senderName));
        }
      }
    }
    allMessages.sort((a, b) => a.msg.timestamp.compareTo(b.msg.timestamp));

    // 4. Process all messages chronologically
    final Map<String, bool> accountHasReliableBalance = {};
    for (var acc in existingAccounts) {
      accountHasReliableBalance[acc.id] = acc.currentBalance != 0.0 || acc.balanceUpdatedAt != null;
    }

    for (var item in allMessages) {
      summary.scanned++;
      final msg = item.msg;
      final senderName = item.senderName;

      try {
        final parsedDue = ExpenseParser.parsePendingDue(msg.text, msg.timestamp);
        
        var bank = BankDetectionService().identifyBank(senderName, msg.text);
        if (parsedDue?.bankName != null) {
          final explicitBank = BankDetectionService().identifyBank('', parsedDue!.bankName!);
          if (explicitBank != null) bank = explicitBank;
        }

        final parsed = ExpenseParser.parse(msg.text);
        if (bank == null && parsed?.bankName != null) {
          final explicitBank = BankDetectionService().identifyBank('', parsed!.bankName!);
          if (explicitBank != null) bank = explicitBank;
        }

        String? accountId;
        if (existingAccounts.isNotEmpty) {
          final rawAccount = parsedDue?.accountSuffix ?? parsed?.accountNumber;
          if (rawAccount != null) {
            accountId = resolver.resolveAccount(
              bankIdOrName: bank?.id,
              rawAccountOrSuffix: rawAccount,
              accounts: existingAccounts,
            );
          } else if (bank != null) {
            accountId = resolver.resolveAccountId(
              sender: senderName,
              messageText: msg.text,
              bank: bank,
              existingAccounts: existingAccounts,
            );
          }
        }

        // Handle Pending Due
        if (parsedDue != null) {
          final normalizedDesc = (parsedDue.description ?? senderName).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
          final rawDueString = '${accountId ?? "unknown"}_${bank?.id ?? "unknown"}_${parsedDue.amount}_${parsedDue.dueDate.toUtc().toIso8601String()}_$normalizedDesc';
          final dueBytes = utf8.encode(rawDueString);
          final dueDigest = sha256.convert(dueBytes);
          final dueDeterministicId = 'due_${dueDigest.toString()}';

          final pendingDue = PendingDue(
            id: dueDeterministicId,
            amount: parsedDue.amount,
            dueDate: parsedDue.dueDate,
            accountId: accountId,
            bankId: bank?.id,
            description: parsedDue.description ?? senderName,
            detectedAt: msg.timestamp,
            source: parsedDue.source,
          );
          
          await dueRepo.addPendingDueIfAbsent(pendingDue);
          summary.imported++;
          continue;
        }

        if (parsed == null) {
          // If message is a pure balance inquiry
          final rawBalance = ExpenseParser.parseAvailableBalanceOnly(msg.text);
          if (rawBalance != null && accountId != null && accountMap.containsKey(accountId)) {
            final acc = accountMap[accountId]!;
            bool statementAllows = true;
            if (acc.balanceSource == 'statement') {
              final statementDate = acc.lastStatementImportAt ?? acc.balanceUpdatedAt;
              if (statementDate != null && !msg.timestamp.isAfter(statementDate)) {
                statementAllows = false;
              }
            }

            if (statementAllows) {
              final updatedAcc = Account(
                id: acc.id,
                name: acc.name,
                bankName: acc.bankName,
                accountNumber: acc.accountNumber,
                accountType: acc.accountType,
                balance: acc.balance,
                currentBalance: rawBalance,
                balanceSource: 'sms',
                balanceUpdatedAt: msg.timestamp,
                lastStatementImportAt: acc.lastStatementImportAt,
                currency: acc.currency,
                accentColor: acc.accentColor,
                isAutoDiscovered: acc.isAutoDiscovered,
                createdAt: acc.createdAt,
              );
              accountMap[accountId] = updatedAcc;
              accountHasReliableBalance[accountId] = true;
            }
          }
          summary.skipped++;
          continue;
        }

        final txDate = parsed.transactionTimestamp ?? msg.timestamp;

        // Multi-level Transaction Identity Evaluation
        final idResult = TransactionIdentityService.evaluateCandidate(
          parsed: parsed,
          txDate: txDate,
          accountId: accountId,
          bankId: bank?.id,
          senderName: senderName,
          rawText: msg.text,
          existingTransactions: existingTxList,
          seenIds: existingTxIds,
        );

        bool isNewlyImported = false;

        if (!idResult.isDuplicate) {
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
            accountId: accountId,
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
        }

        // Chronological balance tracking per account
        if (accountId != null && accountMap.containsKey(accountId)) {
          final acc = accountMap[accountId]!;

          bool statementAllows = true;
          if (acc.balanceSource == 'statement') {
            final statementDate = acc.lastStatementImportAt ?? acc.balanceUpdatedAt;
            if (statementDate != null && !txDate.isAfter(statementDate)) {
              statementAllows = false;
            }
          }

          if (statementAllows) {
            if (parsed.availableBalance != null) {
              // Explicit balance checkpoint (even if transaction was duplicate)
              final updatedAcc = Account(
                id: acc.id,
                name: acc.name,
                bankName: acc.bankName,
                accountNumber: acc.accountNumber,
                accountType: acc.accountType,
                balance: acc.balance,
                currentBalance: parsed.availableBalance!,
                balanceSource: 'sms',
                balanceUpdatedAt: txDate,
                lastStatementImportAt: acc.lastStatementImportAt,
                currency: acc.currency,
                accentColor: acc.accentColor,
                isAutoDiscovered: acc.isAutoDiscovered,
                createdAt: acc.createdAt,
              );
              accountMap[accountId] = updatedAcc;
              accountHasReliableBalance[accountId] = true;
            } else if (isNewlyImported && (accountHasReliableBalance[accountId] ?? false)) {
              // Calculated balance delta ONLY for newly imported transactions
              final delta = parsed.type == model_tx.TransactionType.expense ? -parsed.amount : parsed.amount;
              final newBal = acc.currentBalance + delta;
              final updatedAcc = Account(
                id: acc.id,
                name: acc.name,
                bankName: acc.bankName,
                accountNumber: acc.accountNumber,
                accountType: acc.accountType,
                balance: acc.balance,
                currentBalance: newBal,
                balanceSource: 'sms',
                balanceUpdatedAt: txDate,
                lastStatementImportAt: acc.lastStatementImportAt,
                currency: acc.currency,
                accentColor: acc.accentColor,
                isAutoDiscovered: acc.isAutoDiscovered,
                createdAt: acc.createdAt,
              );
              accountMap[accountId] = updatedAcc;
            }
          }
        }
      } catch (e) {
        summary.failed++;
      }
    }

    // 5. Commit updated account balances to repository once
    for (var acc in existingAccounts) {
      final updated = accountMap[acc.id];
      if (updated != null) {
        if (updated.currentBalance != acc.currentBalance || 
            updated.balanceUpdatedAt != acc.balanceUpdatedAt ||
            updated.balanceSource != acc.balanceSource) {
          try {
            await accountRepo.updateAccount(updated);
          } catch (e) {
            debugPrint('[SmsTransactionImporter] failed to update balance for account ${acc.id}: $e');
          }
        }
      }
    }

    // 6. Reconcile pending dues
    try {
      final pendingDues = await dueRepo.getPendingDues();
      if (pendingDues.isNotEmpty) {
        final recentTx = await transactionRepo.getTransactions(); 
        for (var due in pendingDues) {
          bool hasMatchingDebit = recentTx.any((tx) {
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

    return summary;
  }
}
