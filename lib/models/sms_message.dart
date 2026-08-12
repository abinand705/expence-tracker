class SmsMessage {
  final String id;
  final String sender;
  final String snippet;
  final DateTime date;
  final double? extractedAmount;

  SmsMessage({
    required this.id,
    required this.sender,
    required this.snippet,
    required this.date,
    this.extractedAmount,
  });
}
