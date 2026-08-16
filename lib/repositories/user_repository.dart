import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  static final UserRepository _instance = UserRepository._internal();
  factory UserRepository() => _instance;
  UserRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'moneytrack',
  );

  Future<void> createProfile({
    required String uid,
    required String displayName,
    required String email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'displayName': displayName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'currency': 'INR', // Default
    });
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) => doc.data());
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    final updateData = Map<String, dynamic>.from(data);
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    
    await _firestore.collection('users').doc(uid).update(updateData);
  }

  Future<String?> getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'User';
    final profile = await getProfile(user.uid);
    return profile?['displayName'] as String? ?? user.displayName ?? 'User';
  }

  Future<void> updateUserName(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await updateProfile(user.uid, {'displayName': name});
    // Also update Firebase Auth profile
    await user.updateDisplayName(name);
  }
}
