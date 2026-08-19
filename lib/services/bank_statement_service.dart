import 'dart:io';
import 'dart:developer' as developer;
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;

import '../models/bank_statement.dart';
import '../models/account.dart';
import '../models/transaction.dart' as tm;
import '../repositories/transaction_repository.dart';
import '../repositories/statement_repository.dart';
import '../repositories/account_repository.dart';

import 'statement_parsers/statement_parser.dart';
import 'statement_parsers/csv_statement_parser.dart';
import 'statement_parsers/xlsx_statement_parser.dart';
import 'statement_parsers/docx_statement_parser.dart';
import 'statement_parsers/pdf_statement_parser.dart';

class BankStatementService {
  final TransactionRepository _transactionRepository = TransactionRepository();
  final StatementRepository _statementRepository = StatementRepository();
  final AccountRepository _accountRepository = AccountRepository();

  Future<ParsedBankStatement?> pickAndParseStatement(Account account) async {
    try {
      PlatformFile? result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'docx', 'pdf'],
      );

      if (result != null && result.path != null) {
        String path = result.path!;
        File file = File(path);
        String extension = p.extension(path).toLowerCase();

        StatementParser parser;
        switch (extension) {
          case '.csv':
            parser = CsvStatementParser();
            break;
          case '.xlsx':
            parser = XlsxStatementParser();
            break;
          case '.docx':
            parser = DocxStatementParser();
            break;
          case '.pdf':
            parser = PdfStatementParser();
            break;
          default:
            throw Exception('Unsupported statement format.');
        }

        developer.log('parsing started for $extension', name: 'BankStatementService');
        final parsedStatement = await parser.parse(file);
        
        if (parsedStatement.transactions.isEmpty) {
          throw Exception('Could not detect transactions or account information from this statement.');
        }
        
        developer.log('transactions parsed: ${parsedStatement.transactions.length}', name: 'BankStatementService');

        // Validate account match
        if (parsedStatement.accountLast4 != null && parsedStatement.accountLast4!.isNotEmpty && account.accountNumber.isNotEmpty) {
          if (!account.accountNumber.endsWith(parsedStatement.accountLast4!)) {
            throw Exception('Account mismatch. This statement belongs to an account ending in ${parsedStatement.accountLast4}.');
          }
        }

        // Reconcile balances
        if (parsedStatement.openingBalance != null && parsedStatement.closingBalance != null) {
          double calculatedBalance = parsedStatement.openingBalance!;
          for (var t in parsedStatement.transactions) {
            calculatedBalance += t.credit - t.debit;
          }
          
          if ((calculatedBalance - parsedStatement.closingBalance!).abs() > 1.0) {
             throw Exception('The statement balance could not be verified. Please check that the statement is complete.');
          } else {
             developer.log('reconciliation successful', name: 'BankStatementService');
          }
        }

        return parsedStatement;
      }
      return null;
    } catch (e) {
      developer.log('error: $e', name: 'BankStatementService');
      if (e is Exception && (e.toString().contains('Unsupported statement format') ||
          e.toString().contains('Could not detect transactions') ||
          e.toString().contains('Account mismatch') ||
          e.toString().contains('The statement balance could not be verified'))) {
        rethrow;
      }
      throw Exception('Unable to read this statement. Please make sure the file is a supported bank statement.');
    }
  }

  Future<Map<String, int>> importStatement(
    String uid, 
    Account account, 
    ParsedBankStatement parsedStatement, 
    String fileName, 
    String fileType
  ) async {
    int newTransactionsCount = 0;
    int duplicatesSkipped = 0;

    // Fetch existing transactions to do in-memory duplicate check to save reads/writes and enable probable matching
    final existingTransactions = await _transactionRepository.getTransactionsForAccount(account.id);

    List<tm.Transaction> newTransactions = [];
    final statementId = const Uuid().v4();
    
    for (var stTx in parsedStatement.transactions) {
      final amount = stTx.debit > 0 ? stTx.debit : stTx.credit;
      final type = stTx.debit > 0 ? tm.TransactionType.expense : tm.TransactionType.income;
      final rawStr = '${account.id}_${stTx.date.millisecondsSinceEpoch}_${stTx.description.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase()}_${stTx.debit}_${stTx.credit}_${stTx.reference ?? ""}';
      final fingerprint = sha256.convert(utf8.encode(rawStr)).toString();
      final txId = 'statement_$fingerprint';

      // Check Exact duplicate by sourceFingerprint OR exact match fields
      bool isDuplicate = existingTransactions.any((tx) {
        if (tx.sourceFingerprint == fingerprint) return true;
        if (tx.id == txId) return true;
        
        // Probable duplicate check
        // same account, same date (ignore time), same amount, same type
        final sameDay = tx.date.year == stTx.date.year && 
                        tx.date.month == stTx.date.month && 
                        tx.date.day == stTx.date.day;
        
        if (tx.accountId == account.id && sameDay && tx.amount == amount && tx.type == type) {
           if (stTx.reference != null && stTx.reference!.isNotEmpty && tx.upiReference == stTx.reference) {
             return true; // Exact reference match
           }
           
           // If reference is not available, check similar description
           if ((stTx.reference == null || stTx.reference!.isEmpty) && (tx.upiReference == null || tx.upiReference!.isEmpty)) {
             // For safety, only consider duplicate if descriptions are very similar
             final txDesc = tx.description?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ?? '';
             final stDesc = stTx.description.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
             
             if (txDesc.isNotEmpty && stDesc.isNotEmpty && (txDesc.contains(stDesc) || stDesc.contains(txDesc))) {
               return true;
             }
           }
        }
        return false;
      });

      // Also check against newTransactions list to prevent duplicates within the same statement file
      if (!isDuplicate) {
        isDuplicate = newTransactions.any((tx) => tx.sourceFingerprint == fingerprint);
      }

      if (isDuplicate) {
        duplicatesSkipped++;
      } else {
        newTransactions.add(tm.Transaction(
          id: txId,
          accountId: account.id,
          amount: amount,
          type: type,
          merchant: '', 
          description: stTx.description,
          category: 'Uncategorized', // Let user categorize later
          date: stTx.date,
          transactionSource: 'statement',
          sourceId: statementId,
          sourceFingerprint: fingerprint,
          upiReference: stTx.reference,
          isManual: false,
        ));
        newTransactionsCount++;
      }
    }

    // Batch add to Firestore
    await _transactionRepository.batchAddTransactions(newTransactions);

    // Update Account
    if (parsedStatement.closingBalance != null) {
      final now = DateTime.now();
      // Only update balance if statement is newer or equal priority
      // Account balance rule: if balanceSource is statement, keep it. 
      // If balanceSource is SMS, statement overwrites SMS.
      final updatedAccount = Account(
        id: account.id,
        name: account.name,
        bankName: account.bankName,
        accountNumber: account.accountNumber,
        accountType: account.accountType,
        balance: account.balance,
        currentBalance: parsedStatement.closingBalance!,
        balanceSource: 'statement',
        balanceUpdatedAt: now,
        lastStatementImportAt: now,
        currency: account.currency,
        accentColor: account.accentColor,
        isAutoDiscovered: account.isAutoDiscovered,
      );
      await _accountRepository.updateAccount(updatedAccount);
    }

    // Create Statement Record
    final statement = BankStatement(
      id: statementId,
      accountId: account.id,
      bankId: account.bankName,
      fileName: fileName,
      fileType: fileType,
      statementStartDate: parsedStatement.statementStartDate ?? DateTime.now(),
      statementEndDate: parsedStatement.statementEndDate ?? DateTime.now(),
      openingBalance: parsedStatement.openingBalance ?? 0.0,
      closingBalance: parsedStatement.closingBalance ?? 0.0,
      transactionCount: parsedStatement.transactions.length,
      importedAt: DateTime.now(),
    );
    await _statementRepository.addStatement(uid, statement);

    developer.log('import completed', name: 'BankStatementService');

    return {
      'newTransactions': newTransactionsCount,
      'duplicatesSkipped': duplicatesSkipped,
    };
  }
}
