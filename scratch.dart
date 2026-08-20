import 'dart:io';

void main() {
  final RegExp _futureDebitKeywords = RegExp(r'(will be debited|scheduled payment|auto debit|will be deducted|to be debited|debit on|payment due|autopay|mandate|standing instruction|due on)', caseSensitive: false);
  final RegExp _dateRegex = RegExp(r'(\d{1,2})(?:st|nd|rd|th)?[-/\s]+([a-zA-Z]{3,9}|\d{1,2})(?:[-/\s]+(\d{2,4}))?', caseSensitive: false);
  final RegExp _amountRegex = RegExp(r'(?:rs\.?|inr|₹)\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);

  final text = '₹2,499 will be debited on 25 Aug';
  print('futureDebitKeywords: ${_futureDebitKeywords.hasMatch(text)}');
  
  final amountMatch = _amountRegex.firstMatch(text);
  print('amountMatch: ${amountMatch?.group(1)}');
  
  final dateMatch = _dateRegex.firstMatch(text);
  print('dateMatch: ${dateMatch?.group(1)} ${dateMatch?.group(2)} ${dateMatch?.group(3)}');
}
