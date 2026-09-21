import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/discovered_bank_account.dart';
import '../models/sms_models.dart';
import '../repositories/account_discovery_repository.dart';
import '../repositories/account_repository.dart';
import '../utils/expense_parser.dart';
import 'bank_detection_service.dart';

/// Service that analyzes SMS messages to discover potential bank accounts.
///
/// Flow:
/// SMS messages
///   ↓
/// Bank Detection (identifyBank)
///   ↓
/// Account Number Extraction (extractAccountNumber)
///   ↓
/// Grouping by (bankCode, accountLast4)
///   ↓
/// Filter against existing user accounts and ignored discoveries
///   ↓
/// Returns list of DiscoveredBankAccount candidates for user confirmation.
class BankAccountDiscoveryService {
  final AccountDiscoveryRepository _discoveryRepo;
  final AccountRepository _accountRepo;
  final BankDetectionService _bankDetectionService;

  BankAccountDiscoveryService({
    AccountDiscoveryRepository? discoveryRepo,
    AccountRepository? accountRepo,
    BankDetectionService? bankDetectionService,
  })  : _discoveryRepo = discoveryRepo ?? AccountDiscoveryRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _bankDetectionService = bankDetectionService ?? BankDetectionService();

  /// Scans conversations and returns newly discovered bank account candidates.
  Future<List<DiscoveredBankAccount>> discoverAccounts({
    required List<Conversation> conversations,
    List<Account>? existingAccounts,
  }) async {
    final userAccounts = existingAccounts ?? await _accountRepo.getAccounts();
    final existingDiscoveries = await _discoveryRepo.getDiscoveries();
    final discoveryMap = {
      for (final d in existingDiscoveries) d.discoveryId: d
    };

    // Temporary grouping: discoveryId -> CandidateGroup
    final Map<String, _CandidateGroup> groups = {};

    for (final conv in conversations) {
      final sender = conv.senderName;
      for (final msg in conv.messages) {
        final text = msg.text;

        // 1. Identify bank
        final bankDef = _bankDetectionService.identifyBank(sender, text);
        final detectedBankName = bankDef?.displayName ?? ExpenseParser.extractBankName(text);
        if (detectedBankName == null || detectedBankName.isEmpty) {
          continue; // No identifiable bank
        }

        final bankCode = bankDef?.id ??
            detectedBankName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

        // 2. Extract account suffix (e.g. XX1234, 1234)
        final rawAccount = ExpenseParser.extractAccountNumber(text);
        if (rawAccount == null || rawAccount.isEmpty) {
          // Section 17: Do not suggest accounts without an account identifier
          continue;
        }

        final digits = rawAccount.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length < 3) {
          continue; // Insufficient identifier digits
        }
        final accountLast4 = digits.length >= 4
            ? digits.substring(digits.length - 4)
            : digits;

        // 3. Unique discovery key: bankCode + accountLast4
        final discoveryId = '${bankCode}_$accountLast4';

        // 4. Extract balance if available
        final balance = ExpenseParser.extractBalance(text);

        // 5. Add to candidate group
        final group = groups.putIfAbsent(
          discoveryId,
          () => _CandidateGroup(
            discoveryId: discoveryId,
            bankName: detectedBankName,
            bankCode: bankCode,
            accountLast4: accountLast4,
          ),
        );

        group.addMessage(
          sender: sender,
          text: text,
          timestamp: msg.timestamp,
          balance: balance,
        );
      }
    }

    final List<DiscoveredBankAccount> candidates = [];

    for (final group in groups.values) {
      // Check against existing accounts
      if (_matchesExistingAccount(group.bankName, group.accountLast4, userAccounts)) {
        debugPrint(
            '[BankAccountDiscovery] Skipping ${group.bankName} ••••${group.accountLast4}: already configured as user account.');
        continue;
      }

      // Check against existing discovery state
      final existingDisc = discoveryMap[group.discoveryId];
      if (existingDisc != null) {
        if (existingDisc.state == 'ignored' || existingDisc.state == 'initialized') {
          continue; // User explicitly ignored or already initialized
        }
      }

      final confidence = _calculateConfidence(group);
      if (confidence < 0.7) {
        continue;
      }

      final candidate = DiscoveredBankAccount(
        discoveryId: group.discoveryId,
        bankName: group.bankName,
        bankCode: group.bankCode,
        accountLast4: group.accountLast4,
        maskedAccountNumber: '••••${group.accountLast4}',
        accountType: group.inferredAccountType,
        detectedSenderIds: group.senderIds.toList(),
        detectedMessagePatterns: group.detectedPatterns.toList(),
        detectedBalance: group.latestBalance,
        detectedCurrency: 'INR',
        messageCount: group.messageCount,
        firstSeen: group.firstSeen,
        lastSeen: group.lastSeen,
        confidence: confidence,
        source: 'sms',
        state: existingDisc?.state ?? 'discovered',
        sampleMessages: group.sampleMessages,
      );

      candidates.add(candidate);
    }

