import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/budget_item.dart';
import '../models/category_item.dart';
import '../models/transaction_item.dart';

class FirestoreService {
  final FirebaseFirestore? _firestore;
  final List<TransactionItem> _localFallback = [];
  final Map<String, Map<String, dynamic>> _localUsersFallback = {};
  final List<CategoryItem> _localCategoriesFallback =
      List.from(CategoryItem.predefinedCategories);
  final List<BudgetItem> _localBudgetsFallback = [];
  final _fallbackController =
      StreamController<List<TransactionItem>>.broadcast();
  final _categoriesFallbackController =
      StreamController<List<CategoryItem>>.broadcast();
  final _budgetsFallbackController =
      StreamController<List<BudgetItem>>.broadcast();

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _resolveFirestore() {
    seedPredefinedCategories();
  }

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

  Stream<List<TransactionItem>> streamTransactions(String userId) async* {
    final ref = _userTransactionsRef(userId);
    if (ref == null) {
      // In-memory fallback stream for test/offline environments
      yield List.from(_localFallback);
      yield* _fallbackController.stream;
      return;
    }

    yield* ref
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
      final mapData = item.toMap(userId: userId);
      await ref.doc(item.id).set(mapData, SetOptions(merge: true));

      if (_firestore != null) {
        await _firestore
            .collection('transactions')
            .doc(item.id)
            .set(mapData, SetOptions(merge: true));
      }
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
      if (_firestore != null) {
        await _firestore
            .collection('transactions')
            .doc(transactionId)
            .delete();
      }
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

  /// Saves user registration details to the "users" collection with fields:
  /// username, user_Id, email_Id
  Future<void> saveUserData({
    required String userId,
    required String username,
    required String emailId,
  }) async {
    final data = {
      'username': username,
      'user_Id': userId,
      'email_Id': emailId,
    };

    if (_firestore == null) {
      _localUsersFallback[userId] = data;
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).set(
        data,
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error saving user data to Firestore: $e');
      rethrow;
    }
  }

  /// Retrieves user profile details from the "users" collection
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (_firestore == null) {
      return _localUsersFallback[userId];
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error fetching user data from Firestore: $e');
      return null;
    }
  }

