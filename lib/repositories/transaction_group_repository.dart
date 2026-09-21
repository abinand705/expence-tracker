import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction_group.dart';

class TransactionGroupRepository {
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

  CollectionReference<Map<String, dynamic>> get _groupsRef {
    return _firestore.collection('users').doc(_uid).collection('transaction_groups');
  }

  Future<void> saveGroup(TransactionGroup group) async {
    final docRef = _groupsRef.doc(group.groupId);
    final data = group.toMap();
    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> batchSaveGroups(List<TransactionGroup> groups) async {
    if (groups.isEmpty) return;
    const maxBatchSize = 500;
    for (int i = 0; i < groups.length; i += maxBatchSize) {
      final batch = _firestore.batch();
      final chunk = groups.skip(i).take(maxBatchSize);
      for (final g in chunk) {
        final docRef = _groupsRef.doc(g.groupId);
        batch.set(docRef, g.toMap(), SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Future<List<TransactionGroup>> getPendingReviewGroups() async {
    final snapshot = await _groupsRef
        .where('status', isEqualTo: TransactionGroupStatus.pendingReview.name)
        .orderBy('transactionDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => TransactionGroup.fromMap(doc.data())).toList();
  }

  Stream<List<TransactionGroup>> watchPendingReviewGroups() {
    return _groupsRef
        .where('status', isEqualTo: TransactionGroupStatus.pendingReview.name)
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TransactionGroup.fromMap(doc.data())).toList());
  }

  Future<void> updateGroupStatus(String groupId, TransactionGroupStatus status) async {
    final docRef = _groupsRef.doc(groupId);
    await docRef.update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
