import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:expense_tracker/models/recurring_expense.dart';
import 'package:expense_tracker/repositories/recurring_expense_repository.dart';

void main() {
  group('RecurringExpenseRepository', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late RecurringExpenseRepository repository;
    final uid = 'test_uid_123';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      final mockUser = MockUser(uid: uid);
      auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      repository = RecurringExpenseRepository();
      repository.setInstancesForTesting(firestore, auth);
    });

    test('addRecurringExpense writes to correct scoped path', () async {
      final now = DateTime.now();
      final expense = RecurringExpense(
        id: '',
        title: 'Netflix',
        amount: 15.99,
        category: 'Entertainment',
        accountId: 'acc1',
        frequency: 'monthly',
        startDate: now,
        nextOccurrence: now,
        createdAt: now,
        updatedAt: now,
      );

      final id = await repository.addRecurringExpense(expense);
      expect(id, isNotEmpty);

      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('recurring_expenses')
          .get();

      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['title'], 'Netflix');
    });

    test('getRecurringExpenses retrieves items', () async {
      final now = DateTime.now();
      await firestore.collection('users').doc(uid).collection('recurring_expenses').add({
        'title': 'Spotify',
        'amount': 9.99,
        'category': 'Entertainment',
        'accountId': 'acc1',
        'frequency': 'monthly',
        'startDate': now,
        'nextOccurrence': now,
        'createdAt': now,
        'updatedAt': now,
      });

      final expenses = await repository.getRecurringExpenses();
      expect(expenses.length, 1);
      expect(expenses.first.title, 'Spotify');
    });
    
    test('User isolation', () async {
      final now = DateTime.now();
      // Write a document to user B's collection manually
      await firestore.collection('users').doc('user_B').collection('recurring_expenses').add({
        'title': 'Gym',
        'amount': 50.0,
        'category': 'Health',
        'accountId': 'acc1',
        'frequency': 'monthly',
        'startDate': now,
        'nextOccurrence': now,
        'createdAt': now,
        'updatedAt': now,
      });
      
      // Repository is authenticated as user test_uid_123, so it should not see user_B's docs
      final expenses = await repository.getRecurringExpenses();
      expect(expenses.length, 0);
    });
  });
}
