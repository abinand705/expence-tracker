import 'dart:io';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../../models/bank_statement.dart';
import 'statement_parser.dart';

class CsvStatementParser implements StatementParser {
  @override
  Future<ParsedBankStatement> parse(File file) async {
    final contents = await file.readAsString();
    
    // Auto-detect delimiter
    String delimiter = ',';
    if (contents.split(';').length > contents.split(',').length) {
      delimiter = ';';
    } else if (contents.split('\t').length > contents.split(',').length) {
      delimiter = '\t';
    }

    final rows = const CsvToListConverter().convert(contents, fieldDelimiter: delimiter);

    int headerRowIndex = -1;
    Map<String, int> colMap = {};

    final possibleDateCols = ['date', 'txn date', 'transaction date', 'value date'];
    final possibleDescCols = ['description', 'narration', 'particulars', 'remarks', 'details'];
    final possibleDebitCols = ['debit', 'withdrawal', 'dr', 'paid out'];
    final possibleCreditCols = ['credit', 'deposit', 'cr', 'paid in'];
    final possibleBalanceCols = ['balance', 'closing balance'];
    final possibleRefCols = ['reference', 'ref', 'txn id', 'transaction id', 'chq no', 'cheque number'];

    // Find header row
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      int matches = 0;
      for (int j = 0; j < row.length; j++) {
        final cell = row[j].toString().toLowerCase().trim();
        if (possibleDateCols.contains(cell)) { colMap['date'] = j; matches++; }
        else if (possibleDescCols.contains(cell)) { colMap['description'] = j; matches++; }
        else if (possibleDebitCols.contains(cell)) { colMap['debit'] = j; matches++; }
        else if (possibleCreditCols.contains(cell)) { colMap['credit'] = j; matches++; }
        else if (possibleBalanceCols.contains(cell)) { colMap['balance'] = j; matches++; }
        else if (possibleRefCols.contains(cell)) { colMap['reference'] = j; }
      }
      if (colMap.containsKey('date') && colMap.containsKey('description') && (colMap.containsKey('debit') || colMap.containsKey('credit'))) {
        headerRowIndex = i;
        break;
      }
    }

    if (headerRowIndex == -1) {
      throw Exception('Could not find valid transaction headers in CSV.');
    }

    List<BankStatementTransaction> transactions = [];
    DateTime? startDate;
    DateTime? endDate;

    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((element) => element.toString().trim().isEmpty)) continue;

      try {
        final dateStr = colMap.containsKey('date') && row.length > colMap['date']! ? row[colMap['date']!].toString().trim() : '';
        if (dateStr.isEmpty) continue;

        DateTime date = _parseDate(dateStr);
        if (startDate == null || date.isBefore(startDate)) startDate = date;
        if (endDate == null || date.isAfter(endDate)) endDate = date;

        final desc = colMap.containsKey('description') && row.length > colMap['description']! ? row[colMap['description']!].toString().trim() : '';
        final debitStr = colMap.containsKey('debit') && row.length > colMap['debit']! ? row[colMap['debit']!].toString().trim() : '';
        final creditStr = colMap.containsKey('credit') && row.length > colMap['credit']! ? row[colMap['credit']!].toString().trim() : '';
        final balanceStr = colMap.containsKey('balance') && row.length > colMap['balance']! ? row[colMap['balance']!].toString().trim() : '';
        final ref = colMap.containsKey('reference') && row.length > colMap['reference']! ? row[colMap['reference']!].toString().trim() : null;

        double debit = _parseDouble(debitStr);
        double credit = _parseDouble(creditStr);
        double? balance = balanceStr.isNotEmpty ? _parseDouble(balanceStr) : null;

        if (debit == 0 && credit == 0) continue; // Skip non-financial rows

        final normalizedDesc = desc.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        
        // We will assign accountId later in BankStatementService
        final rawStr = 'emptyAccountId_${date.millisecondsSinceEpoch}_${normalizedDesc}_${debit}_${credit}_${ref ?? ""}';
        final fingerprint = sha256.convert(utf8.encode(rawStr)).toString();

        transactions.add(BankStatementTransaction(
          id: '', // Generated later
          accountId: '', // Assigned later
          date: date,
          description: desc,
          reference: ref,
          debit: debit,
          credit: credit,
          balance: balance,
          rawRowFingerprint: fingerprint,
        ));
      } catch (e) {
        print('Skipping CSV row due to error: $e');
        continue;
      }
    }

    if (transactions.isEmpty) {
      throw Exception('No transactions found in CSV.');
    }

    transactions.sort((a, b) => a.date.compareTo(b.date));

    // Try to find opening and closing balances
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
    // Try multiple formats
    final formats = [
      'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd', 'dd-MM-yyyy', 'dd MMM yyyy', 'dd-MMM-yyyy',
      'dd/MM/yy', 'MM/dd/yy',
    ];
    for (var format in formats) {
      try {
        return DateFormat(format).parseStrict(dateStr);
      } catch (_) {}
    }
    // Fallback
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
