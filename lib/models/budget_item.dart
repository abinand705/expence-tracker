class BudgetItem {
  final String id;
  final String categoryName;
  final int monthlyLimit; // integer monthly limit
  final String userId;

  const BudgetItem({
    required this.id,
    required this.categoryName,
    required this.monthlyLimit,
    this.userId = 'all',
  });

  /// Compatibility getters for existing UI
  String get category => categoryName;
  double get limit => monthlyLimit.toDouble();

  Map<String, dynamic> toMap() {
    return {
      'category/expense_name': categoryName,
      'category_name': categoryName,
      'monthly_limit': monthlyLimit,
      'user_Id': userId,
    };
  }

  factory BudgetItem.fromMap(String id, Map<String, dynamic> map) {
    final catName = (map['category/expense_name'] ??
            map['category_name'] ??
            map['category'] ??
            'General')
        .toString();

    final rawLimit = map['monthly_limit'] ?? map['limit'] ?? 0;
    final int limit;
    if (rawLimit is int) {
      limit = rawLimit;
    } else if (rawLimit is num) {
      limit = rawLimit.round();
    } else {
      limit = int.tryParse(rawLimit.toString()) ?? 0;
    }

    final userId = (map['user_Id'] ?? map['userId'] ?? 'all').toString();

    return BudgetItem(
      id: id,
      categoryName: catName,
      monthlyLimit: limit,
      userId: userId,
    );
  }
}
