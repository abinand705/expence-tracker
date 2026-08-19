import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String merchant;
  final String category;
  final String? description;
  final String? accountId;
  final String transactionSource;
  final String? subcategory;
  final DateTime date;
  final String? paymentMethod;
  final String? upiReference;
  final String? accountNumber;
  final String? rawMessage;
  final String? source;
  final bool isManual;
  final bool isRecurring;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? subtitle;
  final String? sourceId;
  final String? sourceFingerprint;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    this.description,
    this.accountId,
    this.transactionSource = 'manual',
    this.subcategory,
    required this.date,
    this.paymentMethod,
    this.upiReference,
    this.accountNumber,
    this.rawMessage,
    this.source,
    this.isManual = false,
    this.isRecurring = false,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.subtitle,
    this.sourceId,
    this.sourceFingerprint,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.name,
      'merchant': merchant,
      'category': category,
      'description': description,
      'accountId': accountId,
      'transactionSource': transactionSource,
      'subcategory': subcategory,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'upiReference': upiReference,
      'accountNumber': accountNumber,
      'rawMessage': rawMessage,
      'source': source,
      'isManual': isManual,
      'isRecurring': isRecurring,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'subtitle': subtitle,
      'sourceId': sourceId,
      'sourceFingerprint': sourceFingerprint,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    return Transaction(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      merchant: map['merchant'],
      category: map['category'],
      description: map['description'] ?? '',
      accountId: map['accountId'] ?? '',
      transactionSource: map['transactionSource'] ?? 'manual',
      subcategory: map['subcategory'],
      date: parseDate(map['date']),
      paymentMethod: map['paymentMethod'],
      upiReference: map['upiReference'],
      accountNumber: map['accountNumber'],
      rawMessage: map['rawMessage'],
      source: map['source'],
      isManual: map['isManual'] ?? false,
      isRecurring: map['isRecurring'] ?? false,
      notes: map['notes'],
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      subtitle: map['subtitle'],
      sourceId: map['sourceId'],
      sourceFingerprint: map['sourceFingerprint'],
    );
  }
}
