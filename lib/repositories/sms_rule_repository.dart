import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/sms_recognition_rule.dart';

/// Repository for per-account SMS recognition rules.
///
/// Firestore path: users/{uid}/accounts/{accountId}/sms_rules/{ruleId}
class SmsRuleRepository {
  static final SmsRuleRepository _instance = SmsRuleRepository._internal();
  factory SmsRuleRepository() => _instance;
  SmsRuleRepository._internal();

  /// In-memory repository for unit testing without Firebase.
  factory SmsRuleRepository.inMemory([Map<String, List<SmsRecognitionRule>>? initialRules]) =
      _InMemorySmsRuleRepository;

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

  CollectionReference<Map<String, dynamic>>? _rulesCollection(String accountId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .doc(accountId)
        .collection('sms_rules');
  }

  /// Stream of rules for a given account, ordered by creation date.
  Stream<List<SmsRecognitionRule>> watchRules(String accountId) {
    final collection = _rulesCollection(accountId);
    if (collection == null) return Stream.value([]);
    return collection
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SmsRecognitionRule.fromMap(doc.data()))
            .toList());
  }

  /// Fetches all rules for a given account.
  Future<List<SmsRecognitionRule>> getRules(String accountId) async {
    final collection = _rulesCollection(accountId);
    if (collection == null) return [];
    final snap = await collection.orderBy('createdAt', descending: false).get();
    return snap.docs.map((doc) => SmsRecognitionRule.fromMap(doc.data())).toList();
  }

  /// Fetches all enabled rules for a given account.
  Future<List<SmsRecognitionRule>> getEnabledRules(String accountId) async {
    final rules = await getRules(accountId);
    return rules.where((r) => r.isEnabled).toList();
  }

  /// Adds a new rule. Returns the generated rule ID.
  Future<String> addRule(SmsRecognitionRule rule) async {
    final collection = _rulesCollection(rule.accountId);
    if (collection == null) throw Exception('User not authenticated');

    DocumentReference docRef;
    if (rule.id.isEmpty) {
      docRef = collection.doc();
    } else {
      docRef = collection.doc(rule.id);
    }

    final ruleWithId = rule.copyWith(id: docRef.id);
    await docRef.set(ruleWithId.toMap());
    debugPrint('[SmsRuleRepository] added rule ${docRef.id} for account ${rule.accountId}');
    return docRef.id;
  }

  /// Updates an existing rule.
  Future<void> updateRule(SmsRecognitionRule rule) async {
    final collection = _rulesCollection(rule.accountId);
    if (collection == null) throw Exception('User not authenticated');

    final updated = rule.copyWith(updatedAt: DateTime.now());
    await collection.doc(rule.id).set(updated.toMap());
    debugPrint('[SmsRuleRepository] updated rule ${rule.id} for account ${rule.accountId}');
  }

  /// Deletes a rule.
  Future<void> deleteRule(String accountId, String ruleId) async {
    final collection = _rulesCollection(accountId);
    if (collection == null) throw Exception('User not authenticated');
    await collection.doc(ruleId).delete();
    debugPrint('[SmsRuleRepository] deleted rule $ruleId for account $accountId');
  }

  /// Loads ALL rules across ALL accounts for a given user.
  /// Used during SMS scanning to build the in-memory index.
  Future<Map<String, List<SmsRecognitionRule>>> getAllRulesByAccount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    final Map<String, List<SmsRecognitionRule>> result = {};

    try {
      // Fetch all accounts first to enumerate sub-collections
      final accountsSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .get();

      for (final accountDoc in accountsSnap.docs) {
        final accountId = accountDoc.id;
        // Only load rules for accounts that have smsTrackingEnabled = true
        final data = accountDoc.data();
        final smsEnabled = data['smsTrackingEnabled'] as bool? ?? false;
        if (!smsEnabled) continue;

        final rulesSnap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('accounts')
            .doc(accountId)
            .collection('sms_rules')
            .where('isEnabled', isEqualTo: true)
            .get();

        final rules = rulesSnap.docs
            .map((d) => SmsRecognitionRule.fromMap(d.data()))
            .toList();

        if (rules.isNotEmpty) {
          result[accountId] = rules;
        }
      }
    } catch (e) {
      debugPrint('[SmsRuleRepository] getAllRulesByAccount error: $e');
    }

    return result;
  }
}

class _InMemorySmsRuleRepository implements SmsRuleRepository {
  final Map<String, List<SmsRecognitionRule>> _rules;

  _InMemorySmsRuleRepository([Map<String, List<SmsRecognitionRule>>? initialRules])
      : _rules = initialRules != null ? Map.from(initialRules) : {};

  @override
  Future<List<SmsRecognitionRule>> getRules(String accountId) async =>
      _rules[accountId] ?? [];

  @override
  Future<List<SmsRecognitionRule>> getEnabledRules(String accountId) async =>
      (_rules[accountId] ?? []).where((r) => r.isEnabled).toList();

  @override
  Future<String> addRule(SmsRecognitionRule rule) async {
    final list = _rules.putIfAbsent(rule.accountId, () => []);
    final id = rule.id.isNotEmpty
        ? rule.id
        : 'rule_${DateTime.now().millisecondsSinceEpoch}';
    final withId = rule.copyWith(id: id);
    list.add(withId);
    return id;
  }

  @override
  Future<void> updateRule(SmsRecognitionRule rule) async {
    final list = _rules[rule.accountId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == rule.id);
      if (idx != -1) {
        list[idx] = rule;
      }
    }
  }

  @override
  Future<void> deleteRule(String accountId, String ruleId) async {
    _rules[accountId]?.removeWhere((r) => r.id == ruleId);
  }

  @override
  Future<Map<String, List<SmsRecognitionRule>>> getAllRulesByAccount() async =>
      Map.unmodifiable(_rules);

  @override
  Stream<List<SmsRecognitionRule>> watchRules(String accountId) =>
      Stream.value(_rules[accountId] ?? []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