    debugPrint(
        '[BankAccountDiscovery] Discovered ${candidates.length} candidate bank accounts.');
    return candidates;
  }

  /// Checks if a candidate already matches an existing user account.
  bool _matchesExistingAccount(
    String candidateBank,
    String candidateLast4,
    List<Account> existingAccounts,
  ) {
    final normCandidateBank = candidateBank.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final candLast3 = candidateLast4.length >= 3
        ? candidateLast4.substring(candidateLast4.length - 3)
        : candidateLast4;

    for (final acc in existingAccounts) {
      final normAccBank = acc.bankName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final bankMatches = normCandidateBank.contains(normAccBank) ||
          normAccBank.contains(normCandidateBank);

      final accDigits = acc.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
      bool numberMatches = false;
      if (accDigits.isNotEmpty) {
        if (accDigits.endsWith(candidateLast4) || candidateLast4.endsWith(accDigits)) {
          numberMatches = true;
        } else if (acc.last3Digits != null && acc.last3Digits == candLast3) {
          numberMatches = true;
        }
      }

      if (bankMatches && numberMatches) {
        return true;
      }
    }
    return false;
  }

  /// Calculates discovery confidence score (0.0 to 1.0).
  double _calculateConfidence(_CandidateGroup group) {
    double score = 0.70;

    // Has identifiable bank + last 4 digits
    if (group.accountLast4.length >= 4) {
      score += 0.10;
    } else if (group.accountLast4.length == 3) {
      score += 0.05;
    }

    // Multiple messages increase confidence
    if (group.messageCount >= 3) {
      score += 0.10;
    } else if (group.messageCount >= 2) {
      score += 0.05;
    }

    // Has detected balance
    if (group.latestBalance != null) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }
}

class _CandidateGroup {
  final String discoveryId;
  final String bankName;
  final String bankCode;
  final String accountLast4;

  final Set<String> senderIds = {};
  final Set<String> detectedPatterns = {};
  final List<String> sampleMessages = [];

  double? latestBalance;
  DateTime? latestBalanceDate;

  int messageCount = 0;
  late DateTime firstSeen;
  late DateTime lastSeen;

  _CandidateGroup({
    required this.discoveryId,
    required this.bankName,
    required this.bankCode,
    required this.accountLast4,
  });

  String get inferredAccountType {
    for (final msg in sampleMessages) {
      final lower = msg.toLowerCase();
      if (lower.contains('credit card') || lower.contains('card ending')) {
        return 'Credit Card';
      }
      if (lower.contains('current a/c') || lower.contains('current account')) {
        return 'Current';
      }
    }
    return 'Savings';
  }

  void addMessage({
    required String sender,
    required String text,
    required DateTime timestamp,
    double? balance,
  }) {
    senderIds.add(sender);
    messageCount++;

    if (messageCount == 1) {
      firstSeen = timestamp;
      lastSeen = timestamp;
    } else {
      if (timestamp.isBefore(firstSeen)) firstSeen = timestamp;
      if (timestamp.isAfter(lastSeen)) lastSeen = timestamp;
    }

    // Extract patterns (e.g. XX1234, ending 1234, bank keywords)
    detectedPatterns.add('XX$accountLast4');
    detectedPatterns.add('ending $accountLast4');
    detectedPatterns.add(bankName);

    // Track balance
    if (balance != null) {
      if (latestBalanceDate == null || timestamp.isAfter(latestBalanceDate!)) {
        latestBalance = balance;
        latestBalanceDate = timestamp;
      }
    }

    // Store masked sample messages for preview
    if (sampleMessages.length < 3) {
      final masked = _maskSensitive(text);
      if (!sampleMessages.contains(masked)) {
        sampleMessages.add(masked);
      }
    }
  }

  String _maskSensitive(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?:A/c|acct|account|card)\s*(?:no\.?|num)?\s*[:=\-]?\s*([xX\*\.\s-]*\d{3,})',
          caseSensitive: false),
      (m) => 'A/c ••••$accountLast4',
    );
  }
}
