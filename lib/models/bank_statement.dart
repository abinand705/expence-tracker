import 'package:cloud_firestore/cloud_firestore.dart';

class BankStatement {
  final String id;
  final String accountId;
  final String bankId;
  final String fileName;
  final String fileType;
  final DateTime statementStartDate;
  final DateTime statementEndDate;
  final double openingBalance;
  final double closingBalance;
  final int transactionCount;
  final DateTime importedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BankStatement({
    required this.id,
    required this.accountId,
    required this.bankId,
    required this.fileName,
    required this.fileType,
    required this.statementStartDate,
    required this.statementEndDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.transactionCount,
    required this.importedAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'bankId': bankId,
      'fileName': fileName,
      'fileType': fileType,
      'statementStartDate': Timestamp.fromDate(statementStartDate),
      'statementEndDate': Timestamp.fromDate(statementEndDate),
      'openingBalance': openingBalance,
      'closingBalance': closingBalance,
      'transactionCount': transactionCount,
      'importedAt': Timestamp.fromDate(importedAt),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory BankStatement.fromMap(Map<String, dynamic> map) {
    return BankStatement(
      id: map['id'] ?? '',
      accountId: map['accountId'] ?? '',
      bankId: map['bankId'] ?? '',
      fileName: map['fileName'] ?? '',
      fileType: map['fileType'] ?? '',
      statementStartDate: (map['statementStartDate'] as Timestamp).toDate(),
      statementEndDate: (map['statementEndDate'] as Timestamp).toDate(),
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      closingBalance: (map['closingBalance'] as num?)?.toDouble() ?? 0.0,
      transactionCount: map['transactionCount']?.toInt() ?? 0,
      importedAt: (map['importedAt'] as Timestamp).toDate(),
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}

class BankStatementTransaction {
  final String id;
  final String accountId;
  final DateTime date;
  final String description;
  final String? reference;
  final double debit;
  final double credit;
  final double? balance;
  final String rawRowFingerprint;

  BankStatementTransaction({
    required this.id,
    required this.accountId,
    required this.date,
    required this.description,
    this.reference,
    this.debit = 0.0,
    this.credit = 0.0,
    this.balance,
    required this.rawRowFingerprint,
  });
}

class ParsedBankStatement {
  final String? bankName;
  final String? accountLast4;
  final DateTime? statementStartDate;
  final DateTime? statementEndDate;
  final double? openingBalance;
  final double? closingBalance;
  final List<BankStatementTransaction> transactions;

  ParsedBankStatement({
    this.bankName,
    this.accountLast4,
    this.statementStartDate,
    this.statementEndDate,
    this.openingBalance,
    this.closingBalance,
    required this.transactions,
  });
}
