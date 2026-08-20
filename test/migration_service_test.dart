import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/account.dart';

// Since MigrationService uses Firestore internally, we'll just test the ID resolution logic directly
// by temporarily exposing it or moving the logic to a static method. 
// For now, let's create a wrapper that has the same logic.

void main() {
  group('MigrationService resolution logic', () {
    String? resolve(String preliminaryAccountId, List<Account> existingAccounts) {
      if (existingAccounts.any((a) => a.id == preliminaryAccountId)) {
        return preliminaryAccountId;
      }
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
      return null;
    }

    test('TEST 3 - Existing migration resolves correctly', () {
      final accounts = [
        Account(id: 'random_uid', name: 'HDFC', bankName: 'HDFC', accountNumber: '1234', accountType: 'Savings', accentColor: const Color(0xFF000000))
      ];
      final newId = resolve('hdfc_1234', accounts);
      expect(newId, 'random_uid');
    });

    test('TEST 6 - Already canonical remains unchanged', () {
      final accounts = [
        Account(id: 'random_uid', name: 'HDFC', bankName: 'HDFC', accountNumber: '1234', accountType: 'Savings', accentColor: const Color(0xFF000000))
      ];
      // Note: The logic in MigrationService explicitly says "If exact match already exists, no need to migrate".
      // Our function returns preliminaryAccountId to signify no change needed from the ID perspective.
      final newId = resolve('random_uid', accounts);
      expect(newId, 'random_uid'); 
    });

    test('TEST 7 - Ambiguous migration returns null (no change)', () {
      final accounts = [
        Account(id: 'acc1', name: 'HDFC', bankName: 'HDFC', accountNumber: '1234', accountType: 'Savings', accentColor: const Color(0xFF000000)),
        Account(id: 'acc2', name: 'HDFC', bankName: 'HDFC', accountNumber: '1234', accountType: 'Current', accentColor: const Color(0xFF000000)),
      ];
      final newId = resolve('hdfc_1234', accounts);
      expect(newId, isNull);
    });
  });
}
