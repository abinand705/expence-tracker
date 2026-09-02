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
      expect(transaction.customTitle, isNull);
    });

    test('toMap and fromMap correctly serialize and deserialize customTitle', () {
      final date = DateTime(2026, 9, 2);
      final transaction = model.Transaction(
        id: 'txn3',
        amount: 250.0,
        type: model.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: date,
        customTitle: 'Amazon',
      );

      final map = transaction.toMap();
      expect(map['customTitle'], 'Amazon');

      final fromMapTx = model.Transaction.fromMap(map);
      expect(fromMapTx.customTitle, 'Amazon');
      expect(fromMapTx.displayTitle, 'Amazon');
    });

    test('displayTitle priority: customTitle > merchant > description > Unknown Merchant', () {
      final date = DateTime.now();

      // 1. New transaction: customTitle = null -> displays parsed merchant
      final tx1 = model.Transaction(
        id: 't1',
        amount: 100,
        type: model.TransactionType.expense,
        merchant: 'Swiggy',
        category: 'Food',
        date: date,
      );
      expect(tx1.displayTitle, 'Swiggy');

      // 2. Unknown merchant: customTitle = null, merchant = Unknown Merchant -> displays Unknown Merchant
      final tx2 = model.Transaction(
        id: 't2',
        amount: 100,
        type: model.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: date,
      );
      expect(tx2.displayTitle, 'Unknown Merchant');

      // 3. Custom title: customTitle = "Amazon" -> displays Amazon
      final tx3 = model.Transaction(
        id: 't3',
        amount: 100,
        type: model.TransactionType.expense,
        merchant: 'Unknown Merchant',
        category: 'Others',
        date: date,
        customTitle: 'Amazon',
      );
      expect(tx3.displayTitle, 'Amazon');

      // 4. Custom title with whitespace: customTitle = "   " -> falls back to merchant
      final tx4 = model.Transaction(
        id: 't4',
        amount: 100,
        type: model.TransactionType.expense,
        merchant: 'Swiggy',
        category: 'Food',
        date: date,
        customTitle: '   ',
      );
      expect(tx4.displayTitle, 'Swiggy');

      // 5. Description fallback when merchant is Unknown Merchant
      final tx5 = model.Transaction(
        id: 't5',
        amount: 100,
        type: model.TransactionType.expense,
        merchant: 'Unknown Merchant',
        description: 'UPI payment to vendor',
        category: 'Others',
        date: date,
      );
      expect(tx5.displayTitle, 'UPI payment to vendor');

      // 6. Credit / Income transaction rename
      final tx6 = model.Transaction(
        id: 't6',
        amount: 5000,
        type: model.TransactionType.income,
        merchant: 'Unknown Merchant',
        category: 'Income',
        date: date,
        customTitle: 'Salary',
      );
      expect(tx6.displayTitle, 'Salary');
    });
  });
}
