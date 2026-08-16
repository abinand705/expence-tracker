import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../theme/app_colors.dart';

class CategoryRepository {
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

  CollectionReference<Map<String, dynamic>>? get _categoriesCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('categories');
  }

  Future<void> _initializeDefaultsIfNeeded(CollectionReference<Map<String, dynamic>> collection) async {
    final snapshot = await collection.limit(1).get();
    if (snapshot.docs.isEmpty) {
      final now = DateTime.now();
      final defaults = [
        Category(id: 'food', name: 'Food', iconCodePoint: Icons.restaurant.codePoint, colorValue: AppColors.pastelPink.toARGB32(), createdAt: now, updatedAt: now),
        Category(id: 'shopping', name: 'Shopping', iconCodePoint: Icons.shopping_bag.codePoint, colorValue: AppColors.pastelPurple.toARGB32(), createdAt: now, updatedAt: now),
        Category(id: 'bills', name: 'Bills', iconCodePoint: Icons.receipt.codePoint, colorValue: AppColors.pastelBlue.toARGB32(), createdAt: now, updatedAt: now),
        Category(id: 'others', name: 'Others', iconCodePoint: Icons.category.codePoint, colorValue: AppColors.surfaceContainerHigh.toARGB32(), createdAt: now, updatedAt: now),
      ];

      final batch = _firestore.batch();
      for (var cat in defaults) {
        batch.set(collection.doc(cat.id), cat.toMap());
      }
      await batch.commit();
    }
  }

  Stream<List<Category>> watchCategories() {
    final collection = _categoriesCollection;
    if (collection == null) return Stream.value([]);
    
    // Fire and forget initialization to ensure defaults exist.
    _initializeDefaultsIfNeeded(collection);

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Category.fromMap(doc.data(), documentId: doc.id)).toList();
    });
  }

  Future<List<Category>> getCategories() async {
    final collection = _categoriesCollection;
    if (collection == null) return [];
    
    await _initializeDefaultsIfNeeded(collection);

    final snapshot = await collection.get();
    return snapshot.docs.map((doc) => Category.fromMap(doc.data(), documentId: doc.id)).toList();
  }

  Future<void> addCategory(Category category) async {
    final collection = _categoriesCollection;
    if (collection == null) return;

    if (category.id.isNotEmpty) {
      await collection.doc(category.id).set(category.toMap());
    } else {
      final docRef = collection.doc();
      final newCategory = Category(
        id: docRef.id,
        name: category.name,
        iconCodePoint: category.iconCodePoint,
        colorValue: category.colorValue,
        createdAt: category.createdAt,
        updatedAt: category.updatedAt,
      );
      await docRef.set(newCategory.toMap());
    }
  }

  Future<void> updateCategory(Category category) async {
    final collection = _categoriesCollection;
    if (collection == null) return;
    
    final data = category.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await collection.doc(category.id).update(data);
  }

  Future<void> deleteCategory(String id) async {
    final collection = _categoriesCollection;
    if (collection == null) return;

    await collection.doc(id).delete();
  }
}
