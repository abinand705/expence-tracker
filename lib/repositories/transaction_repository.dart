import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart' as model;

class TransactionRepository {
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

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _transactionsRef {
    return _firestore.collection('users').doc(_uid).collection('transactions');
  }

  Future<List<model.Transaction>> getTransactions() async {
    final snapshot = await _transactionsRef.orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => model.Transaction.fromMap(doc.data())).toList();
  }

  Future<List<model.Transaction>> getTransactionsForAccount(String accountId) async {
    final snapshot = await _transactionsRef
        .where('accountId', isEqualTo: accountId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) => model.Transaction.fromMap(doc.data())).toList();
  }

  Stream<List<model.Transaction>> watchTransactions() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[REPOSITORY] watchTransactions: User is not authenticated initially, waiting for authStateChanges');
      return _auth.authStateChanges().asyncExpand((u) {
        if (u == null) return Stream.value([]);
        return _firestore
            .collection('users')
            .doc(u.uid)
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots()
            .map((snapshot) {
              debugPrint('[REPOSITORY] Transactions read: ${snapshot.docs.length}');
              return snapshot.docs.map((doc) => model.Transaction.fromMap(doc.data())).toList();
            });
      });
    }

    return _transactionsRef.orderBy('date', descending: true).snapshots().map((snapshot) {
      debugPrint('[REPOSITORY] Transactions read: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => model.Transaction.fromMap(doc.data())).toList();
    });
  }

  Future<model.Transaction?> getTransactionById(String id) async {
    final doc = await _transactionsRef.doc(id).get();
    if (!doc.exists) return null;
    return model.Transaction.fromMap(doc.data()!);
  }

  Future<String> addTransaction(model.Transaction transaction) async {
    try {
      final docRef = transaction.id.isEmpty
          ? _transactionsRef.doc()
          : _transactionsRef.doc(transaction.id);
      
      final txToSave = transaction.id.isEmpty
          ? transaction.copyWith(id: docRef.id)
          : transaction;
      final data = txToSave.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      await docRef.set(data);
      debugPrint('[REPOSITORY] Transactions written: 1 (id: ${txToSave.id}) to path: ${docRef.path} (database: moneytrack)');
      return docRef.id;
    } catch (e) {
      debugPrint('[REPOSITORY] Transaction write failed: $e');
      rethrow;
    }
  }

  Future<bool> addTransactionIfAbsent(model.Transaction transaction) async {
    try {
      final docRef = _transactionsRef.doc(transaction.id);
      
      return await _firestore.runTransaction((tx) async {
        final doc = await tx.get(docRef);
        if (doc.exists) {
          return false;
        }
        
        final data = transaction.toMap();
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        
        tx.set(docRef, data);
        debugPrint('[REPOSITORY] Transactions written: 1 (id: ${transaction.id})');
        return true;
      });
    } catch (e) {
      debugPrint('[REPOSITORY] Transaction write failed: $e');
      rethrow;
    }
  }

  Future<void> batchAddTransactions(List<model.Transaction> transactions) async {
    if (transactions.isEmpty) return;
    
    // Firestore batches can have max 500 operations
    final maxBatchSize = 500;
    
    for (int i = 0; i < transactions.length; i += maxBatchSize) {
      final batch = _firestore.batch();
      final chunk = transactions.skip(i).take(maxBatchSize);
      
      for (final tx in chunk) {
        final docRef = _transactionsRef.doc(tx.id);
        final data = tx.toMap();
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(docRef, data);
      }
      
      await batch.commit();
    }
  }

  Future<void> updateTransaction(model.Transaction transaction) async {
    final docRef = _transactionsRef.doc(transaction.id);
    
    final data = transaction.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    
    await docRef.update(data);
  }

  Future<void> updateTransactionTitle(String transactionId, String? customTitle) async {
    final docRef = _transactionsRef.doc(transactionId);
    await docRef.update({
      'customTitle': customTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTransactionCategory(String transactionId, String category) async {
    final normalized = model.TransactionCategory.normalize(category);
    final docRef = _transactionsRef.doc(transactionId);
    await docRef.update({
      'customCategory': normalized,
      'category': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionsRef.doc(id).delete();
  }
}
