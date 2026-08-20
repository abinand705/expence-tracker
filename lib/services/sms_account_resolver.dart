import '../utils/expense_parser.dart';
import 'bank_detection_service.dart';

class SmsAccountResolver {
  // Map of thread/sender ID to the set of known explicit account numbers found in that thread
  final Map<String, Set<String>> _threadKnownAccounts = {};

  /// Resolves the account ID based on explicit match or contextual history.
  /// Returns a string like 'bankId_accountSuffix' if successful, or null if missing/ambiguous.
  String? resolveAccountId({
    required String sender,
    required String messageText,
    required BankDefinition bank,
  }) {
    String? explicitAccount = ExpenseParser.extractAccountNumber(messageText);

    if (explicitAccount != null && explicitAccount.isNotEmpty) {
      _threadKnownAccounts.putIfAbsent(sender, () => {}).add(explicitAccount);
      return '${bank.id}_$explicitAccount';
    }

    // No explicit account found in this message. Attempt contextual resolution.
    final knownAccounts = _threadKnownAccounts[sender];
    if (knownAccounts != null && knownAccounts.length == 1) {
      // Safe to resolve: there is exactly one account associated with this thread.
      return '${bank.id}_${knownAccounts.first}';
    }

    // Unsafe to resolve: either 0 known accounts, or >1 known accounts (ambiguous).
    return null;
  }
}
