// ARCHITECTURE NOTE: SmsAccountResolver is NO LONGER used for SMS transaction
// account matching. Its resolveAccount() and resolveAccountId() methods are
// kept for use in BANK STATEMENT PARSING (BankStatementService) only.
//
// For SMS scanning, account matching is done by:
//   SmsAccountIndex → AccountSmsMatcher → SmsRecognitionRule
//
// The resolver's static utility methods (normalizeBankIdentifier,
// extractLast3Digits) remain available as shared utilities.
import '../models/account.dart';
import '../utils/expense_parser.dart';
import 'bank_detection_service.dart';

class SmsAccountResolver {
  // Map of thread/sender ID to the set of known explicit account numbers found in that thread
  final Map<String, Set<String>> _threadKnownAccounts = {};

  static String? extractLast3Digits(String? input) {
    if (input == null) return null;
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 3) return null;
    return digits.substring(digits.length - 3);
  }

  static String normalizeBankIdentifier(String input) {
    final clean = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.contains('baroda') || clean.contains('bob')) return 'bob';
    if (clean.contains('hdfc')) return 'hdfc';
    if (clean.contains('statebank') || clean.contains('sbi')) return 'sbi';
    if (clean.contains('icici')) return 'icici';
    if (clean.contains('axis')) return 'axis';
    if (clean.contains('keralagramin') || clean.contains('keralagrameena') || clean.contains('kgbank') || clean.contains('kgb') || clean.contains('grameena') || clean.contains('gramin')) return 'kgbank';
    return clean;
  }

  static bool bankMatches(Account account, String? bankIdOrName) {
    if (bankIdOrName == null || bankIdOrName.trim().isEmpty) return false;
    final targetNorm = normalizeBankIdentifier(bankIdOrName);
    
    final accBankNorm = normalizeBankIdentifier(account.bankName);
    final accNameNorm = normalizeBankIdentifier(account.name);
    final accIdNorm = normalizeBankIdentifier(account.id);
    
    return accBankNorm == targetNorm || 
           accNameNorm == targetNorm || 
           accIdNorm.startsWith('${targetNorm}_') ||
           accIdNorm == targetNorm ||
           accBankNorm.contains(targetNorm) ||
           targetNorm.contains(accBankNorm);
  }

  /// Single source of truth for 3-digit account matching against user's existing accounts.
  /// Returns the matched Account.id, or null if ambiguous or no match.
  String? resolveAccount({
    String? bankIdOrName,
    String? rawAccountOrSuffix,
    required List<Account> accounts,
  }) {
    if (accounts.isEmpty || rawAccountOrSuffix == null) return null;
    final normDigits = rawAccountOrSuffix.replaceAll(RegExp(r'[^0-9]'), '');
    if (normDigits.length < 3) return null;

    final smsLast3 = normDigits.substring(normDigits.length - 3);

    // 1. If bank is identified from SMS:
    if (bankIdOrName != null && bankIdOrName.trim().isNotEmpty) {
      final bankAccounts = accounts.where((a) => bankMatches(a, bankIdOrName)).toList();
      if (bankAccounts.isEmpty) {
        return null; // Bank was identified, but user has no accounts for this bank
      }

      // Exact full account number match
      final fullMatches = bankAccounts.where((a) {
        final accNorm = a.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
        return accNorm.isNotEmpty && accNorm == normDigits;
      }).toList();
      if (fullMatches.length == 1) {
        return fullMatches.first.id;
      } else if (fullMatches.length > 1) {
        return null;
      }

      // 5+ digit suffix match
      if (normDigits.length >= 5) {
        final d5 = normDigits.substring(normDigits.length - 5);
        final d5Matches = bankAccounts.where((a) {
          final accNorm = a.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
          return accNorm.length >= 5 && accNorm.endsWith(d5);
        }).toList();
        if (d5Matches.length == 1) {
          return d5Matches.first.id;
        } else if (d5Matches.length > 1) {
          return null;
        }
      }

      // 4-digit suffix match
      if (normDigits.length >= 4) {
        final d4 = normDigits.substring(normDigits.length - 4);
        final d4Matches = bankAccounts.where((a) {
          final accNorm = a.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
          return accNorm.length >= 4 && accNorm.endsWith(d4);
        }).toList();
        if (d4Matches.length == 1) {
          return d4Matches.first.id;
        } else if (d4Matches.length > 1) {
          return null;
        }
      }

      // 3-digit suffix match
      final d3Matches = bankAccounts.where((a) {
        final accLast3 = extractLast3Digits(a.accountNumber) ?? 
                         extractLast3Digits(a.name) ?? 
                         extractLast3Digits(a.id);
        return accLast3 == smsLast3;
      }).toList();

      if (d3Matches.length == 1) {
        return d3Matches.first.id;
      }

      // Ambiguous (>1) or no match (0)
      return null;
    }

    // 2. If NO bank was identified from SMS (bank is unavailable):
    // Last 3 digits only, allowed ONLY if exactly one existing account matches globally.
    final globalMatches = accounts.where((a) {
      final accLast3 = extractLast3Digits(a.accountNumber) ?? 
                       extractLast3Digits(a.name) ?? 
                       extractLast3Digits(a.id);
      return accLast3 == smsLast3;
    }).toList();

    if (globalMatches.length == 1) {
      return globalMatches.first.id;
    }

    // Ambiguous (>1 matches) or no match (0 matches) -> return null (NEVER create account or guess)
    return null;
  }

  /// Resolves the account ID based on explicit match or contextual history.
  /// Returns canonical Account.id if matched to an existing account, or null if no match/ambiguous.
  String? resolveAccountId({
    required String sender,
    required String messageText,
    required BankDefinition bank,
    List<Account>? existingAccounts,
  }) {
    if (existingAccounts == null || existingAccounts.isEmpty) return null;

    String? explicitAccount = ExpenseParser.extractAccountNumber(messageText);

    if (explicitAccount != null && explicitAccount.isNotEmpty) {
      _threadKnownAccounts.putIfAbsent(sender, () => {}).add(explicitAccount);

      return resolveAccount(
        bankIdOrName: bank.id,
        rawAccountOrSuffix: explicitAccount,
        accounts: existingAccounts,
      );
    }

    // Contextual resolution from SMS thread
    final knownAccounts = _threadKnownAccounts[sender];
    if (knownAccounts != null && knownAccounts.length == 1) {
      return resolveAccount(
        bankIdOrName: bank.id,
        rawAccountOrSuffix: knownAccounts.first,
        accounts: existingAccounts,
      );
    }

    return null;
  }
}
