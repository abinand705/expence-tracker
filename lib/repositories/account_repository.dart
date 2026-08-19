import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';

class AccountRepository {
  static final AccountRepository _instance = AccountRepository._internal();
  factory AccountRepository() => _instance;
  AccountRepository._internal();

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

  CollectionReference<Map<String, dynamic>>? get _accountsCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('accounts');
  }

  Stream<List<Account>> watchAccounts() {
    final collection = _accountsCollection;
    if (collection == null) return Stream.value([]);
    
    return collection.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Account.fromMap(doc.data())).toList();
    });
  }

  Future<List<Account>> getAccounts() async {
    final collection = _accountsCollection;
    if (collection == null) return [];

    final snapshot = await collection.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => Account.fromMap(doc.data())).toList();
  }

  Future<Account?> getAccountById(String id) async {
    final collection = _accountsCollection;
    if (collection == null) return null;

    final doc = await collection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Account.fromMap(doc.data()!);
  }

  Future<String> addAccount(Account account) async {
    final collection = _accountsCollection;
    if (collection == null) throw Exception('User not authenticated');

    DocumentReference docRef;
    if (account.id.isEmpty) {
      docRef = collection.doc();
    } else {
      docRef = collection.doc(account.id);
    }
    
    final newAccount = Account(
      id: docRef.id,
      name: account.name,
      bankName: account.bankName,
      accountNumber: account.accountNumber,
      accountType: account.accountType,
      balance: account.balance,
      currentBalance: account.currentBalance,
      balanceSource: account.balanceSource,
      balanceUpdatedAt: account.balanceUpdatedAt,
      lastStatementImportAt: account.lastStatementImportAt,
      currency: account.currency,
      accentColor: account.accentColor,
      isAutoDiscovered: account.isAutoDiscovered,
      createdAt: account.createdAt ?? DateTime.now(),
      updatedAt: account.updatedAt ?? DateTime.now(),
    );

    await docRef.set(newAccount.toMap());
    return docRef.id;
  }

  Future<bool> addAccountIfAbsent(Account account) async {
    final collection = _accountsCollection;
    if (collection == null) throw Exception('User not authenticated');

    final docRef = collection.doc(account.id);
    
    return await _firestore.runTransaction((tx) async {
      final doc = await tx.get(docRef);
      if (doc.exists) {
        debugPrint('[AccountRepository] account already exists for uid: ${_auth.currentUser?.uid.substring(0, 5)}... ($docRef.id)');
        return false;
      }
      
      final newAccount = Account(
        id: docRef.id,
        name: account.name,
        bankName: account.bankName,
        accountNumber: account.accountNumber,
        accountType: account.accountType,
        balance: account.balance,
        currentBalance: account.currentBalance,
        balanceSource: account.balanceSource,
        balanceUpdatedAt: account.balanceUpdatedAt,
        lastStatementImportAt: account.lastStatementImportAt,
        currency: account.currency,
        accentColor: account.accentColor,
        isAutoDiscovered: account.isAutoDiscovered,
        createdAt: account.createdAt ?? DateTime.now(),
        updatedAt: account.updatedAt ?? DateTime.now(),
      );

      tx.set(docRef, newAccount.toMap());
      debugPrint('[AccountRepository] writing account for uid: ${_auth.currentUser?.uid.substring(0, 5)}...');
      debugPrint('[AccountRepository] account write successful: ${docRef.id}');
      return true;
    });
  }

  Future<void> cleanupLegacyAutoDiscoveredAccounts(String canonicalAccountId, String bankId, String last4) async {
    final collection = _accountsCollection;
    if (collection == null) return;

    final snapshot = await collection
        .where('isAutoDiscovered', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      final docId = doc.id;
      // Skip the canonical one
      if (docId == canonicalAccountId) continue;

      // Check if it's a legacy version of the same bank and ending with the same last4
      if (docId.startsWith('${bankId}_') && docId.endsWith(last4)) {
        // e.g. kgbank_80544 ends with 0544
        debugPrint('[AccountRepository] cleaning up legacy duplicate account: $docId (canonical: $canonicalAccountId)');
        await doc.reference.delete();
      }
    }
  }

  Future<void> updateAccount(Account account) async {
    final collection = _accountsCollection;
    if (collection == null) throw Exception('User not authenticated');

    final updateAccount = Account(
      id: account.id,
      name: account.name,
      bankName: account.bankName,
      accountNumber: account.accountNumber,
      accountType: account.accountType,
      balance: account.balance,
      currentBalance: account.currentBalance,
      balanceSource: account.balanceSource,
      balanceUpdatedAt: account.balanceUpdatedAt,
      lastStatementImportAt: account.lastStatementImportAt,
      currency: account.currency,
      accentColor: account.accentColor,
      isAutoDiscovered: account.isAutoDiscovered,
      createdAt: account.createdAt,
      updatedAt: DateTime.now(),
    );

    await collection.doc(account.id).update(updateAccount.toMap());
  }

  Future<void> deleteAccount(String id) async {
    final collection = _accountsCollection;
    if (collection == null) throw Exception('User not authenticated');

    await collection.doc(id).delete();
  }
}
