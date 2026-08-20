import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
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

    test('Explicit account number is resolved directly', () {
      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Your A/C XX1234 has been credited with Rs.10,000.',
        bank: dummyBank,
      );

      expect(accountId, 'testbank_1234');
    });

    test('Account missing + previous context uses previous account', () {
      // Message 1: contains account
      resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX1234 credited',
        bank: dummyBank,
      );

      // Message 2: missing account
      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Available balance Rs.9,500',
        bank: dummyBank,
      );

      expect(accountId, 'testbank_1234');
    });

    test('Multiple accounts in same thread returns null for missing account', () {
      resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX1234',
        bank: dummyBank,
      );
      resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX5678',
        bank: dummyBank,
      );

      // Missing account
      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Available balance Rs.20,000',
        bank: dummyBank,
      );

      // Ambiguous, so it must return null
      expect(accountId, isNull);
    });

    test('No context returns null', () {
      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'Available balance Rs.20,000',
        bank: dummyBank,
      );

      expect(accountId, isNull);
    });

    test('Separate threads respect thread isolation', () {
      // Thread A gets 1234
      resolver.resolveAccountId(
        sender: 'THREAD_A',
        messageText: 'A/C XX1234',
        bank: dummyBank,
      );

      // Thread B gets 5678
      resolver.resolveAccountId(
        sender: 'THREAD_B',
        messageText: 'A/C XX5678',
        bank: dummyBank,
      );

      // Thread A balance without account should resolve to 1234
      final accountIdA = resolver.resolveAccountId(
        sender: 'THREAD_A',
        messageText: 'Balance Rs.100',
        bank: dummyBank,
      );

      // Thread B balance without account should resolve to 5678
      final accountIdB = resolver.resolveAccountId(
        sender: 'THREAD_B',
        messageText: 'Balance Rs.200',
        bank: dummyBank,
      );

      expect(accountIdA, 'testbank_1234');
      expect(accountIdB, 'testbank_5678');
    });

    test('Explicit override ignores history', () {
      // Previous context is 1234
      resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX1234',
        bank: dummyBank,
      );

      // Current message explicitly says 5678
      final accountId = resolver.resolveAccountId(
        sender: 'TESTBANK',
        messageText: 'A/C XX5678',
        bank: dummyBank,
      );

      expect(accountId, 'testbank_5678');
    });
  });
}
