import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_item.dart';

class FirestoreService {
  final FirebaseFirestore? _firestore;
  final List<TransactionItem> _localFallback = [];
  final _fallbackController = StreamController<List<TransactionItem>>.broadcast();

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _resolveFirestore();

  static FirebaseFirestore? _resolveFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('Firestore not available in current environment: $e');
      return null;
    }
  }

  bool get isAvailable => _firestore != null;

  CollectionReference<Map<String, dynamic>>? _userTransactionsRef(String userId) {
    if (_firestore == null || userId.isEmpty) return null;
    return _firestore.collection('users').doc(userId).collection('transactions');
  }

  Stream<List<TransactionItem>> streamTransactions(String userId) {
    final ref = _userTransactionsRef(userId);
    if (ref == null) {
      // In-memory fallback stream for test/offline environments
      return _fallbackController.stream;
    }

    return ref
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionItem.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> saveTransaction(String userId, TransactionItem item) async {
    final ref = _userTransactionsRef(userId);
    if (ref == null) {
      _localFallback.removeWhere((t) => t.id == item.id);
      _localFallback.insert(0, item);
      _fallbackController.add(List.from(_localFallback));
      return;
    }

    try {
      await ref.doc(item.id).set(item.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving transaction to Firestore: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String userId, String transactionId) async {
    final ref = _userTransactionsRef(userId);
    if (ref == null) {
      _localFallback.removeWhere((t) => t.id == transactionId);
      _fallbackController.add(List.from(_localFallback));
      return;
    }

    try {
      await ref.doc(transactionId).delete();
    } catch (e) {
      debugPrint('Error deleting transaction from Firestore: $e');
      rethrow;
    }
  }

  Future<void> clearAllTransactions(String userId) async {
    final ref = _userTransactionsRef(userId);
    if (ref == null) {
      _localFallback.clear();
      _fallbackController.add([]);
      return;
    }

    try {
      final snapshot = await ref.get();
      final batch = _firestore!.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing transactions in Firestore: $e');
      rethrow;
    }
  }

  void dispose() {
    _fallbackController.close();
  }
}
