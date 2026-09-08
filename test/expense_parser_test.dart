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

    test('extracts account number with variable lengths (3, 4, 5+ digits)', () {
      expect(ExpenseParser.extractAccountNumber('Acct XXXX1234 debited'), '1234');
      expect(ExpenseParser.extractAccountNumber('Your A/C XX123 has been credited'), '123');
      expect(ExpenseParser.extractAccountNumber('Acct ending 123'), '123');
      expect(ExpenseParser.extractAccountNumber('account ending in 123'), '123');
      expect(ExpenseParser.extractAccountNumber('account ending with 123'), '123');
      expect(ExpenseParser.extractAccountNumber('a/c ...123 debited'), '123');
      expect(ExpenseParser.extractAccountNumber('account ...123 credited'), '123');
      expect(ExpenseParser.extractAccountNumber('acct ...123'), '123');
      expect(ExpenseParser.extractAccountNumber('AC XXXXX123 debited'), '123');
      expect(ExpenseParser.extractAccountNumber('XXXX123 debited'), '123');
      expect(ExpenseParser.extractAccountNumber('XX123 debited'), '123');
      expect(ExpenseParser.extractAccountNumber('XX XX 123 debited'), '123');
      expect(ExpenseParser.extractAccountNumber('Acct XXXXX12345 debited'), '12345');
      expect(ExpenseParser.extractAccountNumber('Acct XXXX99123 debited'), '99123');
      expect(ExpenseParser.extractAccountNumber('from your 0711-BANK OF BARODA'), '0711');
      expect(ExpenseParser.extractAccountNumber('from your 123-BANK OF BARODA'), '123');
    });

    test('guesses category', () {
      final cat = ExpenseParser.guessCategory('Zomato');
      expect(cat, 'Food');
      
      final cat2 = ExpenseParser.guessCategory('Amazon');
      expect(cat2, 'Shopping');
    });
    
    test('parsePendingDue extracts amount, date, and detects future debits', () {
      final now = DateTime(2026, 8, 20);
      final result = ExpenseParser.parsePendingDue('₹2,499 will be debited on 25 Aug', now);
      expect(result, isNotNull);
      expect(result!.amount, 2499.0);
      expect(result.dueDate.year, 2026);
      expect(result.dueDate.month, 8);
      expect(result.dueDate.day, 25);
    });

    test('parsePendingDue parses specific SIP pattern', () {
      final now = DateTime(2026, 8, 20);
      final msg = "Rs 100.00 will be debited on 21 Aug 2026 from your 0711-BANK OF BARODA for upcoming SIP #xxxxxxxx in HDFC Small Cap Fund Growth Dir. Ensure you have sufficient balance in your bank account.";
      final result = ExpenseParser.parsePendingDue(msg, now);
      expect(result, isNotNull);
      expect(result!.amount, 100.0);
      expect(result.dueDate.year, 2026);
      expect(result.dueDate.month, 8);
      expect(result.dueDate.day, 21);
      expect(result.accountSuffix, '0711');
      expect(result.bankName, 'BANK OF BARODA');
      expect(result.description, 'Upcoming SIP - HDFC Small Cap Fund Growth Dir');
      expect(result.source, 'sms');
    });

    test('isStrongFinancialMessage correctly identifies financial messages', () {
      final msg1 = "Rs 100.00 will be debited on 21 Aug 2026 from your 0711-BANK OF BARODA for upcoming SIP #xxxxxxxx in HDFC Small Cap Fund Growth Dir.";
      expect(ExpenseParser.isStrongFinancialMessage(msg1), isTrue);

      final msg2 = "Your food will be delivered on 25 Aug 2026.";
      expect(ExpenseParser.isStrongFinancialMessage(msg2), isFalse);
    });
    
    test('parsePendingDue ignores past/completed debits', () {
      final now = DateTime(2026, 8, 20);
      final result = ExpenseParser.parsePendingDue('₹2,499 has been debited on 25 Aug', now);
      expect(result, isNull);
    });

    group('Merchant Extraction Regressions', () {
      test('Paid Rs 250 to AMAZON extracts AMAZON', () {
        final result = ExpenseParser.parse('Paid Rs 250 to AMAZON');
        expect(result, isNotNull);
        expect(result!.merchant, 'AMAZON');
      });

      test('Rs 250 debited for AMAZON extracts AMAZON', () {
        final result = ExpenseParser.parse('Rs 250 debited for AMAZON on 12-05');
        expect(result, isNotNull);
        expect(result!.merchant, 'AMAZON');
      });

      test('UPI/AMAZON/123456 extracts AMAZON', () {
        final result = ExpenseParser.parse('Rs 250 debited via UPI/AMAZON/123456 on 01-01-2026');
        expect(result, isNotNull);
        expect(result!.merchant, contains('AMAZON'));
      });

      test('POS AMAZON Rs 250 extracts AMAZON', () {
        final result = ExpenseParser.parse('POS AMAZON Rs 250 debited from a/c 1234');
        expect(result, isNotNull);
        expect(result!.merchant, 'AMAZON');
      });

      test('Transferred Rs 500 to RAHUL extracts RAHUL', () {
        final result = ExpenseParser.parse('Transferred Rs 500 to RAHUL via UPI');
        expect(result, isNotNull);
        expect(result!.merchant, 'RAHUL');
      });

      test('Paid to merchant XYZ extracts XYZ', () {
        final result = ExpenseParser.parse('Paid to merchant XYZ Rs 150 from account 1234');
        expect(result, isNotNull);
        expect(result!.merchant, 'XYZ');
      });

      test('Rs 250 debited from A/c XXXXX544 does not use account/bank as merchant', () {
        final result = ExpenseParser.parse('Rs 250 debited from A/c XXXXX544 on 01-01-2026');
        expect(result, isNotNull);
        expect(result!.merchant, isNull);
      });

      test('After debit of Rs 25, your A/c is debited does not use raw sentence as merchant', () {
        final result = ExpenseParser.parse('After debit of Rs 25, your A/c is debited');
        expect(result, isNotNull);
        expect(result!.merchant, isNull);
      });
    });

    group('Canara Bank & Indian Bank Balance & Date Tests', () {
      test('extracts balance from Avl Bal Rs:14200.00', () {
        const text = 'Canara Bank: Dear UPI user A/C XX1234 debited by 150.0 on date 08Sep26 trf to SWIGGY. Refno 123456789. If not you cancel in app. Avl Bal Rs:14200.00';
        final parsed = ExpenseParser.parse(text);
        expect(parsed, isNotNull);
        expect(parsed!.amount, 150.0);
        expect(parsed.availableBalance, 14200.0);
        expect(parsed.accountNumber, '1234');
        expect(parsed.bankName, 'Canara Bank');
      });

      test('extracts balance from Avl. Bal. : Rs. 12,345.50', () {
        const text = 'Your A/C XXXXX1234 is debited by Rs.500.00 on 08-09-2026 14:30:15. Available Balance:Rs.12345.50 - Canara Bank';
        final parsed = ExpenseParser.parse(text);
        expect(parsed, isNotNull);
        expect(parsed!.amount, 500.0);
        expect(parsed.availableBalance, 12345.50);
        expect(parsed.bankName, 'Canara Bank');
      });

      test('extracts balance from as on pattern', () {
        const text = 'Canara Bank: Avl. Bal. for A/c ...1234 as on 08/09/2026 is Rs. 18,450.00';
        final bal = ExpenseParser.extractBalance(text);
        expect(bal, 18450.0);
        final ts = ExpenseParser.extractTransactionTimestamp(text);
        expect(ts, isNotNull);
        expect(ts!.year, 2026);
        expect(ts.month, 9);
        expect(ts.day, 8);
      });

      test('extracts named month date without time', () {
        const text = 'Dear Customer, your a/c 1234 credited with Rs 5000 on 08-Sep-2026. Avl Bal Rs: 25000.00';
        final ts = ExpenseParser.extractTransactionTimestamp(text);
        expect(ts, isNotNull);
        expect(ts!.year, 2026);
        expect(ts.month, 9);
        expect(ts.day, 8);
      });

      test('extracts negative balance with minus signs', () {
        expect(ExpenseParser.extractBalance('Avl Bal Rs: -500.00'), -500.0);
        expect(ExpenseParser.extractBalance('Avl Bal: -Rs 500.00'), -500.0);
        expect(ExpenseParser.extractBalance('Bal: -12,345.50'), -12345.50);
        expect(ExpenseParser.extractBalance('Avl Bal: -₹ 750.25'), -750.25);
      });

      test('extracts negative balance with Dr/debit suffix', () {
        expect(ExpenseParser.extractBalance('Avl Bal Rs: 500.00 Dr'), -500.0);
        expect(ExpenseParser.extractBalance('Avl Bal: Rs 500.00 (Dr)'), -500.0);
        expect(ExpenseParser.extractBalance('Avl Bal: Rs 500.00 Dr.'), -500.0);
        expect(ExpenseParser.extractBalance('Available Balance: Rs. 1,200.00 debit'), -1200.0);
      });
    });
  });
}
