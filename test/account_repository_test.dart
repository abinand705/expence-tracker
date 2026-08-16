import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/models/account.dart';

void main() {
  group('AccountRepository Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late AccountRepository accountRepo;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      
      final mockUser = MockUser(
        isAnonymous: false,
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      accountRepo = AccountRepository();
      accountRepo.setInstancesForTesting(fakeFirestore, mockAuth);
    });

    test('addAccount creates an account in users/uid/accounts', () async {
      final account = Account(
        id: '',
        name: 'Test Savings',
        bankName: 'Test Bank',
        accountNumber: '1234',
        accountType: 'Savings',
        balance: 5000.0,
        accentColor: Colors.green,
      );

      final id = await accountRepo.addAccount(account);
      expect(id, isNotEmpty);

      final doc = await fakeFirestore
          .collection('users')
          .doc('test_uid')
          .collection('accounts')
          .doc(id)
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['name'], 'Test Savings');
      expect(doc.data()!['balance'], 5000.0);
    });

    test('getAccounts retrieves user accounts', () async {
      await fakeFirestore
          .collection('users')
          .doc('test_uid')
          .collection('accounts')
          .doc('acc1')
          .set({
        'id': 'acc1',
        'name': 'Test Account',
        'balance': 1000.0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final accounts = await accountRepo.getAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Test Account');
      expect(accounts.first.balance, 1000.0);
    });

    test('updateAccount modifies existing document', () async {
      await fakeFirestore
          .collection('users')
          .doc('test_uid')
          .collection('accounts')
          .doc('acc1')
          .set({
        'id': 'acc1',
        'name': 'Old Name',
        'balance': 1000.0,
      });

      final updatedAccount = Account(
        id: 'acc1',
        name: 'New Name',
        bankName: 'Test Bank',
        accountNumber: '1234',
        accountType: 'Savings',
        balance: 2000.0,
        accentColor: Colors.blue,
      );

      await accountRepo.updateAccount(updatedAccount);

      final doc = await fakeFirestore
          .collection('users')
          .doc('test_uid')
          .collection('accounts')
          .doc('acc1')
          .get();

      expect(doc.data()!['name'], 'New Name');
      expect(doc.data()!['balance'], 2000.0);
    });

    test('deleteAccount removes document', () async {
      await fakeFirestore
          .collection('users')
          .doc('test_uid')
          .collection('accounts')
          .doc('acc1')
          .set({
        'id': 'acc1',
        'name': 'To Delete',
        'balance': 1000.0,
      });

      await accountRepo.deleteAccount('acc1');

      final doc = await fakeFirestore
          .collection('users')
          .doc('test_uid')
          .collection('accounts')
          .doc('acc1')
          .get();

      expect(doc.exists, false);
    });
  });
}
