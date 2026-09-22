// ARCHITECTURE NOTE: BankDetectionService.identifyBank() is used for
// informational/UI purposes only (e.g. bank name suggestions in account
// creation). It is NO LONGER used for SMS transaction account matching.
//
// All SMS → account matching now goes through:
//   SmsAccountIndex → AccountSmsMatcher → SmsRecognitionRule
//
// processAllMessagesForDiscovery() is deprecated and not called from the
// SMS scanning pipeline.
import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/sms_models.dart';
import '../repositories/account_repository.dart';
import '../utils/expense_parser.dart';
import 'sms_account_resolver.dart';

/// Normalized bank identifier representing a stable bank entity (e.g. KGBANK, HDFCBK, SBIINB)
/// extracted from varied SMS headers (e.g. VK-KGBANK-S, JD-KGBANK-S, AD-KGBANK-S).
class BankIdentifier {
  final String value;
  final String bankName;
  final double confidence;

  const BankIdentifier({
    required this.value,
    required this.bankName,
    this.confidence = 0.95,
  });

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankIdentifier &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

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
    BankDefinition(
      id: 'canara',
      displayName: 'Canara Bank',
      senderPatterns: ['canbnk', 'canara', 'cnrbk', 'cnrsms', 'cbssms'],
      contentPatterns: ['canara bank', 'canara'],
      accentColor: const Color(0xFF005DAA), // Canara Bank blue
    ),
    BankDefinition(
      id: 'pnb',
      displayName: 'Punjab National Bank',
      senderPatterns: ['pnbsms', 'pnb'],
      contentPatterns: ['punjab national bank', 'pnb'],
      accentColor: const Color(0xFFA20C32),
    ),
    BankDefinition(
      id: 'kotak',
      displayName: 'Kotak Mahindra Bank',
      senderPatterns: ['kotakb', 'kotak'],
      contentPatterns: ['kotak bank', 'kotak mahindra', 'kotak'],
      accentColor: const Color(0xFFED1C24),
    ),
    BankDefinition(
      id: 'union',
      displayName: 'Union Bank of India',
      senderPatterns: ['unionb', 'uboi', 'union'],
      contentPatterns: ['union bank of india', 'union bank', 'uboi'],
      accentColor: const Color(0xFF003874),
    ),
    BankDefinition(
      id: 'federal',
      displayName: 'Federal Bank',
      senderPatterns: ['fedbnk', 'federal', 'fdrb'],
      contentPatterns: ['federal bank'],
      accentColor: const Color(0xFF003366),
    ),
    BankDefinition(
      id: 'yesbank',
      displayName: 'Yes Bank',
      senderPatterns: ['yesbnk', 'yesbank'],
      contentPatterns: ['yes bank'],
      accentColor: const Color(0xFF0B3B60),
    ),
    BankDefinition(
      id: 'idfc',
      displayName: 'IDFC First Bank',
      senderPatterns: ['idfcbk', 'idfc'],
      contentPatterns: ['idfc first bank', 'idfc bank', 'idfc'],
      accentColor: const Color(0xFF990000),
    ),
    BankDefinition(
      id: 'indusind',
      displayName: 'IndusInd Bank',
      senderPatterns: ['indusb', 'indusind'],
      contentPatterns: ['indusind bank'],
      accentColor: const Color(0xFF800000),
    ),
  ];

  static final Set<String> _verifiedBankIdentifiers = {};

  /// Registers an additional bank identifier as verified (e.g. for testing or dynamic discovery).
  static void registerVerifiedBankIdentifier(String id) {
    final clean = id.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.isNotEmpty) {
      _verifiedBankIdentifiers.add(clean);
    }
  }

  /// Clears dynamically registered bank identifiers.
  static void resetVerifiedBankIdentifiers() {
    _verifiedBankIdentifiers.clear();
  }

  /// Checks if [candidate] is recognized as a known or verified bank.
  static bool isKnownOrVerifiedBank(String candidate) {
    final candUpper = candidate.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (candUpper.isEmpty) return false;
    if (_verifiedBankIdentifiers.contains(candUpper)) return true;
    for (final bank in _banks) {
      if (bank.id.toUpperCase() == candUpper) return true;
      for (final pattern in bank.senderPatterns) {
        final patUpper = pattern.toUpperCase();
        if (candUpper == patUpper || candUpper.contains(patUpper) || patUpper.contains(candUpper)) {
          return true;
        }
      }
    }
    return false;
  }

  BankDefinition? identifyBank(String sender, String content) {
    for (final bank in _banks) {
      if (bank.matches(sender, content)) {
        return bank;
      }
    }
    return null;
  }

  /// Extracts a normalized stable bank identifier from an SMS sender string.
  ///
  /// Examples:
  /// - `VK-KGBANK-S` -> `KGBANK`
  /// - `JD-KGBANK-S` -> `KGBANK`
  /// - `AD-KGBANK-S` -> `KGBANK`
  /// - `VM-KGBANK-S` -> `KGBANK`
  /// - `VK-HDFCBK-S` -> `HDFCBK`
  /// - `AD-ABCXYZ-S` -> `ABCXYZ` (when verified)
  /// - `KGBANK` -> `KGBANK`
  ///
  /// Returns `null` for numeric phone numbers or unverified sender headers.
  static String? extractBankIdentifier(String sender) {
    final trimmed = sender.trim();
    if (trimmed.isEmpty) return null;

    // Reject personal phone numbers or pure numeric shortcodes
    if (RegExp(r'^\+?[0-9]+$').hasMatch(trimmed)) return null;
    if (trimmed.length < 3) return null;

    // Check for delimiter-separated formats (e.g. VK-KGBANK-S, JD-KGBANK, BZ_AXISBK)
    if (trimmed.contains('-') || trimmed.contains('_')) {
      final parts = trimmed.split(RegExp(r'[-_]'));
      if (parts.length >= 2) {
        // Standard TRAI format: 2-letter circle prefix (e.g. VK, JD, AD, VM, BZ)
        if (parts[0].length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(parts[0])) {
          final candidate = parts[1].toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          if (candidate.length >= 3 && candidate.length <= 10 && isKnownOrVerifiedBank(candidate)) {
            return candidate;
          }
        }
        // Suffix circle format: KGBANK-VK
        if (parts[1].length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(parts[1])) {
          final candidate = parts[0].toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          if (candidate.length >= 3 && candidate.length <= 10 && isKnownOrVerifiedBank(candidate)) {
            return candidate;
          }
        }
        // Check any part against known bank sender patterns
        for (final part in parts) {
          final cleanPart = part.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          if (cleanPart.length >= 3 && isKnownOrVerifiedBank(cleanPart)) {
            return cleanPart;
          }
        }
      }
    }

    // No delimiter: e.g. KGBANK, VKKGBANK, HDFCBK
    final clean = trimmed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Check if starts with 2 letters circle prefix (e.g. VKKGBANK, ADHDFCBK)
    if (clean.length >= 6) {
      final withoutCircle = clean.substring(2);
      if (isKnownOrVerifiedBank(withoutCircle)) {
        return withoutCircle;
      }
      for (final bank in _banks) {
        for (final pattern in bank.senderPatterns) {
          if (withoutCircle == pattern.toUpperCase() || withoutCircle.startsWith(pattern.toUpperCase())) {
            return pattern.toUpperCase();
          }
        }
      }
    }

    // Direct match against known or verified banks
    if (isKnownOrVerifiedBank(clean)) {
      return clean;
    }

    for (final bank in _banks) {
      for (final pattern in bank.senderPatterns) {
        if (clean == pattern.toUpperCase() || clean.contains(pattern.toUpperCase())) {
          return pattern.toUpperCase();
        }
      }
    }

    return null;
  }

  /// Detects a BankIdentifier model containing confidence and display name.
  static BankIdentifier? detectBankIdentifier(String sender, [String? content]) {
    final value = extractBankIdentifier(sender);
    if (value == null) return null;

    final normVal = value.toUpperCase();
    for (final bank in _banks) {
      final matchesSender = bank.senderPatterns.any((p) =>
          normVal == p.toUpperCase() ||
          normVal.contains(p.toUpperCase()) ||
          p.toUpperCase().contains(normVal));
      final matchesContent = content != null &&
          bank.contentPatterns.any((p) => content.toLowerCase().contains(p.toLowerCase()));

      if (matchesSender || matchesContent) {
        return BankIdentifier(
          value: value,
          bankName: bank.displayName,
          confidence: 0.95,
        );
      }
    }

    // Unknown bank code from verified TRAI format (e.g. AD-ABCXYZ-S)
    return BankIdentifier(
      value: value,
      bankName: value,
      confidence: 0.75,
    );
  }

  /// @Deprecated — NOT called from SMS scanning pipeline.
  ///
  /// SMS account matching now uses SmsAccountIndex + AccountSmsMatcher.
  /// This method is kept only for potential future informational/diagnostic use.
  /// It does NOT create accounts (already enforced inside).
  @Deprecated(
    'Not used in SMS scanning pipeline. Use SmsAccountIndex.build() + '
    'AccountSmsMatcher.match() for account resolution during SMS import.',
  )
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
