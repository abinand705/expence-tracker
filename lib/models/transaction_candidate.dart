import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'transaction.dart';

/// Represents a parsed transaction candidate from an SMS message.
class TransactionCandidate {
  final String candidateId;
  final String? sourceSmsId;
  final String sender;
  final DateTime receivedAt;
  final DateTime transactionDate;
  final double amount;
  final TransactionType transactionType;
  final String? merchant;
  final String? accountId;
  final String? accountLast4;
  final String? bankName;
  final String? referenceNumber;
  final String? upiReference;
  final double? balance;
  final String currency;
  final String rawMessageHash;
  final double parserConfidence;
  final String normalizedMerchant;
  final String normalizedDescription;
  final String lifecycleState; // 'initiated', 'successful', 'failed', 'reversed', 'refund', 'debited', 'credited', 'informational'
  final String? rawMessage; // Retained for local review/debugging only, NEVER sent to AI

  const TransactionCandidate({
    required this.candidateId,
    this.sourceSmsId,
    required this.sender,
    required this.receivedAt,
    required this.transactionDate,
    required this.amount,
    this.transactionType = TransactionType.expense,
    this.merchant,
    this.accountId,
    this.accountLast4,
    this.bankName,
    this.referenceNumber,
    this.upiReference,
    this.balance,
    this.currency = 'INR',
    required this.rawMessageHash,
    this.parserConfidence = 1.0,
    required this.normalizedMerchant,
    required this.normalizedDescription,
    this.lifecycleState = 'successful',
    this.rawMessage,
  });

  /// Factory to construct a candidate from parsed data and raw SMS.
  factory TransactionCandidate.fromParsed({
    required String text,
    required String senderName,
    required DateTime receivedAt,
    required double amount,
    required TransactionType type,
    String? sourceSmsId,
    String? merchant,
    String? accountId,
    String? accountLast4,
    String? bankName,
    String? referenceNumber,
    String? upiReference,
    double? balance,
    DateTime? txDate,
    double parserConfidence = 1.0,
  }) {
    final rawHash = sha256.convert(utf8.encode(text.trim())).toString();
    final normMerchant = _normalizeMerchant(merchant);
    final normDesc = _normalizeDescription(text);
    final lifecycle = _detectLifecycle(text, type);
    final effectiveDate = txDate ?? receivedAt;

    final candidateId = 'cand_${rawHash.substring(0, 16)}_${effectiveDate.millisecondsSinceEpoch}';

    return TransactionCandidate(
      candidateId: candidateId,
      sourceSmsId: sourceSmsId,
      sender: senderName,
      receivedAt: receivedAt,
      transactionDate: effectiveDate,
      amount: amount,
      transactionType: type,
      merchant: merchant,
      accountId: accountId,
      accountLast4: accountLast4,
      bankName: bankName,
      referenceNumber: referenceNumber,
      upiReference: upiReference,
      balance: balance,
      currency: 'INR',
      rawMessageHash: rawHash,
      parserConfidence: parserConfidence,
      normalizedMerchant: normMerchant,
      normalizedDescription: normDesc,
      lifecycleState: lifecycle,
      rawMessage: text,
    );
  }

  static String _normalizeMerchant(String? merchant) {
    if (merchant == null) return '';
    var m = merchant.trim().toLowerCase();
    // Normalize common variations like "amazon pay", "amzn mktp", "amazon india" -> "amazon"
    m = m.replaceAll(RegExp(r'\s+'), ' ');
    if (m.contains('amazon') || m.contains('amzn')) return 'amazon';
    if (m.contains('flipkart') || m.contains('fkrt')) return 'flipkart';
    if (m.contains('swiggy')) return 'swiggy';
    if (m.contains('zomato')) return 'zomato';
    if (m.contains('uber')) return 'uber';
    if (m.contains('ola')) return 'ola';
    return m;
  }

  static String _normalizeDescription(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _detectLifecycle(String text, TransactionType type) {
    final lower = text.toLowerCase();
    if (lower.contains('reversed') || lower.contains('reversal') || lower.contains('chargeback')) {
      return 'reversed';
    }
    if (lower.contains('refund') || lower.contains('refunded')) {
      return 'refund';
    }
    if (lower.contains('failed') || lower.contains('declined') || lower.contains('unsuccessful')) {
      return 'failed';
    }
    if (lower.contains('initiated') || lower.contains('in progress') || lower.contains('processing')) {
      return 'initiated';
    }
    if (lower.contains('successful') || lower.contains('success') || lower.contains('completed')) {
      return 'successful';
    }
    if (type == TransactionType.income) {
      return 'credited';
    }
    return 'debited';
  }

  /// Minimal privacy-safe summary sent to Gemini AI.
  /// Strict requirement: NO raw SMS text, masked account identifiers only.
  Map<String, dynamic> toAiSummaryMap() {
    return {
      'candidateId': candidateId,
      'sender': sender,
      'transactionDate': transactionDate.toIso8601String(),
      'amount': amount,
      'transactionType': transactionType.name,
      'merchant': normalizedMerchant.isNotEmpty ? normalizedMerchant : (merchant ?? ''),
      'accountLast4': accountLast4 ?? '',
      'bankName': bankName ?? '',
      'referenceNumber': referenceNumber ?? '',
      'upiReference': upiReference ?? '',
      'lifecycleState': lifecycleState,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'candidateId': candidateId,
      'sourceSmsId': sourceSmsId,
      'sender': sender,
      'receivedAt': receivedAt.toIso8601String(),
      'transactionDate': transactionDate.toIso8601String(),
      'amount': amount,
      'transactionType': transactionType.name,
      'merchant': merchant,
      'accountId': accountId,
      'accountLast4': accountLast4,
      'bankName': bankName,
      'referenceNumber': referenceNumber,
      'upiReference': upiReference,
      'balance': balance,
      'currency': currency,
      'rawMessageHash': rawMessageHash,
      'parserConfidence': parserConfidence,
      'normalizedMerchant': normalizedMerchant,
      'normalizedDescription': normalizedDescription,
      'lifecycleState': lifecycleState,
      'rawMessage': rawMessage,
    };
  }

  factory TransactionCandidate.fromMap(Map<String, dynamic> map) {
    return TransactionCandidate(
      candidateId: map['candidateId'] as String,
      sourceSmsId: map['sourceSmsId'] as String?,
      sender: map['sender'] as String? ?? '',
      receivedAt: DateTime.tryParse(map['receivedAt'] as String? ?? '') ?? DateTime.now(),
      transactionDate: DateTime.tryParse(map['transactionDate'] as String? ?? '') ?? DateTime.now(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      transactionType: map['transactionType'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      merchant: map['merchant'] as String?,
      accountId: map['accountId'] as String?,
      accountLast4: map['accountLast4'] as String?,
      bankName: map['bankName'] as String?,
      referenceNumber: map['referenceNumber'] as String?,
      upiReference: map['upiReference'] as String?,
      balance: (map['balance'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? 'INR',
      rawMessageHash: map['rawMessageHash'] as String? ?? '',
      parserConfidence: (map['parserConfidence'] as num?)?.toDouble() ?? 1.0,
      normalizedMerchant: map['normalizedMerchant'] as String? ?? '',
      normalizedDescription: map['normalizedDescription'] as String? ?? '',
      lifecycleState: map['lifecycleState'] as String? ?? 'successful',
      rawMessage: map['rawMessage'] as String?,
    );
  }
}
