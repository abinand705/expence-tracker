import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/account.dart';

void main() {
  group('Account Model Serialization', () {
    test('toMap converts DateTime to Firestore Timestamp', () {
      final date = DateTime(2026, 1, 1, 10, 0, 0);
      final account = Account(
        id: '123',
        name: 'Savings Account',
        bankName: 'Test Bank',
        accountNumber: '4321',
        accountType: 'Savings',
        balance: 1000.0,
        currency: 'INR',
        accentColor: Colors.blue,
        createdAt: date,
        updatedAt: date,
      );

      final map = account.toMap();

      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), date);
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('fromMap correctly parses Firestore Timestamp to DateTime', () {
      final date = DateTime(2026, 1, 1, 10, 0, 0);
      final map = {
        'id': '123',
        'name': 'Savings Account',
        'bankName': 'Test Bank',
        'accountNumber': '4321',
        'accountType': 'Savings',
        'balance': 1000.0,
        'currency': 'INR',
        'accentColor': Colors.blue.toARGB32(),
        'createdAt': Timestamp.fromDate(date),
        'updatedAt': Timestamp.fromDate(date),
      };

      final account = Account.fromMap(map);

      expect(account.createdAt, date);
      expect(account.updatedAt, date);
      expect(account.balance, 1000.0);
    });

    test('fromMap falls back to String parsing for backwards compatibility', () {
      final date = DateTime(2026, 1, 1, 10, 0, 0);
      final map = {
        'id': '123',
        'name': 'Savings Account',
        'bankName': 'Test Bank',
        'accountNumber': '4321',
        'accountType': 'Savings',
        'balance': 1000.0,
        'currency': 'INR',
        'accentColor': Colors.blue.toARGB32(),
        'createdAt': date.toIso8601String(),
        'updatedAt': date.toIso8601String(),
      };

      final account = Account.fromMap(map);

      expect(account.createdAt, date);
      expect(account.updatedAt, date);
    });
  });
}
