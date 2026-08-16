import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/transaction.dart' as model;

void main() {
  group('Transaction Model Serialization', () {
    test('toMap converts DateTime to Firestore Timestamp', () {
      final date = DateTime(2023, 10, 15, 12, 30);
      final transaction = model.Transaction(
        id: 'txn1',
        amount: 154.90,
        type: model.TransactionType.expense,
        merchant: 'Google Pay',
        category: 'Recharge',
        date: date,
        createdAt: date,
      );

      final map = transaction.toMap();

      expect(map['id'], 'txn1');
      expect(map['amount'], 154.90);
      expect(map['type'], 'expense');
      expect(map['merchant'], 'Google Pay');
      expect(map['category'], 'Recharge');
      
      expect(map['date'], isA<Timestamp>());
      expect((map['date'] as Timestamp).toDate(), date);
      
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), date);
    });

    test('fromMap correctly parses Firestore Timestamp to DateTime', () {
      final date = DateTime(2023, 10, 15, 12, 30);
      final map = {
        'id': 'txn1',
        'amount': 154.90,
        'type': 'expense',
        'merchant': 'Google Pay',
        'category': 'Recharge',
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(date),
      };

      final transaction = model.Transaction.fromMap(map);

      expect(transaction.id, 'txn1');
      expect(transaction.amount, 154.90);
      expect(transaction.type, model.TransactionType.expense);
      expect(transaction.merchant, 'Google Pay');
      expect(transaction.category, 'Recharge');
      expect(transaction.date, date);
      expect(transaction.createdAt, date);
    });

    test('fromMap falls back to String parsing for backwards compatibility', () {
      final dateStr = '2023-10-15T12:30:00.000';
      final map = {
        'id': 'txn2',
        'amount': 200.0,
        'type': 'income',
        'merchant': 'Salary',
        'category': 'Income',
        'date': dateStr,
      };

      final transaction = model.Transaction.fromMap(map);

      expect(transaction.id, 'txn2');
      expect(transaction.date.toIso8601String(), dateStr);
    });
  });
}
