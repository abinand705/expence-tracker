import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';


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
    PlatformFile? result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'docx', 'pdf'],
    );

    if (result != null && result.path != null) {
      String path = result.path!;
      File file = File(path);
      String extension = path.substring(path.lastIndexOf('.')).toLowerCase();

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
          throw Exception('Unsupported file format: $extension');
      }

      print('[Statement] parsing started for $extension');
      final parsedStatement = await parser.parse(file);
      print('[Statement] transactions parsed: ${parsedStatement.transactions.length}');

      // Validate account match
      if (parsedStatement.accountLast4 != null && account.accountNumber.isNotEmpty) {
        if (!account.accountNumber.endsWith(parsedStatement.accountLast4!)) {
          throw Exception('Statement account ending in ${parsedStatement.accountLast4} does not match the selected account.');
        }
      }

      // Reconcile balances
      if (parsedStatement.openingBalance != null && parsedStatement.closingBalance != null) {
        double calculatedBalance = parsedStatement.openingBalance!;
        for (var t in parsedStatement.transactions) {
          calculatedBalance += t.credit - t.debit;
        }
        
        if ((calculatedBalance - parsedStatement.closingBalance!).abs() > 1.0) {
           throw Exception('Statement balance does not reconcile with the transactions in this statement.');
        } else {
           print('[Statement] reconciliation successful');
        }
      }

      return parsedStatement;
    }
    return null;
  }

  Future<Map<String, int>> importStatement(
    String uid, 
    Account account, 
    ParsedBankStatement parsedStatement, 
    String fileName, 
    String fileType
  ) async {
    int newTransactions = 0;
    int duplicatesSkipped = 0;

    // We can't query all existing transactions perfectly, so we just use addTransactionIfAbsent which
    // is safe if we generate consistent IDs.
    // However, the SMS importer used a different ID format.
    // We will generate `statement_{fingerprint}` for statement transactions.
    
    for (var stTx in parsedStatement.transactions) {
      // Re-generate fingerprint with correct accountId
      final rawStr = '${account.id}_${stTx.date.millisecondsSinceEpoch}_${stTx.description.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase()}_${stTx.debit}_${stTx.credit}_${stTx.reference ?? ""}';
      final fingerprint = sha256.convert(utf8.encode(rawStr)).toString();
      final txId = 'statement_$fingerprint';

      final transaction = tm.Transaction(
        id: txId,
        accountId: account.id,
        amount: stTx.debit > 0 ? stTx.debit : stTx.credit,
        type: stTx.debit > 0 ? tm.TransactionType.expense : tm.TransactionType.income,
        merchant: '', 
        description: stTx.description,
        category: 'Uncategorized', // Let user categorize later
        date: stTx.date,
        transactionSource: 'statement',
        upiReference: stTx.reference,
        isManual: false,
      );

      final added = await _transactionRepository.addTransactionIfAbsent(transaction);
      if (added) {
        newTransactions++;
      } else {
        duplicatesSkipped++;
      }
    }

    // Update Account
    if (parsedStatement.closingBalance != null) {
      final updatedAccount = Account(
        id: account.id,
        name: account.name,
        bankName: account.bankName,
        accountNumber: account.accountNumber,
        accountType: account.accountType,
        balance: account.balance, // keep legacy unchanged
        currentBalance: parsedStatement.closingBalance!,
        balanceSource: 'statement',
        balanceUpdatedAt: DateTime.now(),
        lastStatementImportAt: DateTime.now(),
        currency: account.currency,
        accentColor: account.accentColor,
        isAutoDiscovered: account.isAutoDiscovered,
      );
      await _accountRepository.updateAccount(updatedAccount);
    }

    // Create Statement Record
    final statementId = const Uuid().v4();
    final statement = BankStatement(
      id: statementId,
      accountId: account.id,
      bankId: account.bankName, // We don't have bankId stored purely, so using bankName
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

    print('[Statement] import completed');

    return {
      'newTransactions': newTransactions,
      'duplicatesSkipped': duplicatesSkipped,
    };
  }
}
