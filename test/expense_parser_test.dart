import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/expense_parser.dart';

void main() {
  group('ExpenseParser', () {
    test('extracts amount and merchant correctly', () {
      final result = ExpenseParser.parse('Spent Rs. 500 at Amazon');
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.merchant, 'Amazon');
    });

    test('extracts account number', () {
      final ac = ExpenseParser.extractAccountNumber('Acct XXXX1234 debited');
      expect(ac, '1234');
    });

    test('guesses category', () {
      final cat = ExpenseParser.guessCategory('Zomato');
      expect(cat, 'Food');
      
      final cat2 = ExpenseParser.guessCategory('Amazon');
      expect(cat2, 'Shopping');
    });
  });
}
