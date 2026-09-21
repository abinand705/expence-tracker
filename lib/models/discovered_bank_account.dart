import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a bank account candidate discovered automatically from bank SMS messages.
///
/// Discovered accounts are suggestions shown to the user. They are NEVER treated
/// as authoritative user accounts until the user explicitly confirms and initializes them.
class DiscoveredBankAccount {
  final String discoveryId;
  final String bankName;
  final String bankCode;
  final String accountLast4;
  final String maskedAccountNumber;
  final String accountType; // Savings, Current, Credit Card, Other
  final List<String> detectedSenderIds;
  final List<String> detectedMessagePatterns;
  final double? detectedBalance;
  final String detectedCurrency;
  final int messageCount;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final double confidence; // 0.0 to 1.0
  final String source; // 'sms'
  final String state; // 'discovered', 'suggested', 'dismissed', 'ignored', 'initialized'
  final List<String> sampleMessages;

  const DiscoveredBankAccount({
    required this.discoveryId,
    required this.bankName,
    required this.bankCode,
    required this.accountLast4,
    required this.maskedAccountNumber,
    this.accountType = 'Savings',
    this.detectedSenderIds = const [],
    this.detectedMessagePatterns = const [],
    this.detectedBalance,
    this.detectedCurrency = 'INR',
    this.messageCount = 1,
    required this.firstSeen,
    required this.lastSeen,
    this.confidence = 0.9,
    this.source = 'sms',
    this.state = 'discovered',
    this.sampleMessages = const [],
  });

  /// True if the discovery has enough evidence to be suggested to the user.
  bool get isSuggestible =>
      confidence >= 0.7 &&
      accountLast4.isNotEmpty &&
      state != 'ignored' &&
      state != 'initialized';

  DiscoveredBankAccount copyWith({
    String? discoveryId,
    String? bankName,
    String? bankCode,
    String? accountLast4,
    String? maskedAccountNumber,
    String? accountType,
    List<String>? detectedSenderIds,
    List<String>? detectedMessagePatterns,
    double? detectedBalance,
    String? detectedCurrency,
    int? messageCount,
    DateTime? firstSeen,
    DateTime? lastSeen,
    double? confidence,
    String? source,
    String? state,
    List<String>? sampleMessages,
  }) {
    return DiscoveredBankAccount(
      discoveryId: discoveryId ?? this.discoveryId,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      accountLast4: accountLast4 ?? this.accountLast4,
      maskedAccountNumber: maskedAccountNumber ?? this.maskedAccountNumber,
      accountType: accountType ?? this.accountType,
      detectedSenderIds: detectedSenderIds ?? this.detectedSenderIds,
      detectedMessagePatterns:
          detectedMessagePatterns ?? this.detectedMessagePatterns,
      detectedBalance: detectedBalance ?? this.detectedBalance,
      detectedCurrency: detectedCurrency ?? this.detectedCurrency,
      messageCount: messageCount ?? this.messageCount,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      state: state ?? this.state,
      sampleMessages: sampleMessages ?? this.sampleMessages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'discoveryId': discoveryId,
      'bankName': bankName,
      'bankCode': bankCode,
      'accountLast4': accountLast4,
      'maskedAccountNumber': maskedAccountNumber,
      'accountType': accountType,
      'detectedSenderIds': detectedSenderIds,
      'detectedMessagePatterns': detectedMessagePatterns,
      'detectedBalance': detectedBalance,
      'detectedCurrency': detectedCurrency,
      'messageCount': messageCount,
      'firstSeen': Timestamp.fromDate(firstSeen),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'confidence': confidence,
      'source': source,
      'state': state,
      'sampleMessages': sampleMessages,
    };
  }

  factory DiscoveredBankAccount.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    final now = DateTime.now();

    return DiscoveredBankAccount(
      discoveryId: map['discoveryId'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      bankCode: map['bankCode'] as String? ?? '',
      accountLast4: map['accountLast4'] as String? ?? '',
      maskedAccountNumber: map['maskedAccountNumber'] as String? ??
          '••••${map['accountLast4'] ?? ''}',
      accountType: map['accountType'] as String? ?? 'Savings',
      detectedSenderIds: parseList(map['detectedSenderIds']),
      detectedMessagePatterns: parseList(map['detectedMessagePatterns']),
      detectedBalance: (map['detectedBalance'] as num?)?.toDouble(),
      detectedCurrency: map['detectedCurrency'] as String? ?? 'INR',
      messageCount: (map['messageCount'] as num?)?.toInt() ?? 1,
      firstSeen: parseDate(map['firstSeen'], now),
      lastSeen: parseDate(map['lastSeen'], now),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.9,
      source: map['source'] as String? ?? 'sms',
      state: map['state'] as String? ?? 'discovered',
      sampleMessages: parseList(map['sampleMessages']),
    );
  }
}
