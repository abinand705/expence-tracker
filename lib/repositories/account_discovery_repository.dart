import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/discovered_bank_account.dart';

/// Repository for bank account discoveries detected from SMS.
///
/// Firestore path: users/{uid}/account_discoveries/{discoveryId}
/// Database: 'moneytrack'
class AccountDiscoveryRepository {
  static final AccountDiscoveryRepository _instance =
      AccountDiscoveryRepository._internal();
  factory AccountDiscoveryRepository() => _instance;
  AccountDiscoveryRepository._internal();

  /// In-memory repository for unit testing without Firebase.
  factory AccountDiscoveryRepository.inMemory([
    Map<String, DiscoveredBankAccount>? initialData,
  ]) = _InMemoryAccountDiscoveryRepository;

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

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('account_discoveries');
  }

  /// Streams pending discoveries (state: 'discovered' or 'suggested').
  Stream<List<DiscoveredBankAccount>> watchPendingDiscoveries() {
    final col = _collection;
    if (col == null) return Stream.value([]);
    return col
        .where('state', whereIn: ['discovered', 'suggested'])
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DiscoveredBankAccount.fromMap(d.data()))
            .where((d) => d.isSuggestible)
            .toList());
  }

  /// Fetches all discoveries for the authenticated user.
  Future<List<DiscoveredBankAccount>> getDiscoveries() async {
    final col = _collection;
    if (col == null) return [];
    final snap = await col.get();
    return snap.docs
        .map((d) => DiscoveredBankAccount.fromMap(d.data()))
        .toList();
  }

  /// Fetches pending discoveries that should be suggested to the user.
  Future<List<DiscoveredBankAccount>> getPendingDiscoveries() async {
    final col = _collection;
    if (col == null) return [];
    final snap = await col
        .where('state', whereIn: ['discovered', 'suggested'])
        .get();
    return snap.docs
        .map((d) => DiscoveredBankAccount.fromMap(d.data()))
        .where((d) => d.isSuggestible)
        .toList();
  }

  /// Fetches a specific discovery by ID.
  Future<DiscoveredBankAccount?> getDiscovery(String discoveryId) async {
    final col = _collection;
    if (col == null) return null;
    final doc = await col.doc(discoveryId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DiscoveredBankAccount.fromMap(doc.data()!);
  }

  /// Saves or updates a discovered account.
  Future<void> saveDiscovery(DiscoveredBankAccount discovery) async {
    final col = _collection;
    if (col == null) return;
    await col.doc(discovery.discoveryId).set(
          discovery.toMap(),
          SetOptions(merge: true),
        );
    debugPrint(
        '[AccountDiscoveryRepository] saved discovery: ${discovery.discoveryId} (${discovery.bankName} ••••${discovery.accountLast4})');
  }

  /// Marks a discovery as dismissed ("Not Now").
  Future<void> dismissDiscovery(String discoveryId) async {
    final col = _collection;
    if (col == null) return;
    await col.doc(discoveryId).update({'state': 'dismissed'});
    debugPrint('[AccountDiscoveryRepository] dismissed discovery: $discoveryId');
  }

  /// Marks a discovery as ignored (do not suggest again).
  Future<void> ignoreDiscovery(String discoveryId) async {
    final col = _collection;
    if (col == null) return;
    await col.doc(discoveryId).update({'state': 'ignored'});
    debugPrint('[AccountDiscoveryRepository] ignored discovery: $discoveryId');
  }

  /// Marks a discovery as initialized (user created authoritative account).
  Future<void> markInitialized(String discoveryId) async {
    final col = _collection;
    if (col == null) return;
    await col.doc(discoveryId).update({'state': 'initialized'});
    debugPrint(
        '[AccountDiscoveryRepository] marked initialized: $discoveryId');
  }
}

class _InMemoryAccountDiscoveryRepository
    implements AccountDiscoveryRepository {
  final Map<String, DiscoveredBankAccount> _data;
  final StreamController<List<DiscoveredBankAccount>> _controller =
      StreamController.broadcast();

  _InMemoryAccountDiscoveryRepository([
    Map<String, DiscoveredBankAccount>? initialData,
  ]) : _data = initialData != null ? Map.from(initialData) : {};

  void _notify() {
    final pending = _data.values
        .where((d) =>
            (d.state == 'discovered' || d.state == 'suggested') &&
            d.isSuggestible)
        .toList();
    _controller.add(pending);
  }

  @override
  Stream<List<DiscoveredBankAccount>> watchPendingDiscoveries() {
    return _controller.stream;
  }

  @override
  Future<List<DiscoveredBankAccount>> getDiscoveries() async =>
      _data.values.toList();

  @override
  Future<List<DiscoveredBankAccount>> getPendingDiscoveries() async => _data
      .values
      .where((d) =>
          (d.state == 'discovered' || d.state == 'suggested') &&
          d.isSuggestible)
      .toList();

  @override
  Future<DiscoveredBankAccount?> getDiscovery(String discoveryId) async =>
      _data[discoveryId];

  @override
  Future<void> saveDiscovery(DiscoveredBankAccount discovery) async {
    _data[discovery.discoveryId] = discovery;
    _notify();
  }

  @override
  Future<void> dismissDiscovery(String discoveryId) async {
    final existing = _data[discoveryId];
    if (existing != null) {
      _data[discoveryId] = existing.copyWith(state: 'dismissed');
      _notify();
    }
  }

  @override
  Future<void> ignoreDiscovery(String discoveryId) async {
    final existing = _data[discoveryId];
    if (existing != null) {
      _data[discoveryId] = existing.copyWith(state: 'ignored');
      _notify();
    }
  }

  @override
  Future<void> markInitialized(String discoveryId) async {
    final existing = _data[discoveryId];
    if (existing != null) {
      _data[discoveryId] = existing.copyWith(state: 'initialized');
      _notify();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
