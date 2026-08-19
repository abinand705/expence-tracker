import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../../models/bank_statement.dart';
import 'statement_parser.dart';
import 'dart:developer' as developer;

class DocxStatementParser implements StatementParser {
  @override
  Future<ParsedBankStatement> parse(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? docXmlFile;
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        docXmlFile = file;
        break;
      }
    }

    if (docXmlFile == null) {
      throw Exception('Not a valid DOCX file (missing word/document.xml).');
    }

    final docXmlStr = utf8.decode(docXmlFile.content as List<int>);
    final document = XmlDocument.parse(docXmlStr);

    final tables = document.findAllElements('w:tbl');

    int headerRowIndex = -1;
    Map<String, int> colMap = {};
    List<List<String>>? statementRows;

    final possibleDateCols = ['date', 'txn date', 'transaction date', 'value date'];
    final possibleDescCols = ['description', 'narration', 'particulars', 'remarks', 'details'];
    final possibleDebitCols = ['debit', 'withdrawal', 'dr', 'paid out'];
    final possibleCreditCols = ['credit', 'deposit', 'cr', 'paid in'];
    final possibleBalanceCols = ['balance', 'closing balance'];
    final possibleRefCols = ['reference', 'ref', 'txn id', 'transaction id', 'chq no', 'cheque number'];

    for (var table in tables) {
      final rows = table.findAllElements('w:tr').toList();
      final currentTableRows = <List<String>>[];

      for (int i = 0; i < rows.length; i++) {
        final cells = rows[i].findAllElements('w:tc');
        final rowData = <String>[];
        for (var cell in cells) {
          final textNodes = cell.findAllElements('w:t');
          final cellText = textNodes.map((n) => n.innerText).join('').trim();
          rowData.add(cellText);
        }
        currentTableRows.add(rowData);

        if (headerRowIndex == -1) {
          colMap.clear();
          for (int j = 0; j < rowData.length; j++) {
            final cellValue = rowData[j].toLowerCase();
            if (possibleDateCols.contains(cellValue)) { colMap['date'] = j; }
            else if (possibleDescCols.contains(cellValue)) { colMap['description'] = j; }
            else if (possibleDebitCols.contains(cellValue)) { colMap['debit'] = j; }
            else if (possibleCreditCols.contains(cellValue)) { colMap['credit'] = j; }
            else if (possibleBalanceCols.contains(cellValue)) { colMap['balance'] = j; }
            else if (possibleRefCols.contains(cellValue)) { colMap['reference'] = j; }
          }
          if (colMap.containsKey('date') && colMap.containsKey('description') && (colMap.containsKey('debit') || colMap.containsKey('credit'))) {
            headerRowIndex = i;
            statementRows = currentTableRows;
          }
        }
      }
      if (headerRowIndex != -1) break;
    }

    if (statementRows == null || headerRowIndex == -1) {
      throw Exception('Could not find valid transaction table in DOCX.');
    }

    List<BankStatementTransaction> transactions = [];
    DateTime? startDate;
    DateTime? endDate;

    for (int i = headerRowIndex + 1; i < statementRows.length; i++) {
      final row = statementRows[i];
      if (row.isEmpty || row.every((element) => element.isEmpty)) continue;

      try {
        final dateStr = colMap.containsKey('date') && row.length > colMap['date']! ? row[colMap['date']!] : '';
        if (dateStr.isEmpty) continue;

        DateTime date = _parseDate(dateStr);
        if (startDate == null || date.isBefore(startDate)) startDate = date;
        if (endDate == null || date.isAfter(endDate)) endDate = date;

        final desc = colMap.containsKey('description') && row.length > colMap['description']! ? row[colMap['description']!] : '';
        final debitStr = colMap.containsKey('debit') && row.length > colMap['debit']! ? row[colMap['debit']!] : '';
        final creditStr = colMap.containsKey('credit') && row.length > colMap['credit']! ? row[colMap['credit']!] : '';
        final balanceStr = colMap.containsKey('balance') && row.length > colMap['balance']! ? row[colMap['balance']!] : '';
        final ref = colMap.containsKey('reference') && row.length > colMap['reference']! ? row[colMap['reference']!] : null;

        double debit = _parseDouble(debitStr);
        double credit = _parseDouble(creditStr);
        double? balance = balanceStr.isNotEmpty ? _parseDouble(balanceStr) : null;

        if (debit == 0 && credit == 0) continue; 

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
        developer.log('Skipping DOCX row due to error: $e', name: 'DocxStatementParser');
        continue;
      }
    }

    if (transactions.isEmpty) {
      throw Exception('No transactions found in DOCX.');
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
