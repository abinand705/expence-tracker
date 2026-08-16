import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/sms_models.dart';
import '../repositories/account_repository.dart';
import '../utils/expense_parser.dart';

class BankDefinition {
  final String id;
  final String displayName;
  final List<String> senderPatterns;
  final List<String> contentPatterns;
  final Color accentColor;

  BankDefinition({
    required this.id,
    required this.displayName,
    required this.senderPatterns,
    required this.contentPatterns,
    required this.accentColor,
  });

  bool matches(String sender, String content) {
    final sLower = sender.toLowerCase();
    final cLower = content.toLowerCase();

    for (final pattern in senderPatterns) {
      if (sLower.contains(pattern.toLowerCase())) return true;
    }
    for (final pattern in contentPatterns) {
      if (cLower.contains(pattern.toLowerCase())) return true;
    }
    return false;
  }
}

class BankDetectionService {
  final AccountRepository _accountRepo = AccountRepository();

  // Known bank configurations
  static final List<BankDefinition> _banks = [
    BankDefinition(
      id: 'hdfc',
      displayName: 'HDFC Bank',
      senderPatterns: ['hdfcbk', 'hdfc'],
      contentPatterns: ['hdfc bank'],
      accentColor: const Color(0xFF004B8D),
    ),
    BankDefinition(
      id: 'sbi',
      displayName: 'State Bank of India',
      senderPatterns: ['sbiinb', 'sbi'],
      contentPatterns: ['state bank of india', 'sbi'],
      accentColor: const Color(0xFF1976D2),
    ),
    BankDefinition(
      id: 'icici',
      displayName: 'ICICI Bank',
      senderPatterns: ['icicib', 'icici'],
      contentPatterns: ['icici bank'],
      accentColor: const Color(0xFFF05A28),
    ),
    BankDefinition(
      id: 'axis',
      displayName: 'Axis Bank',
      senderPatterns: ['axisbk', 'axis'],
      contentPatterns: ['axis bank'],
      accentColor: const Color(0xFF97144D),
    ),
  ];

  BankDefinition? identifyBank(String sender, String content) {
    for (final bank in _banks) {
      if (bank.matches(sender, content)) {
        return bank;
      }
    }
    return null;
  }

  Future<void> processMessagesForDiscovery(List<Message> messages, String sender) async {
    debugPrint('[BankDetection] processMessages START: ${messages.length} messages');
    if (messages.isEmpty) return;
    
    // Group by account to avoid hammering Firestore for the same account inside a single loop
    final Map<String, Account> accountsToCreate = {};

    debugPrint('[BankDetection] sender detected: $sender');

    for (final msg in messages) {
      debugPrint('[BankDetection] processing message');
      final bank = identifyBank(sender, msg.text);
      if (bank == null) continue;

      final last4 = ExpenseParser.extractAccountNumber(msg.text);
      if (last4 == null || last4.isEmpty) continue;

      final balance = ExpenseParser.extractBalance(msg.text);
      
      final accountId = '${bank.id}_$last4';

      if (!accountsToCreate.containsKey(accountId)) {
        debugPrint('[BankDetection] bank detected: ${bank.displayName}');
        debugPrint('[BankDetection] last4 detected: $last4');
        debugPrint('[BankDetection] account identity: $accountId');
        
        accountsToCreate[accountId] = Account(
          id: accountId,
          name: '${bank.displayName} Account',
          bankName: bank.displayName,
          accountNumber: last4,
          accountType: 'Savings', // Default fallback
          balance: balance ?? 0.0,
          accentColor: bank.accentColor,
          isAutoDiscovered: true,
          createdAt: msg.timestamp,
        );
      } else {
        // Update balance to the latest known if we parsed one
        if (balance != null) {
          final existing = accountsToCreate[accountId]!;
          if (existing.balance == 0.0) {
            accountsToCreate[accountId] = Account(
              id: existing.id,
              name: existing.name,
              bankName: existing.bankName,
              accountNumber: existing.accountNumber,
              accountType: existing.accountType,
              balance: balance,
              accentColor: existing.accentColor,
              isAutoDiscovered: true,
              createdAt: existing.createdAt,
            );
          }
        }
      }
    }

    for (final account in accountsToCreate.values) {
      debugPrint('[BankDetection] creating account: ${account.id}');
      try {
        await _accountRepo.addAccountIfAbsent(account);
      } catch (e) {
        debugPrint('[BankDetection] error creating account: $e');
      }
    }
  }
}
