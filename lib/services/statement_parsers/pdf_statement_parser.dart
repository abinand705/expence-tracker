import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../../models/bank_statement.dart';
import 'statement_parser.dart';

class PdfStatementParser implements StatementParser {
  @override
  Future<ParsedBankStatement> parse(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();

    if (text == null || text.trim().isEmpty) {
      throw Exception('Unable to read this PDF statement. Please use a text-based bank statement or CSV/XLSX.');
    }

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    int headerRowIndex = -1;
    Map<String, int> colMap = {};
    List<List<String>> parsedRows = [];

    final possibleDateCols = ['date', 'txn date', 'transaction date', 'value date'];
    final possibleDescCols = ['description', 'narration', 'particulars', 'remarks', 'details'];
    final possibleDebitCols = ['debit', 'withdrawal', 'dr', 'paid out'];
    final possibleCreditCols = ['credit', 'deposit', 'cr', 'paid in'];
    final possibleBalanceCols = ['balance', 'closing balance'];

    // Try to find header and parse rows
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Split by 2 or more spaces or tabs to simulate columns
      final cols = line.split(RegExp(r'\s{2,}|\t'));
      
      if (headerRowIndex == -1) {
        int matches = 0;
        colMap.clear();
        for (int j = 0; j < cols.length; j++) {
          final cellValue = cols[j].toLowerCase().trim();
          if (possibleDateCols.contains(cellValue)) { colMap['date'] = j; matches++; }
          else if (possibleDescCols.contains(cellValue)) { colMap['description'] = j; matches++; }
          else if (possibleDebitCols.contains(cellValue)) { colMap['debit'] = j; matches++; }
          else if (possibleCreditCols.contains(cellValue)) { colMap['credit'] = j; matches++; }
          else if (possibleBalanceCols.contains(cellValue)) { colMap['balance'] = j; matches++; }
        }
        if (colMap.containsKey('date') && colMap.containsKey('description') && (colMap.containsKey('debit') || colMap.containsKey('credit'))) {
          headerRowIndex = i;
        }
      } else {
        if (cols.length >= 3) {
          parsedRows.add(cols);
        }
      }
    }

    if (headerRowIndex == -1 || parsedRows.isEmpty) {
      throw Exception('Could not find valid transaction headers in PDF. Please check the format.');
    }

    List<BankStatementTransaction> transactions = [];
    DateTime? startDate;
    DateTime? endDate;

    for (var row in parsedRows) {
      try {
        final dateStr = colMap.containsKey('date') && row.length > colMap['date']! ? row[colMap['date']!].trim() : '';
        if (dateStr.isEmpty) continue;

        DateTime date = _parseDate(dateStr);
        if (startDate == null || date.isBefore(startDate)) startDate = date;
        if (endDate == null || date.isAfter(endDate)) endDate = date;

        final desc = colMap.containsKey('description') && row.length > colMap['description']! ? row[colMap['description']!].trim() : '';
        final debitStr = colMap.containsKey('debit') && row.length > colMap['debit']! ? row[colMap['debit']!].trim() : '';
        final creditStr = colMap.containsKey('credit') && row.length > colMap['credit']! ? row[colMap['credit']!].trim() : '';
        final balanceStr = colMap.containsKey('balance') && row.length > colMap['balance']! ? row[colMap['balance']!].trim() : '';
        
        double debit = _parseDouble(debitStr);
        double credit = _parseDouble(creditStr);
        double? balance = balanceStr.isNotEmpty ? _parseDouble(balanceStr) : null;

        if (debit == 0 && credit == 0) continue;

        final normalizedDesc = desc.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        
        final rawStr = 'emptyAccountId_${date.millisecondsSinceEpoch}_${normalizedDesc}_${debit}_${credit}_';
        final fingerprint = sha256.convert(utf8.encode(rawStr)).toString();

        transactions.add(BankStatementTransaction(
          id: '', 
          accountId: '',
          date: date,
          description: desc,
          debit: debit,
          credit: credit,
          balance: balance,
          rawRowFingerprint: fingerprint,
        ));
      } catch (e) {
        continue;
      }
    }

    if (transactions.isEmpty) {
      throw Exception('No transactions found in PDF.');
    }

    transactions.sort((a, b) => a.date.compareTo(b.date));

    double? openingBalance;
    double? closingBalance;

    if (transactions.first.balance != null) {
      openingBalance = transactions.first.balance! + transactions.first.debit - transactions.first.credit;
    }
    closingBalance = transactions.last.balance;

    return ParsedBankStatement(
      statementStartDate: startDate,
      statementEndDate: endDate,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      transactions: transactions,
    );
  }

  DateTime _parseDate(String dateStr) {
    final formats = [
      'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd', 'dd-MM-yyyy', 'dd MMM yyyy', 'dd-MMM-yyyy',
      'dd/MM/yy', 'MM/dd/yy',
    ];
    for (var format in formats) {
      try {
        return DateFormat(format).parseStrict(dateStr);
      } catch (_) {}
    }
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}
    
    throw FormatException('Could not parse date: $dateStr');
  }

  double _parseDouble(String val) {
    if (val.isEmpty) return 0.0;
    val = val.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.-]'), '');
    if (val.isEmpty) return 0.0;
    return double.parse(val);
  }
}
