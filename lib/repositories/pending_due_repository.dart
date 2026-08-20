import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pending_due.dart';

class PendingDueRepository {
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

  CollectionReference<Map<String, dynamic>> get _duesRef {
    return _firestore.collection('users').doc(_uid).collection('pending_dues');
  }

  Stream<List<PendingDue>> watchPendingDues() {
    return _duesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PendingDue.fromMap(doc.data())).toList();
    });
  }

  Future<bool> addPendingDueIfAbsent(PendingDue due) async {
    final docRef = _duesRef.doc(due.id);
    
    return await _firestore.runTransaction((tx) async {
      final doc = await tx.get(docRef);
      if (doc.exists) {
        return false;
      }
      
      final data = due.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      
      tx.set(docRef, data);
      return true;
    });
  }

  Future<void> deletePendingDue(String id) async {
    await _duesRef.doc(id).delete();
  }

  Future<List<PendingDue>> getPendingDues() async {
    final snapshot = await _duesRef.get();
    return snapshot.docs.map((doc) => PendingDue.fromMap(doc.data())).toList();
  }
}
