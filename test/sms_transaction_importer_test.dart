import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;

class MockTransactionRepository implements TransactionRepository {
  final Map<String, model_tx.Transaction> transactions = {};

  @override
  Future<model_tx.Transaction?> getTransactionById(String id) async {
    return transactions[id];
  }

  @override
  Future<String> addTransaction(model_tx.Transaction transaction) async {
    transactions[transaction.id] = transaction;
    return transaction.id;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SmsTransactionImporter', () {
    late MockTransactionRepository repo;
    late SmsTransactionImporter importer;

    setUp(() {
      repo = MockTransactionRepository();
      importer = SmsTransactionImporter(transactionRepo: repo);
    });

    test('imports valid expense sms', () async {
      final msg = Message(
        id: '1',
        text: 'Rs. 500 debited from a/c 1234 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'BankA');
      expect(result, SmsImportResult.imported);
      expect(repo.transactions.length, 1);
      
      final savedTx = repo.transactions.values.first;
      expect(savedTx.amount, 500.0);
      expect(savedTx.type, model_tx.TransactionType.expense);
    });

    test('imports valid income sms', () async {
      final msg = Message(
        id: '2',
        text: 'Rs. 5000 credited to a/c 1234 on 01-01-2026',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'BankA');
      expect(result, SmsImportResult.imported);
      expect(repo.transactions.length, 1);
      
      final savedTx = repo.transactions.values.first;
      expect(savedTx.amount, 5000.0);
      expect(savedTx.type, model_tx.TransactionType.income);
    });

    test('prevents duplicate transactions with exactly same data', () async {
      final msg = Message(
        id: '3',
        text: 'Rs. 500 debited',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );

      final result1 = await importer.importMessage(msg, 'BankA');
      expect(result1, SmsImportResult.imported);

      final result2 = await importer.importMessage(msg, 'BankA');
      expect(result2, SmsImportResult.duplicate);

      expect(repo.transactions.length, 1);
    });

    test('allows same amount but different timestamps', () async {
      final msg1 = Message(
        id: '4',
        text: 'Rs. 500 debited',
        timestamp: DateTime(2026, 1, 1, 10, 0), // 10:00 AM
        isMe: false,
      );
      
      final msg2 = Message(
        id: '5',
        text: 'Rs. 500 debited',
        timestamp: DateTime(2026, 1, 1, 14, 0), // 2:00 PM
        isMe: false,
      );

      final result1 = await importer.importMessage(msg1, 'BankA');
      expect(result1, SmsImportResult.imported);

      final result2 = await importer.importMessage(msg2, 'BankA');
      expect(result2, SmsImportResult.imported);

      expect(repo.transactions.length, 2);
    });

    test('skips non-financial SMS', () async {
      final msg = Message(
        id: '6',
        text: 'Your OTP is 123456',
        timestamp: DateTime(2026, 1, 1),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'BankA');
      expect(result, SmsImportResult.skipped);
      expect(repo.transactions.length, 0);
    });

    test('importAllBankMessages skips non-bank senders', () async {
      final conv = Conversation(
        id: 'c1',
        senderName: 'Alice',
        senderNumber: '123',
        avatarColor: const Color(0xFF000000),
        isBankSender: false,
        messages: [
          Message(
            id: 'm1',
            text: 'Rs. 500 debited',
            timestamp: DateTime.now(),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      expect(summary.scanned, 0);
      expect(summary.imported, 0);
      expect(repo.transactions.length, 0);
    });
  });
}
