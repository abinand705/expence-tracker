import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/expense_parser.dart';
import 'package:expense_tracker/models/transaction.dart';

void main() {
  group('ExpenseParser', () {
    test('extracts amount and merchant correctly for expense', () {
      final result = ExpenseParser.parse('Spent Rs. 500 at Amazon');
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.merchant, 'Amazon');
      expect(result.type, TransactionType.expense);
    });

    test('extracts amount correctly for income', () {
      final result = ExpenseParser.parse('Rs. 5,000 credited to your account');
      expect(result, isNotNull);
      expect(result!.amount, 5000.0);
      expect(result.type, TransactionType.income);
    });

    test('ignores non-financial SMS', () {
      final result = ExpenseParser.parse('Your OTP is 123456');
      expect(result, isNull);
    });

    test('ignores false positive received messages', () {
      final result = ExpenseParser.parse('We have received your request.');
      expect(result, isNull);
    });

    test('prioritizes debit when ambiguous', () {
      final result = ExpenseParser.parse('Rs. 500 debited from your account and credited to Alice');
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, TransactionType.expense);
    });

    test('extracts account number and normalizes to last 4 digits', () {
      expect(ExpenseParser.extractAccountNumber('Acct XXXX1234 debited'), '1234');
      expect(ExpenseParser.extractAccountNumber('Acct 80544 debited'), '0544');
      expect(ExpenseParser.extractAccountNumber('Acct 12344 debited'), '2344');
      expect(ExpenseParser.extractAccountNumber('ending in 1234'), '1234');
      expect(ExpenseParser.extractAccountNumber('Acct 001234'), '1234');
    });

    test('guesses category', () {
      final cat = ExpenseParser.guessCategory('Zomato');
      expect(cat, 'Food');
      
      final cat2 = ExpenseParser.guessCategory('Amazon');
      expect(cat2, 'Shopping');
    });
  });
}