  /// Ensures predefined categories from the app design exist in Firestore
  Future<void> seedPredefinedCategories() async {
    if (_firestore == null) return;
    try {
      final batch = _firestore.batch();

      // Ensure categories/expense and categories/income parent documents exist with metadata
      final expDoc = _firestore.collection('categories').doc('expense');
      batch.set(expDoc, {'type': 'expense', 'title': 'Expense Categories'}, SetOptions(merge: true));
      final incDoc = _firestore.collection('categories').doc('income');
      batch.set(incDoc, {'type': 'income', 'title': 'Income Categories'}, SetOptions(merge: true));

      for (final cat in CategoryItem.predefinedCategories) {
        final docRef = _firestore.collection('categories').doc(cat.id);
        batch.set(docRef, cat.toMap(), SetOptions(merge: true));

        final subRef = _firestore
            .collection('categories')
            .doc(cat.subcategory)
            .collection('items')
            .doc(cat.id);
        batch.set(subRef, cat.toMap(), SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Notice seeding predefined categories: $e');
    }
  }

  /// Streams categories: includes predefined categories (user_Id: 'all')
  /// and categories created by the specific user (user_Id: userId).
  Stream<List<CategoryItem>> streamCategories(String userId) async* {
    if (_firestore == null) {
      yield _localCategoriesFallback
          .where((c) => c.userId == 'all' || c.userId == userId)
          .toList();
      yield* _categoriesFallbackController.stream.map(
        (list) =>
            list.where((c) => c.userId == 'all' || c.userId == userId).toList(),
      );
      return;
    }

    final targetUserIds = {'all', if (userId.isNotEmpty) userId}.toList();
    final query = _firestore
        .collection('categories')
        .where('user_Id', whereIn: targetUserIds);

    yield* query.snapshots().map((snapshot) {
      final loaded = snapshot.docs
          .map((doc) => CategoryItem.fromMap(doc.id, doc.data()))
          .toList();

      final Map<String, CategoryItem> map = {};
      for (final cat in CategoryItem.predefinedCategories) {
        map[cat.name.toLowerCase()] = cat;
      }
      for (final cat in loaded) {
        map[cat.name.toLowerCase()] = cat;
      }
      return map.values.toList();
    });
  }

  /// Saves a category document to Firestore with fields:
  /// "category/expense_name", "icon", "colour", "user_Id", "subcategory"
  Future<void> saveCategory(CategoryItem category) async {
    _localCategoriesFallback.removeWhere((c) => c.id == category.id);
    _localCategoriesFallback.add(category);
    _categoriesFallbackController.add(List.from(_localCategoriesFallback));

    if (_firestore == null) return;

    try {
      // Ensure parent document exists
      await _firestore.collection('categories').doc(category.subcategory).set({
        'type': category.subcategory,
        'title': '${category.subcategory[0].toUpperCase()}${category.subcategory.substring(1)} Categories',
      }, SetOptions(merge: true));

      await _firestore
          .collection('categories')
          .doc(category.id)
          .set(category.toMap(), SetOptions(merge: true));

      await _firestore
          .collection('categories')
          .doc(category.subcategory)
          .collection('items')
          .doc(category.id)
          .set(category.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving category to Firestore: $e');
      rethrow;
    }
  }

  /// Deletes a custom category from Firestore
  Future<void> deleteCategory(String categoryId, String subcategory) async {
    _localCategoriesFallback.removeWhere((c) => c.id == categoryId);
    _categoriesFallbackController.add(List.from(_localCategoriesFallback));

    if (_firestore == null) return;

    try {
      await _firestore.collection('categories').doc(categoryId).delete();
      await _firestore
          .collection('categories')
          .doc(subcategory)
          .collection('items')
          .doc(categoryId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting category from Firestore: $e');
      rethrow;
    }
  }

  /// Streams user's category budgets from the "budgets" collection
  Stream<List<BudgetItem>> streamBudgets(String userId) async* {
    if (_firestore == null) {
      yield _localBudgetsFallback
          .where((b) => b.userId == 'all' || b.userId == userId)
          .toList();
      yield* _budgetsFallbackController.stream.map(
        (list) =>
            list.where((b) => b.userId == 'all' || b.userId == userId).toList(),
      );
      return;
    }

    final targetUserIds = {'all', if (userId.isNotEmpty) userId}.toList();
    final query = _firestore
        .collection('budgets')
        .where('user_Id', whereIn: targetUserIds);

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BudgetItem.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Saves a budget document to Firestore with fields:
  /// "category/expense_name", "monthly_limit" (integer), and "user_Id"
  Future<void> saveBudget(BudgetItem budget) async {
    _localBudgetsFallback.removeWhere((b) =>
        b.id == budget.id ||
        (b.userId == budget.userId && b.categoryName == budget.categoryName));
    _localBudgetsFallback.add(budget);
    _budgetsFallbackController.add(List.from(_localBudgetsFallback));

    if (_firestore == null) return;

    try {
      // Top-level "budgets" collection
      await _firestore
          .collection('budgets')
          .doc(budget.id)
          .set(budget.toMap(), SetOptions(merge: true));

      // Also persist to user's subcollection for consistency
      if (budget.userId.isNotEmpty && budget.userId != 'all') {
        await _firestore
            .collection('users')
            .doc(budget.userId)
            .collection('budgets')
            .doc(budget.id)
            .set(budget.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving budget to Firestore: $e');
      rethrow;
    }
  }

  /// Deletes a budget document from Firestore
  Future<void> deleteBudget(String budgetId, {String? userId}) async {
    _localBudgetsFallback.removeWhere((b) => b.id == budgetId);
    _budgetsFallbackController.add(List.from(_localBudgetsFallback));

    if (_firestore == null) return;

    try {
      await _firestore.collection('budgets').doc(budgetId).delete();
      if (userId != null && userId.isNotEmpty && userId != 'all') {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('budgets')
            .doc(budgetId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error deleting budget from Firestore: $e');
      rethrow;
    }
  }

  void dispose() {
    _fallbackController.close();
    _categoriesFallbackController.close();
    _budgetsFallbackController.close();
  }
}
