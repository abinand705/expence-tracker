import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/services/sms_account_resolver.dart';
import 'package:expense_tracker/services/bank_detection_service.dart';

void main() {
  group('SmsAccountResolver Tests', () {
    late SmsAccountResolver resolver;
    final dummyBank = BankDefinition(
      id: 'testbank',
      displayName: 'Test Bank',
      senderPatterns: ['test'],
      contentPatterns: ['test'],
      accentColor: Colors.blue,
    );

    setUp(() {
      resolver = SmsAccountResolver();
    });

    test('Explicit account number is resolved to matching account ID', () {
      final accounts = [
        Account(id: 'test_acc_1', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX1234', accountType: 'Savings', accentColor: Colors.blue)
      ];

      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Your A/C XX1234 has been credited with Rs.10,000.',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      expect(accountId, 'test_acc_1');
    });

    test('Unmatched account returns null (never constructs fake account ID)', () {
      final accounts = [
        Account(id: 'test_acc_1', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX9999', accountType: 'Savings', accentColor: Colors.blue)
      ];

      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Your A/C XX1234 has been credited with Rs.10,000.',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      expect(accountId, isNull);
    });

    test('Account missing + previous context uses previous account', () {
      final accounts = [
        Account(id: 'test_acc_1', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX1234', accountType: 'Savings', accentColor: Colors.blue)
      ];

      // Message 1: contains account
      resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX1234 credited',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      // Message 2: missing account
      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Available balance Rs.9,500',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      expect(accountId, 'test_acc_1');
    });

    test('Multiple accounts in same thread returns null for missing account', () {
      final accounts = [
        Account(id: 'test_acc_1', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX1234', accountType: 'Savings', accentColor: Colors.blue),
        Account(id: 'test_acc_2', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX5678', accountType: 'Savings', accentColor: Colors.blue)
      ];

      resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX1234',
        bank: dummyBank,
        existingAccounts: accounts,
      );
      resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX5678',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      // Missing account
      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Available balance Rs.20,000',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      // Ambiguous, so it must return null
      expect(accountId, isNull);
    });

    test('No context returns null', () {
      final accounts = [
        Account(id: 'test_acc_1', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX1234', accountType: 'Savings', accentColor: Colors.blue)
      ];

      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Available balance Rs.20,000',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      expect(accountId, isNull);
    });

    test('Separate threads respect thread isolation', () {
      final accounts = [
        Account(id: 'test_acc_1', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX1234', accountType: 'Savings', accentColor: Colors.blue),
        Account(id: 'test_acc_2', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX5678', accountType: 'Savings', accentColor: Colors.blue)
      ];

      // Thread A gets 1234
      resolver.resolveAccountId(
        sender: 'THREAD_A',
        messageText: 'A/C XX1234',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      // Thread B gets 5678
      resolver.resolveAccountId(
        sender: 'THREAD_B',
        messageText: 'A/C XX5678',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      // Thread A balance without account should resolve to 1234
      final accountIdA = resolver.resolveAccountId(
        sender: 'THREAD_A',
        messageText: 'Balance Rs.100',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      // Thread B balance without account should resolve to 5678
      final accountIdB = resolver.resolveAccountId(
        sender: 'THREAD_B',
        messageText: 'Balance Rs.200',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      expect(accountIdA, 'test_acc_1');
      expect(accountIdB, 'test_acc_2');
    });

    test('Explicit override ignores history', () {
      final accounts = [
        Account(id: 'test_acc_1', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX1234', accountType: 'Savings', accentColor: Colors.blue),
        Account(id: 'test_acc_2', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX5678', accountType: 'Savings', accentColor: Colors.blue)
      ];

      // Previous context is 1234
      resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX1234',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      // Current message explicitly says 5678
      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX5678',
        bank: dummyBank,
        existingAccounts: accounts,
      );

      expect(accountId, 'test_acc_2');
    });

    test('3-digit extraction and resolution fallback', () {
      final accounts = [
        Account(id: 'test_123_uid', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXX123', accountType: 'Savings', accentColor: Colors.blue)
      ];

      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Your account ending 123 has been debited by Rs 500',
        bank: dummyBank,
        existingAccounts: accounts,
      );
      expect(accountId, 'test_123_uid');
    });

    test('5-digit extraction and resolution', () {
      final accounts = [
        Account(id: 'test_12345_uid', name: 'Test Bank', bankName: 'Test Bank', accountNumber: 'XXXXX12345', accountType: 'Savings', accentColor: Colors.blue)
      ];

      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Your A/C XXXXX12345 has been credited with Rs 1,000',
        bank: dummyBank,
        existingAccounts: accounts,
      );
      expect(accountId, 'test_12345_uid');
    });

    test('Bank + 3-digit suffix matches correct account when unambiguous', () {
      final bobBank = BankDefinition(
        id: 'bob',
        displayName: 'Bank of Baroda',
        senderPatterns: ['bobsms'],
        contentPatterns: ['bob'],
        accentColor: Colors.orange,
      );
      final sbiBank = BankDefinition(
        id: 'sbi',
        displayName: 'State Bank of India',
        senderPatterns: ['sbi'],
        contentPatterns: ['sbi'],
        accentColor: Colors.blue,
      );

      final accounts = [
        Account(id: 'bob_acc_1', name: 'BOB', bankName: 'Bank of Baroda', accountNumber: '1234567890123', accountType: 'Savings', accentColor: Colors.orange),
        Account(id: 'sbi_acc_1', name: 'SBI', bankName: 'State Bank of India', accountNumber: '9876543210123', accountType: 'Savings', accentColor: Colors.blue),
      ];

      // BOB message with 3-digit suffix
      final bobResolved = resolver.resolveAccountId(
        sender: 'BOBSMS',
        messageText: 'Rs 100 debited from account ending 123',
        bank: bobBank,
        existingAccounts: accounts,
      );
      expect(bobResolved, 'bob_acc_1');

      // SBI message with 3-digit suffix
      final sbiResolved = resolver.resolveAccountId(
        sender: 'SBISMS',
        messageText: 'Rs 200 credited to account ending 123',
        bank: sbiBank,
        existingAccounts: accounts,
      );
      expect(sbiResolved, 'sbi_acc_1');
    });

    test('Ambiguous 3-digit suffix returns null (does not guess)', () {
      final bobBank = BankDefinition(
        id: 'bob',
        displayName: 'Bank of Baroda',
        senderPatterns: ['bobsms'],
        contentPatterns: ['bob'],
        accentColor: Colors.orange,
      );

      final accounts = [
        Account(id: 'bob_acc_1', name: 'BOB 1', bankName: 'Bank of Baroda', accountNumber: '1111123', accountType: 'Savings', accentColor: Colors.orange),
        Account(id: 'bob_acc_2', name: 'BOB 2', bankName: 'Bank of Baroda', accountNumber: '2222123', accountType: 'Savings', accentColor: Colors.orange),
      ];

      final resolved = resolver.resolveAccountId(
        sender: 'BOBSMS',
        messageText: 'Rs 500 debited from account ending 123',
        bank: bobBank,
        existingAccounts: accounts,
      );

      expect(resolved, isNull);
    });

    test('Matching priority: Exact ID > Full Number > 5+ Suffix > 4 Suffix > 3 Suffix', () {
      final hdfcBank = BankDefinition(
        id: 'hdfc',
        displayName: 'HDFC Bank',
        senderPatterns: ['hdfc'],
        contentPatterns: ['hdfc'],
        accentColor: Colors.blue,
      );

      // Account 1 has exact full number 123456
      // Account 2 has 3456
      final accounts = [
        Account(id: 'hdfc_full', name: 'HDFC Full', bankName: 'HDFC Bank', accountNumber: '123456', accountType: 'Savings', accentColor: Colors.blue),
        Account(id: 'hdfc_partial', name: 'HDFC Part', bankName: 'HDFC Bank', accountNumber: '993456', accountType: 'Savings', accentColor: Colors.blue),
      ];

      // SMS with full number 123456 matches hdfc_full
      final fullMatch = resolver.resolveAccountId(
        sender: 'HDFCBK',
        messageText: 'Rs 500 debited from a/c 123456',
        bank: hdfcBank,
        existingAccounts: accounts,
      );
      expect(fullMatch, 'hdfc_full');

      // SMS with 3456 is ambiguous between the two (both end with 3456)
      final ambiguousMatch = resolver.resolveAccountId(
        sender: 'HDFCBK',
        messageText: 'Rs 500 debited from a/c 3456',
        bank: hdfcBank,
        existingAccounts: accounts,
      );
      expect(ambiguousMatch, isNull);
    });
  });
}
