import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/recurring_expense.dart';

void main() {
  group('RecurringExpense Model', () {
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    test('toMap converts DateTime to Timestamp', () {
      final expense = RecurringExpense(
        id: '123',
        title: 'Netflix',
        amount: 15.0,
        category: 'Entertainment',
        accountId: 'bank_id',
        frequency: 'monthly',
        startDate: now,
        nextOccurrence: now,
        endDate: null,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = expense.toMap();

      expect(map['id'], '123');
      expect(map['startDate'], isA<Timestamp>());
      expect((map['startDate'] as Timestamp).toDate(), now);
      expect(map['endDate'], isNull);
    });

    test('fromMap parses Firestore Timestamp', () {
      final map = {
        'id': '123',
        'title': 'Gym',
        'amount': 40.0,
        'category': 'Health',
        'accountId': 'bank_id',
        'frequency': 'monthly',
        'startDate': Timestamp.fromDate(now),
        'nextOccurrence': Timestamp.fromDate(now),
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final expense = RecurringExpense.fromMap(map, documentId: 'doc_456');

      expect(expense.id, 'doc_456');
      expect(expense.title, 'Gym');
      expect(expense.startDate, now);
      expect(expense.endDate, isNull);
    });
  });
}
