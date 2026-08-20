import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/pending_due_repository.dart';
import '../repositories/account_repository.dart';
import '../models/account.dart';

class MigrationService {
  final TransactionRepository transactionRepo;
  final PendingDueRepository pendingDueRepo;
  final AccountRepository accountRepo;
  
  MigrationService({
    required this.transactionRepo,
    required this.pendingDueRepo,
    required this.accountRepo,
  });

  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
        app: FirebaseFirestore.instance.app,
        databaseId: 'moneytrack',
      );

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> runCanonicalAccountMigration() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userDocRef = _firestore.collection('users').doc(uid);
    final userMetaRef = userDocRef.collection('metadata').doc('migration_status');

    try {
      final docSnapshot = await userMetaRef.get();
      if (docSnapshot.exists) {
        final version = docSnapshot.data()?['accountMigrationVersion'] ?? 0;
        if (version >= 1) {
          debugPrint('[MigrationService] Migration already run. Skipping.');
          return;
        }
      }

      debugPrint('[MigrationService] Starting canonical account migration...');
      
      final accounts = await accountRepo.getAccounts();
      if (accounts.isEmpty) {
        // Nothing to migrate if no accounts
        await userMetaRef.set({'accountMigrationVersion': 1}, SetOptions(merge: true));
        return;
      }

      final transactions = await transactionRepo.getTransactions();
      int txMigrated = 0;
      for (final tx in transactions) {
        if (tx.accountId != null) {
          final newId = _resolveTrueAccountId(tx.accountId!, accounts);
          if (newId != null && newId != tx.accountId) {
            // Update transaction
            await _firestore
                .collection('users')
                .doc(uid)
                .collection('transactions')
                .doc(tx.id)
                .update({'accountId': newId});
            txMigrated++;
          }
        }
      }

      final pendingDues = await pendingDueRepo.getPendingDues();
      int duesMigrated = 0;
      for (final due in pendingDues) {
        if (due.accountId != null) {
          final newId = _resolveTrueAccountId(due.accountId!, accounts);
          if (newId != null && newId != due.accountId) {
            await _firestore
                .collection('users')
                .doc(uid)
                .collection('pending_dues')
                .doc(due.id)
                .update({'accountId': newId});
            duesMigrated++;
          }
        }
      }

      debugPrint('[MigrationService] Migration complete: $txMigrated transactions, $duesMigrated pending dues migrated.');
      await userMetaRef.set({'accountMigrationVersion': 1}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[MigrationService] Migration failed: $e');
    }
  }

  String? _resolveTrueAccountId(String preliminaryAccountId, List<Account> existingAccounts) {
    // If exact match already exists, no need to migrate
    if (existingAccounts.any((a) => a.id == preliminaryAccountId)) {
      return preliminaryAccountId;
    }

    // Only migrate preliminary ids that look like bank_suffix
    if (!preliminaryAccountId.contains('_')) return null;

    final parts = preliminaryAccountId.split('_');
    final bankId = parts.first;
    final searchLast4 = parts.last;

    String normalizeSuffix(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
    final normSearchLast4 = normalizeSuffix(searchLast4);
    if (normSearchLast4.isEmpty) return null;

    final bankMatches = existingAccounts.where((a) {
      final accNormSuffix = normalizeSuffix(a.accountNumber);
      if (accNormSuffix.isEmpty) return false;
      
      bool suffixMatch = accNormSuffix == normSearchLast4 || 
                         accNormSuffix.endsWith(normSearchLast4) || 
                         normSearchLast4.endsWith(accNormSuffix);
      if (!suffixMatch) return false;
      
      final normBankId = bankId.toLowerCase();
      final normBankName = a.bankName.toLowerCase();
      return a.id.startsWith('${bankId}_') || 
             normBankName.contains(normBankId) || 
             normBankId.contains(normBankName);
    }).toList();

    if (bankMatches.length == 1) {
      return bankMatches.first.id;
    }
    
    // Return null if ambiguous or not found, so it remains unchanged.
    return null;
  }
}
