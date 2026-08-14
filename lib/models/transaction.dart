enum TransactionType { income, expense }

class Transaction {
  final String id;
  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final String? subtitle;
  final TransactionType type;

  Transaction({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.subtitle,
    required this.type,
  });
}
