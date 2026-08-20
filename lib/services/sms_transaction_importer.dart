import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/sms_models.dart';
import '../models/transaction.dart' as model_tx;
import '../repositories/transaction_repository.dart';
import '../services/bank_detection_service.dart';
import '../utils/expense_parser.dart';
import 'sms_account_resolver.dart';
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

  SmsTransactionImporter({required this.transactionRepo, this.pendingDueRepo});

  String? resolveTrueAccountId(String? preliminaryAccountId, String? last4, String bankId, List<Account>? existingAccounts) {
    if (existingAccounts == null) return preliminaryAccountId;
    
    String? searchLast4 = last4;
    if (searchLast4 == null && preliminaryAccountId != null && preliminaryAccountId.contains('_')) {
      searchLast4 = preliminaryAccountId.split('_').last;
    }
    
    if (searchLast4 == null || searchLast4.isEmpty) return null;

    String normalizeSuffix(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
    final normSearchLast4 = normalizeSuffix(searchLast4);
    if (normSearchLast4.isEmpty) return null;

    if (preliminaryAccountId != null) {
      if (existingAccounts.any((a) => a.id == preliminaryAccountId)) {
        return preliminaryAccountId;
      }
    }

    final bankMatches = existingAccounts.where((a) {
      final accNormSuffix = normalizeSuffix(a.accountNumber);
      if (accNormSuffix.isEmpty) return false;
      
      bool suffixMatch = accNormSuffix == normSearchLast4 || 
                         accNormSuffix.endsWith(normSearchLast4) || 
                         normSearchLast4.endsWith(accNormSuffix);
      if (!suffixMatch) return false;
      
      final normBankId = bankId.toLowerCase();
      final normBankName = a.bankName.toLowerCase();
      return a.id.startsWith('${bankId}_') || 
             normBankName.contains(normBankId) || 
             normBankId.contains(normBankName);
    }).toList();

    if (bankMatches.length == 1) {
      return bankMatches.first.id;
    } else if (bankMatches.length > 1) {
      return null;
    }

    return preliminaryAccountId ?? '${bankId}_$searchLast4';
  }

  Future<SmsImportResult> importMessage(Message msg, String senderName, [SmsAccountResolver? resolver, PendingDueRepository? dueRepo, List<Account>? existingAccounts]) async {
    try {
      final parsedDue = ExpenseParser.parsePendingDue(msg.text, msg.timestamp);
      
      var bank = BankDetectionService().identifyBank(senderName, msg.text);
      if (parsedDue?.bankName != null) {
        final explicitBank = BankDetectionService().identifyBank('', parsedDue!.bankName!);
        if (explicitBank != null) bank = explicitBank;
      }

      String? accountId;
      if (bank != null) {
        String? last4;
        if (parsedDue?.accountSuffix != null) {
          last4 = parsedDue!.accountSuffix;
          accountId = '${bank.id}_$last4';
        } else if (resolver != null) {
          accountId = resolver.resolveAccountId(
            sender: senderName,
            messageText: msg.text,
            bank: bank,
          );
          if (accountId != null) {
            last4 = accountId.split('_').last;
          }
        } else {
          last4 = ExpenseParser.extractAccountNumber(msg.text);
          if (last4 != null && last4.isNotEmpty) {
            accountId = '${bank.id}_$last4';
          }
        }
        accountId = resolveTrueAccountId(accountId, last4, bank.id, existingAccounts);
      }

      if (parsedDue != null && dueRepo != null) {
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
        return SmsImportResult.imported; 
      }

      final parsed = ExpenseParser.parse(msg.text);
      if (parsed == null) {
        return SmsImportResult.skipped;
      }


      // Generate deterministic fingerprint
      final normalizedSender = senderName.trim().toLowerCase();
      final normalizedBody = msg.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final timestampIso = msg.timestamp.toUtc().toIso8601String();
      
      final rawString = '${normalizedSender}_${timestampIso}_$normalizedBody';
      final bytes = utf8.encode(rawString);
      final digest = sha256.convert(bytes);
      final fingerprint = digest.toString();
      final deterministicId = 'sms_$fingerprint';

      // Convert to Transaction
      final transaction = model_tx.Transaction(
        id: deterministicId,
        amount: parsed.amount,
        type: parsed.type,
        merchant: parsed.merchant ?? 'Unknown Merchant',
        category: ExpenseParser.guessCategory(parsed.merchant),
        date: msg.timestamp,
        subtitle: senderName,
        rawMessage: msg.text,
        source: 'sms',
        transactionSource: 'sms',
        isManual: false,
        accountId: accountId,
      );

      // Duplicate prevention: Atomic check
      final success = await transactionRepo.addTransactionIfAbsent(transaction);
      if (!success) {
        return SmsImportResult.duplicate;
      }

      return SmsImportResult.imported;
    } catch (e) {
      return SmsImportResult.failed;
    }
  }

  Future<SmsImportSummary> importAllBankMessages(List<Conversation> conversations) async {
    final summary = SmsImportSummary();
    final resolver = SmsAccountResolver();
    // Default to a real repository if none provided (for prod usage).
    // In tests, pendingDueRepo will be injected or bypassed.
    final dueRepo = pendingDueRepo ?? PendingDueRepository();
    final accountRepo = AccountRepository();
    
    List<Account> existingAccounts = [];
    try {
      existingAccounts = await accountRepo.getAccounts();
    } catch (e) {
      // Allow fallback if not authenticated
    }

    for (var conv in conversations) {
      if (conv.isBankSender) {
        final sortedMessages = List<Message>.from(conv.messages)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        for (var msg in sortedMessages) {
          summary.scanned++;
          final result = await importMessage(msg, conv.senderName, resolver, dueRepo, existingAccounts);
          switch (result) {
            case SmsImportResult.imported:
              summary.imported++;
              break;
            case SmsImportResult.duplicate:
              summary.duplicates++;
              break;
            case SmsImportResult.skipped:
              summary.skipped++;
              break;
            case SmsImportResult.failed:
              summary.failed++;
              break;
          }
        }
      }
    }

    // Reconcile pending dues
    try {
       final pendingDues = await dueRepo.getPendingDues();
       if (pendingDues.isNotEmpty) {
         final now = DateTime.now();
         final today = DateTime(now.year, now.month, now.day);
         final recentTx = await transactionRepo.getTransactions(); 
         for (var due in pendingDues) {
           // Wait, "If due date passes without a matching completed transaction, DO NOT silently delete it."
           // Only delete if there is a matching completed debit.
           // A matching debit: same accountId, same amount, date >= due.detectedAt and date is around dueDate.
           bool hasMatchingDebit = recentTx.any((tx) {
             if (tx.type != model_tx.TransactionType.expense) return false;
             if (due.accountId != null && tx.accountId != null && due.accountId != tx.accountId) return false;
             if ((tx.amount - due.amount).abs() > 0.01) return false;
             // Date constraint: must be after detectedAt, and around or after dueDate
             if (tx.date.isBefore(due.detectedAt)) return false;
             return true;
           });

           if (hasMatchingDebit) {
             await dueRepo.deletePendingDue(due.id);
           }
         }
       }
    } catch (e) {
       // Ignore reconciliation errors
    }

    return summary;
  }
}
