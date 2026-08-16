import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bank_statement.dart';

class StatementRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addStatement(String uid, BankStatement statement) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('statements')
        .doc(statement.id)
        .set(statement.toMap());
  }

  Future<List<BankStatement>> getStatements(String uid, String accountId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('statements')
        .where('accountId', isEqualTo: accountId)
        .orderBy('importedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => BankStatement.fromMap(doc.data())).toList();
  }
}
