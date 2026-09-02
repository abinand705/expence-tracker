import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/sms_models.dart';
import '../repositories/account_repository.dart';
import '../utils/expense_parser.dart';
import 'sms_account_resolver.dart';

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
      senderPatterns: ['bobsms', 'bob', 'baroda'],
      contentPatterns: ['bank of baroda', 'bob', 'baroda'],
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
      senderPatterns: ['kgbank', 'keralagrameena', 'keralagramin'],
      contentPatterns: ['kerala grameena bank', 'kerala gramin bank', 'kg bank', 'kgbank'],
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
    
    // Group messages by account
    final Map<String, List<Message>> messagesByAccount = {};
    final Map<String, BankDefinition> accountBankMap = {};

    // Clean up and migrate any legacy duplicate auto-discovered accounts
    try {
      await _accountRepo.migrateAndCleanupAutoDiscoveredAccounts();
    } catch (_) {}

    // Fetch existing accounts so resolver can map messages to canonical accounts
    final existingAccounts = await _accountRepo.getAccounts();
    if (existingAccounts.isEmpty) {
      debugPrint('[BankDetection] No existing user accounts found. Skipping discovery balance updates.');
      return;
    }

    final Map<String, Account> existingAccountsMap = { for (var acc in existingAccounts) acc.id: acc };

    final resolver = SmsAccountResolver();

    for (final entry in senderToMessages.entries) {
      final sender = entry.key;
      final messages = entry.value;

      // Ensure chronological processing
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (final msg in messages) {
        final bank = identifyBank(sender, msg.text);
        if (bank == null) continue;

        final accountId = resolver.resolveAccountId(
          sender: sender,
          messageText: msg.text,
          bank: bank,
          existingAccounts: existingAccounts,
        );
        
        if (accountId == null) continue;

        messagesByAccount.putIfAbsent(accountId, () => []).add(msg);
        accountBankMap[accountId] = bank;
      }
    }

    debugPrint('[BankDetection] unique matched accounts for SMS balances: ${messagesByAccount.length}');

    for (final entry in messagesByAccount.entries) {
      final accountId = entry.key;
      final existingAcc = existingAccountsMap[accountId];
      if (existingAcc == null) continue; // Never create new accounts from SMS

      // Sort messages by timestamp descending (newest first)
      final sortedMessages = entry.value..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Find the newest valid balance
      double? newestValidBalance;
      DateTime? balanceUpdatedAt;
      
      for (final msg in sortedMessages) {
        final balance = ExpenseParser.extractBalance(msg.text);
        if (balance != null) {
          newestValidBalance = balance;
          balanceUpdatedAt = msg.timestamp;
          break; // Stop at the first (newest) valid balance
        }
      }

      if (newestValidBalance != null && balanceUpdatedAt != null) {
        // Check authority rules
        bool shouldUpdate = false;
        
        if (existingAcc.balanceSource == 'statement') {
          // Statements are more authoritative. Only update if SMS is newer than statement import
          final statementDate = existingAcc.lastStatementImportAt ?? existingAcc.balanceUpdatedAt;
          if (statementDate == null || balanceUpdatedAt.isAfter(statementDate)) {
             shouldUpdate = true;
          }
        } else {
          // If manual or sms, just use the newest one
          final currentUpdated = existingAcc.balanceUpdatedAt;
          if (currentUpdated == null || balanceUpdatedAt.isAfter(currentUpdated)) {
             shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          debugPrint('[BankDetection] updating balance for account $accountId from SMS ($newestValidBalance)');
          final updatedAccount = Account(
            id: existingAcc.id,
            name: existingAcc.name,
            bankName: existingAcc.bankName,
            accountNumber: existingAcc.accountNumber,
            accountType: existingAcc.accountType,
            balance: existingAcc.balance, // legacy
            currentBalance: newestValidBalance,
            balanceSource: 'sms',
            balanceUpdatedAt: balanceUpdatedAt,
            lastStatementImportAt: existingAcc.lastStatementImportAt,
            currency: existingAcc.currency,
            accentColor: existingAcc.accentColor,
            isAutoDiscovered: existingAcc.isAutoDiscovered,
            createdAt: existingAcc.createdAt,
          );
          await _accountRepo.updateAccount(updatedAccount);
        }
      }
    }
  }
}
