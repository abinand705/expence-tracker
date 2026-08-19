import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction.dart' as model;

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'moneytrack',
  );

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
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
    return _transactionsRef.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => model.Transaction.fromMap(doc.data())).toList();
    });
  }

  Future<model.Transaction?> getTransactionById(String id) async {
    final doc = await _transactionsRef.doc(id).get();
    if (!doc.exists) return null;
    return model.Transaction.fromMap(doc.data()!);
  }

  Future<String> addTransaction(model.Transaction transaction) async {
    final docRef = _transactionsRef.doc(transaction.id);
    
    final data = transaction.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    
    await docRef.set(data);
    return docRef.id;
  }

  Future<bool> addTransactionIfAbsent(model.Transaction transaction) async {
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
      return true;
    });
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

  Future<void> deleteTransaction(String id) async {
    await _transactionsRef.doc(id).delete();
  }
}
