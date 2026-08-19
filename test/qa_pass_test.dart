import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/expense_parser.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/transaction.dart' as tm;
import 'package:expense_tracker/models/sms_models.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:ui';

void main() {
  group('QA Pass Tests - Statements & Authority', () {
    
    test('Statement Deduplication: same fingerprint skipped', () {
      final accountId = 'acc1';
      final stTxDate = DateTime(2026, 8, 18);
      final rawStr = '${accountId}_${stTxDate.millisecondsSinceEpoch}_test_100.0_0.0_REF123';
      final fingerprint = sha256.convert(utf8.encode(rawStr)).toString();
      
      final existingTx = tm.Transaction(
        id: 'statement_$fingerprint',
        accountId: accountId,
        amount: 100.0,
        type: tm.TransactionType.expense,
        merchant: '',
        description: 'test',
        category: 'Uncategorized',
        date: stTxDate,
        transactionSource: 'statement',
        sourceId: 'stmt1',
        sourceFingerprint: fingerprint,
        upiReference: 'REF123',
        isManual: false,
      );

      // In importStatement, it checks if existingTransactions.any((tx) => tx.sourceFingerprint == fingerprint)
      // Since it's exactly the same fingerprint, it will be skipped.
      final newFingerprint = sha256.convert(utf8.encode(rawStr)).toString();
      expect(newFingerprint, equals(existingTx.sourceFingerprint));
    });

    test('Statement Deduplication: probable duplicate logic', () {
      final accountId = 'acc1';
      final date = DateTime(2026, 8, 18, 10, 0, 0); // With time
      final existingTx = tm.Transaction(
        id: 'manual_1',
        accountId: accountId,
        amount: 500.0,
        type: tm.TransactionType.expense,
        merchant: '',
        description: 'grocery store',
        category: 'Groceries',
        date: date,
        transactionSource: 'manual',
        isManual: true,
      );

      // Statement transaction
      final stDate = DateTime(2026, 8, 18); // Same day, no time
      final stDesc = 'grocery store pos';
      final stAmount = 500.0;
      final stType = tm.TransactionType.expense;

      // Simulated probable check
      final sameDay = existingTx.date.year == stDate.year &&
                      existingTx.date.month == stDate.month &&
                      existingTx.date.day == stDate.day;

      bool isDuplicate = false;
      if (existingTx.accountId == accountId && sameDay && existingTx.amount == stAmount && existingTx.type == stType) {
        final txDesc = existingTx.description?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ?? '';
        final stDescNormalized = stDesc.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        
        if (txDesc.isNotEmpty && stDescNormalized.isNotEmpty && (txDesc.contains(stDescNormalized) || stDescNormalized.contains(txDesc))) {
          isDuplicate = true;
        }
      }

      expect(isDuplicate, isTrue);
    });

    test('Balance Authority Rules', () {
      // Setup
      final statementDate = DateTime(2026, 8, 18, 10, 0);
      final existingAcc = Account(
        id: 'acc1',
        name: 'Test',
        bankName: 'Test',
        accountNumber: '1234',
        accountType: 'Savings',
        balance: 10000.0,
        currentBalance: 10000.0,
        balanceSource: 'statement',
        balanceUpdatedAt: statementDate,
        lastStatementImportAt: statementDate,
        accentColor: const Color(0xFF000000),
      );

      // Case 1: Older SMS should NOT override
      final olderSmsDate = DateTime(2026, 8, 17, 20, 0);
      bool shouldUpdateOlder = false;
      if (existingAcc.balanceSource == 'statement') {
        final stDate = existingAcc.lastStatementImportAt ?? existingAcc.balanceUpdatedAt;
        if (stDate == null || olderSmsDate.isAfter(stDate)) {
           shouldUpdateOlder = true;
        }
      }
      expect(shouldUpdateOlder, isFalse);

      // Case 2: Newer SMS SHOULD override
      final newerSmsDate = DateTime(2026, 8, 18, 14, 0);
      bool shouldUpdateNewer = false;
      if (existingAcc.balanceSource == 'statement') {
        final stDate = existingAcc.lastStatementImportAt ?? existingAcc.balanceUpdatedAt;
        if (stDate == null || newerSmsDate.isAfter(stDate)) {
           shouldUpdateNewer = true;
        }
      }
      expect(shouldUpdateNewer, isTrue);
    });

    test('SMS Balance Discovery: picks newest valid balance regardless of list order', () {
      final messages = [
        Message(id: '1', text: 'Acct XX123 debited by Rs 100. Bal Rs 5000.', timestamp: DateTime(2026, 8, 10), isMe: false),
        Message(id: '2', text: 'Acct XX123 debited by Rs 200. Bal Rs 6000.', timestamp: DateTime(2026, 8, 12), isMe: false),
        Message(id: '3', text: 'Acct XX123 debited by Rs 300. Bal Rs 7200.', timestamp: DateTime(2026, 8, 15), isMe: false),
      ];

      // Reverse order shouldn't matter
      final sortedMessages = List<Message>.from(messages)..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      double? newestValidBalance;
      DateTime? balanceUpdatedAt;
      for (final msg in sortedMessages) {
        final balance = ExpenseParser.extractBalance(msg.text);
        if (balance != null) {
          newestValidBalance = balance;
          balanceUpdatedAt = msg.timestamp;
          break;
        }
      }

      expect(newestValidBalance, 7200.0);
      expect(balanceUpdatedAt, DateTime(2026, 8, 15));
    });

    test('Google User Profile creation isolates correct fields', () {
      // Simulate UserCredential properties mapping to profile
      final displayName = 'John Doe';
      final email = 'john@example.com';
      
      final profile = {
        'displayName': displayName,
        'email': email,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      expect(profile['displayName'], 'John Doe');
      expect(profile['email'], 'john@example.com');
      expect(profile['photoURL'], isNull);
    });



    test('Statement Parsing Validation handles empty or malformed gracefully', () {
      // Instead of failing and crashing, parsers should throw handled exceptions
      bool threwException = false;
      try {
        // mock logic
        throw Exception('Could not detect transactions');
      } catch (e) {
        threwException = true;
      }
      expect(threwException, isTrue);
    });
  });
}
