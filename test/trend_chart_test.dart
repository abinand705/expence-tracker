import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/analytics_service.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/models/trend_data.dart';

void main() {
  group('AnalyticsService.calculateTrendData', () {
    final analytics = AnalyticsService();
    // Use a fixed reference date for tests: August 15, 2026, 12:00 PM
    final referenceDate = DateTime(2026, 8, 15, 12, 0);

    final testTransactions = [
      // Today (August 15, 2026) - 10 AM -> belongs to 8 AM bucket
      Transaction(id: '1', amount: 100, type: TransactionType.expense, merchant: 'Coffee', category: 'Food', date: DateTime(2026, 8, 15, 10, 0)),
      // Today (August 15, 2026) - 3 PM -> belongs to 12 PM bucket
      Transaction(id: '2', amount: 200, type: TransactionType.expense, merchant: 'Lunch', category: 'Food', date: DateTime(2026, 8, 15, 15, 0)),
      // Yesterday (August 14, 2026)
      Transaction(id: '3', amount: 150, type: TransactionType.expense, merchant: 'Dinner', category: 'Food', date: DateTime(2026, 8, 14, 20, 0)),
      // August 10, 2026 (Monday of the same week)
      Transaction(id: '4', amount: 500, type: TransactionType.expense, merchant: 'Groceries', category: 'Shopping', date: DateTime(2026, 8, 10, 10, 0)),
      // July 15, 2026 (Last month)
      Transaction(id: '5', amount: 1000, type: TransactionType.expense, merchant: 'Rent', category: 'Others', date: DateTime(2026, 7, 15, 10, 0)),
      // January 5, 2026 (Same year)
      Transaction(id: '6', amount: 2000, type: TransactionType.expense, merchant: 'TV', category: 'Shopping', date: DateTime(2026, 1, 5, 10, 0)),
      // Today, but INCOME -> should be excluded
      Transaction(id: '7', amount: 5000, type: TransactionType.income, merchant: 'Salary', category: 'Income', date: DateTime(2026, 8, 15, 11, 0)),
    ];

    test('Day trend calculates correctly', () {
      final result = analytics.calculateTrendData(testTransactions, TrendPeriod.day, referenceDate, null);
      
      expect(result.length, 6);
      expect(result[0].label, '12 AM');
      expect(result[1].label, '4 AM');
      expect(result[2].label, '8 AM'); // 10 AM transaction -> bucket 2 (10 ~/ 4 = 2)
      expect(result[2].amount, 100.0);
      expect(result[3].label, '12 PM'); // 3 PM transaction -> bucket 3 (15 ~/ 4 = 3)
      expect(result[3].amount, 200.0);
      expect(result[4].label, '4 PM');
      expect(result[4].amount, 0.0);
    });

    test('Week trend calculates correctly', () {
      // Aug 15, 2026 is a Saturday (weekday 6)
      final result = analytics.calculateTrendData(testTransactions, TrendPeriod.week, referenceDate, null);
      
      expect(result.length, 7);
      expect(result[0].label, 'Mon');
      expect(result[0].amount, 500.0); // Aug 10
      expect(result[4].label, 'Fri');
      expect(result[4].amount, 150.0); // Aug 14
      expect(result[5].label, 'Sat');
      expect(result[5].amount, 300.0); // Aug 15 (100 + 200)
      expect(result[6].label, 'Sun');
      expect(result[6].amount, 0.0);
    });

    test('Month trend calculates correctly', () {
      final result = analytics.calculateTrendData(testTransactions, TrendPeriod.month, referenceDate, null);
      
      expect(result.length, 5);
      expect(result[0].label, 'W1');
      expect(result[1].label, 'W2');
      expect(result[1].amount, 650.0); // Aug 10 and 14 fall in days 8-14 (W2)
      expect(result[2].label, 'W3');
      expect(result[2].amount, 300.0); // Aug 15 fall in days 15-21 (W3)
    });

    test('Year trend calculates correctly', () {
      final result = analytics.calculateTrendData(testTransactions, TrendPeriod.year, referenceDate, null);
      
      expect(result.length, 12);
      expect(result[0].label, 'Jan');
      expect(result[0].amount, 2000.0);
      expect(result[6].label, 'Jul');
      // Wait, 7th month is July. Index 6.
      expect(result[6].amount, 1000.0);
      expect(result[7].label, 'Aug');
      expect(result[7].amount, 950.0); // 100 + 200 + 150 + 500 = 950
    });

    test('Custom trend calculates correctly (Short Range)', () {
      final start = DateTime(2026, 8, 14);
      final end = DateTime(2026, 8, 15);
      final range = DateTimeRange(start: start, end: end);
      
      final result = analytics.calculateTrendData(testTransactions, TrendPeriod.custom, referenceDate, range);
      
      expect(result.length, 2);
      expect(result[0].label, '14/8');
      expect(result[0].amount, 150.0);
      expect(result[1].label, '15/8');
      expect(result[1].amount, 300.0);
    });
    
    test('Income is excluded', () {
      final result = analytics.calculateTrendData(testTransactions, TrendPeriod.day, referenceDate, null);
      final total = result.fold(0.0, (sum, t) => sum + t.amount);
      // Only 300 for today's expenses, the 5000 income should NOT be there.
      expect(total, 300.0);
    });
  });
}
