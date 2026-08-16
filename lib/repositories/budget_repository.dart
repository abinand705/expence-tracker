import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/budget.dart';

class BudgetRepository {
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

  CollectionReference<Map<String, dynamic>>? get _budgetsCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('budgets');
  }

  Stream<List<Budget>> watchBudgets() {
    final collection = _budgetsCollection;
    if (collection == null) return Stream.value([]);
    
    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Budget.fromMap(doc.data(), documentId: doc.id)).toList();
    });
  }

  Future<List<Budget>> getBudgets() async {
    final collection = _budgetsCollection;
    if (collection == null) return [];
    
    final snapshot = await collection.get();
    return snapshot.docs.map((doc) => Budget.fromMap(doc.data(), documentId: doc.id)).toList();
  }

  Future<Budget?> getBudgetById(String id) async {
    final collection = _budgetsCollection;
    if (collection == null) return null;

    final doc = await collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;

    return Budget.fromMap(doc.data()!, documentId: doc.id);
  }

  Future<String> addBudget(Budget budget) async {
    final collection = _budgetsCollection;
    if (collection == null) throw Exception("User not authenticated");

    final docRef = collection.doc();
    final newBudget = Budget(
      id: docRef.id,
      category: budget.category,
      amount: budget.amount,
      period: budget.period,
      createdAt: budget.createdAt,
      updatedAt: budget.updatedAt,
    );
    await docRef.set(newBudget.toMap());
    return docRef.id;
  }

  Future<void> updateBudget(Budget budget) async {
    final collection = _budgetsCollection;
    if (collection == null) return;
    
    final data = budget.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await collection.doc(budget.id).update(data);
  }

  Future<void> deleteBudget(String id) async {
    final collection = _budgetsCollection;
    if (collection == null) return;

    await collection.doc(id).delete();
  }
}
