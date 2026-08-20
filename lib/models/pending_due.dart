import 'package:cloud_firestore/cloud_firestore.dart';

class PendingDue {
  final String id;
  final double amount;
  final DateTime dueDate;
  final String? accountId;
  final String? bankId;
  final String? description;
  final String? reference;
  final DateTime detectedAt;
  final String source;

  PendingDue({
    required this.id,
    required this.amount,
    required this.dueDate,
    this.accountId,
    this.bankId,
    this.description,
    this.reference,
    required this.detectedAt,
    this.source = 'sms',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'accountId': accountId,
      'bankId': bankId,
      'description': description,
      'reference': reference,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'source': source,
    };
  }

  factory PendingDue.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    return PendingDue(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      dueDate: parseDate(map['dueDate']),
      accountId: map['accountId'],
      bankId: map['bankId'],
      description: map['description'],
      reference: map['reference'],
      detectedAt: parseDate(map['detectedAt']),
      source: map['source'] ?? 'sms',
    );
  }
}
