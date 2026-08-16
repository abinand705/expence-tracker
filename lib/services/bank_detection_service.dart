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
    final normalizedSender = sender.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final cLower = content.toLowerCase();

    for (final pattern in senderPatterns) {
      if (normalizedSender.contains(pattern.toUpperCase())) return true;
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
      id: 'bob',
      displayName: 'Bank of Baroda',
      senderPatterns: ['bobsms'],
      contentPatterns: ['bank of baroda', 'bob'],
      accentColor: const Color(0xFFF05A28), // Bank of Baroda orange-red
    ),
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
    BankDefinition(
      id: 'kgbank',
      displayName: 'Kerala Gramin Bank',
      senderPatterns: ['kgbank'],
      contentPatterns: ['kerala gramin bank', 'kg bank'],
      accentColor: const Color(0xFF006B3F), // Approximate green
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

  Future<void> processAllMessagesForDiscovery(Map<String, List<Message>> senderToMessages) async {
    int totalMessages = 0;
    for (final msgs in senderToMessages.values) {
      totalMessages += msgs.length;
    }
    debugPrint('[BankDetection] processMessages START: $totalMessages messages');
    
    // Group by account to avoid hammering Firestore for the same account inside a single loop
    final Map<String, Account> accountsToCreate = {};

    for (final entry in senderToMessages.entries) {
      final sender = entry.key;
      final messages = entry.value;

      for (final msg in messages) {
        final bank = identifyBank(sender, msg.text);
        if (bank == null) {
          if (ExpenseParser.parse(msg.text) != null) {
            // It looks like a financial message, but we didn't identify the bank
            // Mask sender slightly if needed, but since sender is usually 6-9 chars like 'VM-FEDERAL', we just print it.
            debugPrint('[BankDetection] unrecognized financial sender: $sender');
            debugPrint('[BankDetection] possible financial message: YES');
          }
          continue;
        }

        final last4 = ExpenseParser.extractAccountNumber(msg.text);
        if (last4 == null || last4.isEmpty) {
          debugPrint('[BankDetection] bank matched: ${bank.displayName}');
          debugPrint('[BankDetection] account suffix found: NO');
          continue;
        }

        
        final balance = ExpenseParser.extractBalance(msg.text);
        final accountId = '${bank.id}_$last4';

        if (!accountsToCreate.containsKey(accountId)) {
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
                currency: existing.currency,
                accentColor: existing.accentColor,
                isAutoDiscovered: existing.isAutoDiscovered,
                createdAt: existing.createdAt,
              );
            }
          }
        }
      }
    }

    debugPrint('[BankDetection] unique accounts discovered: ${accountsToCreate.length}');

    for (final account in accountsToCreate.values) {
      debugPrint('[BankDetection] creating account: ${account.id}');
      try {
        final bankId = account.id.split('_').first;
        await _accountRepo.cleanupLegacyAutoDiscoveredAccounts(account.id, bankId, account.accountNumber);
        await _accountRepo.addAccountIfAbsent(account);
      } catch (e) {
        debugPrint('[BankDetection] failed to process account ${account.id}: $e');
      }
    }
  }
}
