enum TransactionType { income, expense }

class Transaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String merchant;
  final String category;
  final String? subcategory;
  final DateTime date;
  final String? accountId;
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

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    this.subcategory,
    required this.date,
    this.accountId,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.name,
      'merchant': merchant,
      'category': category,
      'subcategory': subcategory,
      'date': date.toIso8601String(),
      'accountId': accountId,
      'paymentMethod': paymentMethod,
      'upiReference': upiReference,
      'accountNumber': accountNumber,
      'rawMessage': rawMessage,
      'source': source,
      'isManual': isManual,
      'isRecurring': isRecurring,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'subtitle': subtitle,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      merchant: map['merchant'],
      category: map['category'],
      subcategory: map['subcategory'],
      date: DateTime.parse(map['date']),
      accountId: map['accountId'],
      paymentMethod: map['paymentMethod'],
      upiReference: map['upiReference'],
      accountNumber: map['accountNumber'],
      rawMessage: map['rawMessage'],
      source: map['source'],
      isManual: map['isManual'] ?? false,
      isRecurring: map['isRecurring'] ?? false,
      notes: map['notes'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      subtitle: map['subtitle'],
    );
  }
}
