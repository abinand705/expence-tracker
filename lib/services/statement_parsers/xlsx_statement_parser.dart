import 'dart:io';
import 'package:excel/excel.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../../models/bank_statement.dart';
import 'statement_parser.dart';

class XlsxStatementParser implements StatementParser {
  @override
  Future<ParsedBankStatement> parse(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    int headerRowIndex = -1;
    Map<String, int> colMap = {};
    String? statementSheet;
    List<List<Data?>>? rows;

    final possibleDateCols = ['date', 'txn date', 'transaction date', 'value date'];
    final possibleDescCols = ['description', 'narration', 'particulars', 'remarks', 'details'];
    final possibleDebitCols = ['debit', 'withdrawal', 'dr', 'paid out'];
    final possibleCreditCols = ['credit', 'deposit', 'cr', 'paid in'];
    final possibleBalanceCols = ['balance', 'closing balance'];
    final possibleRefCols = ['reference', 'ref', 'txn id', 'transaction id', 'chq no', 'cheque number'];

    // Search sheets for transaction table
    for (var table in excel.tables.keys) {
      final sheetRows = excel.tables[table]?.rows;
      if (sheetRows == null) continue;

      for (int i = 0; i < sheetRows.length; i++) {
        final row = sheetRows[i];
        int matches = 0;
        colMap.clear();

        for (int j = 0; j < row.length; j++) {
          final cellValue = row[j]?.value?.toString().toLowerCase().trim() ?? '';
          if (possibleDateCols.contains(cellValue)) { colMap['date'] = j; }
          else if (possibleDescCols.contains(cellValue)) { colMap['description'] = j; }
          else if (possibleDebitCols.contains(cellValue)) { colMap['debit'] = j; }
          else if (possibleCreditCols.contains(cellValue)) { colMap['credit'] = j; }
          else if (possibleBalanceCols.contains(cellValue)) { colMap['balance'] = j; }
          else if (possibleRefCols.contains(cellValue)) { colMap['reference'] = j; }
        }

        if (colMap.containsKey('date') && colMap.containsKey('description') && (colMap.containsKey('debit') || colMap.containsKey('credit'))) {
          headerRowIndex = i;
          statementSheet = table;
          rows = sheetRows;
          break;
        }
      }
      if (statementSheet != null) break;
    }

    if (statementSheet == null || rows == null || headerRowIndex == -1) {
      throw Exception('Could not find valid transaction headers in XLSX.');
    }

    List<BankStatementTransaction> transactions = [];
    DateTime? startDate;
    DateTime? endDate;

    for (int i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((element) => element?.value == null || element!.value.toString().trim().isEmpty)) continue;

      try {
        final dateData = colMap.containsKey('date') && row.length > colMap['date']! ? row[colMap['date']!]?.value : null;
        if (dateData == null) continue;
        final dateStr = dateData.toString().trim();
        if (dateStr.isEmpty) continue;

        DateTime date;
        if (dateData is DateTimeCellValue) {
           date = DateTime(dateData.year, dateData.month, dateData.day, dateData.hour, dateData.minute);
        } else if (dateData is DateCellValue) {
           date = DateTime(dateData.year, dateData.month, dateData.day);
        } else {
           date = _parseDate(dateStr);
        }

        if (startDate == null || date.isBefore(startDate)) startDate = date;
        if (endDate == null || date.isAfter(endDate)) endDate = date;

        final desc = colMap.containsKey('description') && row.length > colMap['description']! ? row[colMap['description']!]?.value?.toString().trim() ?? '' : '';
        final debitStr = colMap.containsKey('debit') && row.length > colMap['debit']! ? row[colMap['debit']!]?.value?.toString().trim() ?? '' : '';
        final creditStr = colMap.containsKey('credit') && row.length > colMap['credit']! ? row[colMap['credit']!]?.value?.toString().trim() ?? '' : '';
        final balanceStr = colMap.containsKey('balance') && row.length > colMap['balance']! ? row[colMap['balance']!]?.value?.toString().trim() ?? '' : '';
        final ref = colMap.containsKey('reference') && row.length > colMap['reference']! ? row[colMap['reference']!]?.value?.toString().trim() : null;

        double debit = _parseDouble(debitStr);
        double credit = _parseDouble(creditStr);
        double? balance = balanceStr.isNotEmpty ? _parseDouble(balanceStr) : null;

        if (debit == 0 && credit == 0) continue; // Skip non-financial rows

        final normalizedDesc = desc.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        
        final rawStr = 'emptyAccountId_${date.millisecondsSinceEpoch}_${normalizedDesc}_${debit}_${credit}_${ref ?? ""}';
        final fingerprint = sha256.convert(utf8.encode(rawStr)).toString();

        transactions.add(BankStatementTransaction(
          id: '', 
          accountId: '',
          date: date,
          description: desc,
          reference: ref,
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
      throw Exception('No transactions found in XLSX.');
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
