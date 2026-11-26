enum TransactionType {
  expense,
  income,
  transfer,
}

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String category;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'type': type.name,
      'date': date.millisecondsSinceEpoch,
      'category': category,
    };
  }

  factory TransactionItem.fromMap(String id, Map<String, dynamic> map) {
    return TransactionItem(
      id: id,
      title: map['title'] as String? ?? 'Untitled',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: TransactionType.values.firstWhere(
        (t) => t.name == (map['type'] as String?),
        orElse: () => TransactionType.expense,
      ),
      date: map['date'] != null
          ? (map['date'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
              : DateTime.tryParse(map['date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      category: map['category'] as String? ?? 'General',
    );
  }
}
