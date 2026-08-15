import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

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

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    final updateData = Map<String, dynamic>.from(data);
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    
    await _firestore.collection('users').doc(uid).update(updateData);
  }

  // Fallback methods for mock usages during migration phase
  Future<String?> getUserName() async {
    // Attempt to get currently authenticated user profile
    // But since this is a synchronous-ish wrapper, we can just return a fallback if no auth logic provided here
    // We will rely on Auth flow. For now, if called directly:
    return 'User';
  }

  Future<void> updateUserName(String name) async {
    // Mock update logic
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
