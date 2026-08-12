import 'transaction.dart';
import 'sms_message.dart';

class DummyData {
  static List<Transaction> getTransactions() {
    return [
      Transaction(
        id: '1',
        merchant: 'Uber Eats',
        amount: 24.50,
        date: DateTime.now().subtract(const Duration(hours: 2)),
        category: 'Food',
        type: TransactionType.expense,
      ),
      Transaction(
        id: '2',
        merchant: 'Amazon',
        amount: 120.00,
        date: DateTime.now().subtract(const Duration(hours: 5)),
        category: 'Shopping',
        type: TransactionType.expense,
      ),
      Transaction(
        id: '3',
        merchant: 'Salary',
        amount: 3200.00,
        date: DateTime.now().subtract(const Duration(days: 2)),
        category: 'Income',
        type: TransactionType.income,
      ),
      Transaction(
        id: '4',
        merchant: 'Electricity Bill',
        amount: 85.00,
        date: DateTime.now().subtract(const Duration(days: 3)),
        category: 'Bills',
        type: TransactionType.expense,
      ),
    ];
  }

  static List<SmsMessage> getSmsMessages() {
    return [
      SmsMessage(
        id: 's1',
        sender: 'Bank',
        snippet: 'Your account XXXXXX was debited \$14.99 at Netflix.',
        date: DateTime.now().subtract(const Duration(minutes: 15)),
        extractedAmount: 14.99,
      ),
      SmsMessage(
        id: 's2',
        sender: 'CreditCard',
        snippet: 'Transaction alert: \$45.00 spent at Target.',
        date: DateTime.now().subtract(const Duration(hours: 1)),
        extractedAmount: 45.00,
      ),
      SmsMessage(
        id: 's3',
        sender: 'Bank',
        snippet: 'Payment of \$100.00 to John Doe successful.',
        date: DateTime.now().subtract(const Duration(days: 1)),
        extractedAmount: 100.00,
      ),
    ];
  }
}
