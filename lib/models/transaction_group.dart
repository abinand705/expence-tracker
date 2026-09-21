import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction.dart';
import 'transaction_candidate.dart';

enum TransactionGroupStatus {
  confirmed,
  pendingReview,
  ignored,
}

enum TransactionResolutionMethod {
  exactReference,
  deterministicMatch,
  fuzzyMatch,
  gemini,
  manual,
  newTransaction,
}

/// Represents a single real-world financial transaction, potentially formed from
/// multiple related bank SMS messages / candidates.
class TransactionGroup {
  final String groupId;
  final List<String> candidateIds;
  final double canonicalAmount;
  final TransactionType canonicalType;
  final String canonicalMerchant;
  final String? accountId;
  final String? bankName;
  final DateTime transactionDate;
  final String? referenceNumber;
  final TransactionGroupStatus status;
  final double confidence;
  final TransactionResolutionMethod resolutionMethod;
  final String? aiReason;
  final String? canonicalTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TransactionCandidate>? candidates;

  const TransactionGroup({
    required this.groupId,
    required this.candidateIds,
    required this.canonicalAmount,
    required this.canonicalType,
    required this.canonicalMerchant,
    this.accountId,
    this.bankName,
    required this.transactionDate,
    this.referenceNumber,
    this.status = TransactionGroupStatus.confirmed,
    this.confidence = 1.0,
    this.resolutionMethod = TransactionResolutionMethod.newTransaction,
    this.aiReason,
    this.canonicalTransactionId,
    required this.createdAt,
    required this.updatedAt,
    this.candidates,
  });

  TransactionGroup copyWith({
    String? groupId,
    List<String>? candidateIds,
    double? canonicalAmount,
    TransactionType? canonicalType,
    String? canonicalMerchant,
    String? accountId,
    String? bankName,
    DateTime? transactionDate,
    String? referenceNumber,
    TransactionGroupStatus? status,
    double? confidence,
    TransactionResolutionMethod? resolutionMethod,
    String? aiReason,
    String? canonicalTransactionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TransactionCandidate>? candidates,
  }) {
    return TransactionGroup(
      groupId: groupId ?? this.groupId,
      candidateIds: candidateIds ?? this.candidateIds,
      canonicalAmount: canonicalAmount ?? this.canonicalAmount,
      canonicalType: canonicalType ?? this.canonicalType,
      canonicalMerchant: canonicalMerchant ?? this.canonicalMerchant,
      accountId: accountId ?? this.accountId,
      bankName: bankName ?? this.bankName,
      transactionDate: transactionDate ?? this.transactionDate,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      resolutionMethod: resolutionMethod ?? this.resolutionMethod,
      aiReason: aiReason ?? this.aiReason,
      canonicalTransactionId: canonicalTransactionId ?? this.canonicalTransactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      candidates: candidates ?? this.candidates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'candidateIds': candidateIds,
      'canonicalAmount': canonicalAmount,
      'canonicalType': canonicalType.name,
      'canonicalMerchant': canonicalMerchant,
      'accountId': accountId,
      'bankName': bankName,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'referenceNumber': referenceNumber,
      'status': status.name,
      'confidence': confidence,
      'resolutionMethod': resolutionMethod.name,
      'aiReason': aiReason,
      'canonicalTransactionId': canonicalTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (candidates != null)
        'candidates': candidates!.map((c) => c.toMap()).toList(),
    };
  }

  factory TransactionGroup.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    TransactionGroupStatus parseStatus(dynamic val) {
      switch (val?.toString()) {
        case 'pendingReview':
        case 'pending_review':
          return TransactionGroupStatus.pendingReview;
        case 'ignored':
          return TransactionGroupStatus.ignored;
        case 'confirmed':
        default:
          return TransactionGroupStatus.confirmed;
      }
    }

    TransactionResolutionMethod parseMethod(dynamic val) {
      switch (val?.toString()) {
        case 'exactReference':
        case 'exact_reference':
          return TransactionResolutionMethod.exactReference;
        case 'deterministicMatch':
        case 'deterministic_match':
          return TransactionResolutionMethod.deterministicMatch;
        case 'fuzzyMatch':
        case 'fuzzy_match':
          return TransactionResolutionMethod.fuzzyMatch;
        case 'gemini':
          return TransactionResolutionMethod.gemini;
        case 'manual':
          return TransactionResolutionMethod.manual;
        case 'newTransaction':
        case 'new_transaction':
        default:
          return TransactionResolutionMethod.newTransaction;
      }
    }

    List<TransactionCandidate>? candList;
    if (map['candidates'] is List) {
      candList = (map['candidates'] as List)
          .map((item) => TransactionCandidate.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return TransactionGroup(
      groupId: map['groupId'] as String,
      candidateIds: (map['candidateIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      canonicalAmount: (map['canonicalAmount'] as num?)?.toDouble() ?? 0.0,
      canonicalType: map['canonicalType'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      canonicalMerchant: map['canonicalMerchant'] as String? ?? 'Unknown Merchant',
      accountId: map['accountId'] as String?,
      bankName: map['bankName'] as String?,
      transactionDate: parseDate(map['transactionDate']),
      referenceNumber: map['referenceNumber'] as String?,
      status: parseStatus(map['status']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      resolutionMethod: parseMethod(map['resolutionMethod']),
      aiReason: map['aiReason'] as String?,
      canonicalTransactionId: map['canonicalTransactionId'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      candidates: candList,
    );
  }
}
