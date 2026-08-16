import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:expense_tracker/repositories/budget_repository.dart';
import 'package:expense_tracker/models/budget.dart';

void main() {
  group('BudgetRepository Tests', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late BudgetRepository repository;
    final uid = 'test_uid_123';
    
    setUp(() {
      firestore = FakeFirebaseFirestore();
      final mockUser = MockUser(uid: uid);
      auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
      
      repository = BudgetRepository();
      repository.setInstancesForTesting(firestore, auth);
    });

    test('addBudget creates a budget in users/uid/budgets', () async {
      final now = DateTime.now();
      final budget = Budget(
        id: '',
        category: 'Total',
        amount: 20000.0,
        period: 'monthly',
        createdAt: now,
        updatedAt: now,
      );

      final id = await repository.addBudget(budget);
      expect(id, isNotEmpty);

      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .get();

      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['amount'], 20000.0);
    });

    test('getBudgets retrieves user budgets', () async {
      final now = DateTime.now();
      await firestore.collection('users').doc(uid).collection('budgets').add({
        'category': 'Food',
        'amount': 5000.0,
        'period': 'monthly',
        'createdAt': now,
        'updatedAt': now,
      });

      final budgets = await repository.getBudgets();
      expect(budgets.length, 1);
      expect(budgets.first.category, 'Food');
      expect(budgets.first.amount, 5000.0);
    });

    test('updateBudget modifies existing document', () async {
      final now = DateTime.now();
      final docRef = await firestore.collection('users').doc(uid).collection('budgets').add({
        'category': 'Food',
        'amount': 5000.0,
        'period': 'monthly',
        'createdAt': now,
        'updatedAt': now,
      });

      final budgetToUpdate = Budget(
        id: docRef.id,
        category: 'Food',
        amount: 6000.0, // Modified amount
        period: 'monthly',
        createdAt: now,
        updatedAt: now,
      );

      await repository.updateBudget(budgetToUpdate);

      final doc = await docRef.get();
      expect(doc.data()?['amount'], 6000.0);
    });

    test('deleteBudget removes document', () async {
      final now = DateTime.now();
      final docRef = await firestore.collection('users').doc(uid).collection('budgets').add({
        'category': 'Food',
        'amount': 5000.0,
        'period': 'monthly',
        'createdAt': now,
        'updatedAt': now,
      });

      await repository.deleteBudget(docRef.id);

      final doc = await docRef.get();
      expect(doc.exists, isFalse);
    });
    
    test('watchBudgets streams updates correctly', () async {
      final now = DateTime.now();
      
      final stream = repository.watchBudgets();
      
      expect(stream, emits(isEmpty));
      
      await firestore.collection('users').doc(uid).collection('budgets').add({
        'category': 'Total',
        'amount': 10000.0,
        'period': 'monthly',
        'createdAt': now,
        'updatedAt': now,
      });
      
      final budgets = await stream.firstWhere((list) => list.isNotEmpty);
      expect(budgets.length, 1);
      expect(budgets.first.amount, 10000.0);
    });
  });
}
