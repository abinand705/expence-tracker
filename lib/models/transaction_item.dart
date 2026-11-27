import 'package:intl/intl.dart';

enum TransactionType {
  expense,
  income,
  transfer,
}

class TransactionItem {
  final String id;
  final String title;
  final String note;
  final double amount; // numeric for calculations
  final TransactionType type;
  final DateTime date; // contains exact date and time
  final String category;
  final String? userId;

  TransactionItem({
    required this.id,
    required this.title,
    String? note,
    required double amount,
    required this.type,
    required this.date,
    required this.category,
    this.userId,
  })  : note = (note != null && note.isNotEmpty) ? note : title,
        amount = amount.roundToDouble();

  int get integerAmount => amount.round();

  Map<String, dynamic> toMap({String? userId}) {
    final effectiveUserId = userId ?? this.userId ?? 'all';
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final timeStr = DateFormat('HH:mm:ss').format(date);

    return {
      'title': title,
      'note': note,
      'amount': amount.round(), // Stored strictly as integer
      'type': type.name,
      'category': type == TransactionType.transfer ? 'Transfer' : category,
      'date': date.millisecondsSinceEpoch,
      'date_time': date.toIso8601String(),
      'date_string': dateStr,
      'time_string': timeStr,
      'user_Id': effectiveUserId,
    };
  }

  factory TransactionItem.fromMap(String id, Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    final double amount;
    if (rawAmount is int) {
      amount = rawAmount.toDouble();
    } else if (rawAmount is num) {
      amount = rawAmount.toDouble();
    } else {
      amount = double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0;
    }

    final rawDate = map['date_time'] ?? map['date'];
    final DateTime date;
    if (rawDate is int) {
      date = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate != null) {
      date = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    final note = (map['note'] ?? map['title'] ?? '').toString();
    final title = (map['title'] ?? map['note'] ?? 'Untitled').toString();

    return TransactionItem(
      id: id,
      title: title.isNotEmpty ? title : (note.isNotEmpty ? note : 'Untitled'),
      note: note,
      amount: amount,
      type: TransactionType.values.firstWhere(
        (t) => t.name == (map['type'] as String?),
        orElse: () => TransactionType.expense,
      ),
      date: date,
      category: map['category'] as String? ?? 'General',
      userId: map['user_Id'] as String?,
    );
  }
}
