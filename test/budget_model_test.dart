import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/budget.dart';

void main() {
  group('Budget Model Serialization', () {
    final now = DateTime(2023, 1, 1, 12, 0, 0);

    test('toMap converts DateTime to Firestore Timestamp', () {
      final budget = Budget(
        id: 'test_id',
        category: 'Food',
        amount: 5000.0,
        period: 'monthly',
        createdAt: now,
        updatedAt: now,
      );

      final map = budget.toMap();

      expect(map['id'], 'test_id');
      expect(map['category'], 'Food');
      expect(map['amount'], 5000.0);
      expect(map['period'], 'monthly');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
      expect(map['updatedAt'], isA<Timestamp>());
      expect((map['updatedAt'] as Timestamp).toDate(), now);
    });

    test('fromMap correctly parses Firestore Timestamp to DateTime', () {
      final map = {
        'id': 'test_id',
        'category': 'Shopping',
        'amount': 3000.0,
        'period': 'monthly',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final budget = Budget.fromMap(map, documentId: 'doc_123');

      expect(budget.id, 'doc_123'); // documentId overrides map['id'] if provided
      expect(budget.category, 'Shopping');
      expect(budget.amount, 3000.0);
      expect(budget.period, 'monthly');
      expect(budget.createdAt, now);
      expect(budget.updatedAt, now);
    });

    test('fromMap falls back to String parsing for backwards compatibility', () {
      final map = {
        'id': 'test_id',
        'category': 'Total',
        'amount': 20000,
        'period': 'weekly',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final budget = Budget.fromMap(map);

      expect(budget.id, 'test_id');
      expect(budget.category, 'Total');
      expect(budget.amount, 20000.0);
      expect(budget.period, 'weekly');
      expect(budget.createdAt, now);
      expect(budget.updatedAt, now);
    });

    test('fromMap handles missing fields gracefully', () {
      final map = <String, dynamic>{};

      final budget = Budget.fromMap(map);

      expect(budget.id, '');
      expect(budget.category, 'Total');
      expect(budget.amount, 0.0);
      expect(budget.period, 'monthly');
      // createdAt and updatedAt should default to roughly now
      expect(budget.createdAt.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
      expect(budget.updatedAt.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
    });
  });
}
