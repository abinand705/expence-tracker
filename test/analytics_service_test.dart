import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/analytics_service.dart';
import 'package:expense_tracker/models/transaction.dart';

void main() {
  group('AnalyticsService', () {
    final analytics = AnalyticsService();
    final now = DateTime.now();

    final testTransactions = [
      Transaction(
        id: '1',
        amount: 100,
        type: TransactionType.expense,
        merchant: 'Zomato',
        category: 'Food',
        date: now,
      ),
      Transaction(
        id: '2',
        amount: 50,
        type: TransactionType.expense,
        merchant: 'Uber',
        category: 'Others',
        date: now.subtract(const Duration(days: 1)),
      ),
      Transaction(
        id: '3',
        amount: 200,
        type: TransactionType.income,
        merchant: 'Salary',
        category: 'Income',
        date: now,
      ),
    ];

    test('calculates total expenses correctly', () {
      final total = analytics.calculateTotalExpenses(testTransactions, month: now.month, year: now.year);
      // It should ignore income
      expect(total, 150.0);
    });

    test('calculates category totals correctly', () {
      final totals = analytics.calculateCategoryTotals(testTransactions, month: now.month, year: now.year);
      expect(totals['Food'], 100.0);
      expect(totals['Others'], 50.0);
      expect(totals['Income'], isNull); // Income should be ignored
    });

    test('calculates total income correctly', () {
      final total = analytics.calculateTotalIncome(testTransactions, month: now.month, year: now.year);
      expect(total, 200.0);
    });
  });
}
