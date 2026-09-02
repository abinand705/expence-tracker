import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

class TransactionCategory {
  static const String food = 'food';
  static const String bills = 'bills';
  static const String shopping = 'shopping';
  static const String others = 'others';

  static const List<String> all = [food, bills, shopping, others];

  static String normalize(String? category) {
    if (category == null || category.trim().isEmpty) return others;
    final lower = category.trim().toLowerCase();
    switch (lower) {
      case 'food':
        return food;
      case 'bills':
      case 'bill':
      case 'electricity bill':
      case 'utilities':
        return bills;
      case 'shopping':
        return shopping;
      case 'others':
      case 'uncategorized':
      default:
        return others;
    }
  }

  static String displayName(String? category) {
    final normalized = normalize(category);
    switch (normalized) {
      case food:
        return 'Food';
      case bills:
        return 'Bills';
      case shopping:
        return 'Shopping';
      case others:
      default:
        return 'Others';
    }
  }
}

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String merchant;
  final String category;
  final String? customCategory;
  final String? description;
  final String? accountId;
  final String transactionSource;
  final String? subcategory;
  final DateTime date;
  final String? paymentMethod;
  final String? upiReference;
  final String? accountNumber;
  final String? rawMessage;
  final String? source;
  final bool isManual;
  final bool isRecurring;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? subtitle;
  final String? sourceId;
  final String? sourceFingerprint;
  final String? customTitle;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    this.customCategory,
    this.description,
    this.accountId,
    this.transactionSource = 'manual',
    this.subcategory,
    required this.date,
    this.paymentMethod,
    this.upiReference,
    this.accountNumber,
    this.rawMessage,
    this.source,
    this.isManual = false,
    this.isRecurring = false,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.subtitle,
    this.sourceId,
    this.sourceFingerprint,
    this.customTitle,
  });

  String get effectiveCategory {
    if (customCategory != null && customCategory!.trim().isNotEmpty) {
      return customCategory!.trim();
    }
    if (category.trim().isNotEmpty) {
      return category.trim();
    }
    return TransactionCategory.others;
  }

  String get displayCategory => TransactionCategory.displayName(effectiveCategory);

  String get displayTitle {
    if (customTitle != null && customTitle!.trim().isNotEmpty) {
      return customTitle!.trim();
    }
    final trimmedMerchant = merchant.trim();
    if (trimmedMerchant.isNotEmpty && trimmedMerchant.toLowerCase() != 'unknown merchant') {
      return trimmedMerchant;
    }
    final trimmedDesc = description?.trim();
    if (trimmedDesc != null && trimmedDesc.isNotEmpty) {
      return trimmedDesc;
    }
    if (trimmedMerchant.isNotEmpty) {
      return trimmedMerchant;
    }
    return 'Unknown Merchant';
  }

  static const Object _sentinel = Object();

  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? merchant,
    String? category,
    Object? customCategory = _sentinel,
    String? description,
    String? accountId,
    String? transactionSource,
    String? subcategory,
    DateTime? date,
    String? paymentMethod,
    String? upiReference,
    String? accountNumber,
    String? rawMessage,
    String? source,
    bool? isManual,
    bool? isRecurring,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subtitle,
    String? sourceId,
    String? sourceFingerprint,
    Object? customTitle = _sentinel,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      customCategory: customCategory == _sentinel ? this.customCategory : (customCategory as String?),
      description: description ?? this.description,
      accountId: accountId ?? this.accountId,
      transactionSource: transactionSource ?? this.transactionSource,
      subcategory: subcategory ?? this.subcategory,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      upiReference: upiReference ?? this.upiReference,
      accountNumber: accountNumber ?? this.accountNumber,
      rawMessage: rawMessage ?? this.rawMessage,
      source: source ?? this.source,
      isManual: isManual ?? this.isManual,
      isRecurring: isRecurring ?? this.isRecurring,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subtitle: subtitle ?? this.subtitle,
      sourceId: sourceId ?? this.sourceId,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      customTitle: customTitle == _sentinel ? this.customTitle : (customTitle as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.name,
      'merchant': merchant,
      'category': category,
      'customCategory': customCategory,
      'description': description,
      'accountId': accountId,
      'transactionSource': transactionSource,
      'subcategory': subcategory,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'upiReference': upiReference,
      'accountNumber': accountNumber,
      'rawMessage': rawMessage,
      'source': source,
      'isManual': isManual,
      'isRecurring': isRecurring,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'subtitle': subtitle,
      'sourceId': sourceId,
      'sourceFingerprint': sourceFingerprint,
      'customTitle': customTitle,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    return Transaction(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      merchant: map['merchant'] ?? '',
      category: map['category'] ?? 'others',
      customCategory: map['customCategory'] as String?,
      description: map['description'] ?? '',
      accountId: map['accountId'] ?? '',
      transactionSource: map['transactionSource'] ?? 'manual',
      subcategory: map['subcategory'],
      date: parseDate(map['date']),
      paymentMethod: map['paymentMethod'],
      upiReference: map['upiReference'],
      accountNumber: map['accountNumber'],
      rawMessage: map['rawMessage'],
      source: map['source'],
      isManual: map['isManual'] ?? false,
      isRecurring: map['isRecurring'] ?? false,
      notes: map['notes'],
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      subtitle: map['subtitle'],
      sourceId: map['sourceId'],
      sourceFingerprint: map['sourceFingerprint'],
      customTitle: map['customTitle'] as String?,
    );
  }
}
