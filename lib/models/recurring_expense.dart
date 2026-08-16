import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringExpense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String accountId;
  final String frequency; // daily, weekly, monthly, yearly
  final DateTime startDate;
  final DateTime nextOccurrence;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecurringExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.frequency,
    required this.startDate,
    required this.nextOccurrence,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'accountId': accountId,
      'frequency': frequency,
      'startDate': Timestamp.fromDate(startDate),
      'nextOccurrence': Timestamp.fromDate(nextOccurrence),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RecurringExpense.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }
    
    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return RecurringExpense(
      id: documentId ?? map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'General',
      accountId: map['accountId'] ?? '',
      frequency: map['frequency'] ?? 'monthly',
      startDate: parseDate(map['startDate']),
      nextOccurrence: parseDate(map['nextOccurrence']),
      endDate: parseOptionalDate(map['endDate']),
      isActive: map['isActive'] ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
