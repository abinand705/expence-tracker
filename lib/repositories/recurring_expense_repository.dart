import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/recurring_expense.dart';

class RecurringExpenseRepository {
  FirebaseFirestore? __firestore;
  FirebaseFirestore get _firestore {
    __firestore ??= FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'moneytrack',
    );
    return __firestore!;
  }

  FirebaseAuth? __auth;
  FirebaseAuth get _auth {
    __auth ??= FirebaseAuth.instance;
    return __auth!;
  }

  @visibleForTesting
  void setInstancesForTesting(FirebaseFirestore firestore, FirebaseAuth auth) {
    __firestore = firestore;
    __auth = auth;
  }

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('recurring_expenses');
  }

  Stream<List<RecurringExpense>> watchRecurringExpenses() {
    final collection = _collection;
    if (collection == null) return Stream.value([]);
    
    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RecurringExpense.fromMap(doc.data(), documentId: doc.id)).toList();
    });
  }

  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final collection = _collection;
    if (collection == null) return [];
    
    final snapshot = await collection.get();
    return snapshot.docs.map((doc) => RecurringExpense.fromMap(doc.data(), documentId: doc.id)).toList();
  }

  Future<RecurringExpense?> getRecurringExpenseById(String id) async {
    final collection = _collection;
    if (collection == null) return null;

    final doc = await collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;

    return RecurringExpense.fromMap(doc.data()!, documentId: doc.id);
  }

  Future<String> addRecurringExpense(RecurringExpense expense) async {
    final collection = _collection;
    if (collection == null) throw Exception("User not authenticated");

    final docRef = collection.doc();
    final newExpense = RecurringExpense(
      id: docRef.id,
      title: expense.title,
      amount: expense.amount,
      category: expense.category,
      accountId: expense.accountId,
      frequency: expense.frequency,
      startDate: expense.startDate,
      nextOccurrence: expense.nextOccurrence,
      endDate: expense.endDate,
      isActive: expense.isActive,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    );
    await docRef.set(newExpense.toMap());
    return docRef.id;
  }

  Future<void> updateRecurringExpense(RecurringExpense expense) async {
    final collection = _collection;
    if (collection == null) return;
    
    final data = expense.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await collection.doc(expense.id).update(data);
  }

  Future<void> deleteRecurringExpense(String id) async {
    final collection = _collection;
    if (collection == null) return;

    await collection.doc(id).delete();
  }
}
