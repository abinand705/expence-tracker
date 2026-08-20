import '../models/transaction.dart';

class ParsedPendingDue {
  final double amount;
  final DateTime dueDate;
  final String? description;

  ParsedPendingDue({required this.amount, required this.dueDate, this.description});
}

class ParsedExpense {
  final double amount;
  final String? merchant;
  final String rawText;
  final double? availableBalance;
  final String? accountNumber;
  final TransactionType type;

  ParsedExpense({
    required this.amount, 
    this.merchant, 
    this.availableBalance,
    this.accountNumber,
    required this.rawText,
    this.type = TransactionType.expense,
  });
}

class ExpenseParser {
  static final RegExp _amountRegex = RegExp(r'(?:rs\.?|inr|₹)\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  static final RegExp _debitKeywords = RegExp(r'(debited|spent|paid|sent|deducted|\bdr\b|dr\.)', caseSensitive: false);
  static final RegExp _creditKeywords = RegExp(r'(credited|received|\bcr\b|cr\.)', caseSensitive: false);
  static final RegExp _balRegex = RegExp(r'(?:avl\s*bal|available\s*balance|available\s*bal|a/c\s*balance|a/c\s*bal|bal\s*stands|balance|bal)\s*[:-]?\s*(?:is\s+)?(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  static final RegExp _acRegex = RegExp(r'(?:(?:a/c|account|acct)\s*(?:no\.?|number)?\s*[-:]?\s*(?:ending(?:\s+in)?\s+)?(?:[xX\*\.]{2,}[-]*)?\s*|ending(?:\s+in)?\s+|[xX\*]{2,}[-]*\s*)(\d{4,})', caseSensitive: false);
  static final RegExp _futureDebitKeywords = RegExp(r'(will be debited|scheduled payment|auto debit|will be deducted|to be debited|debit on|payment due|autopay|mandate|standing instruction|due on)', caseSensitive: false);
  static final RegExp _dateRegex = RegExp(r'(\d{1,2})(?:st|nd|rd|th)?[-/\s]+([a-zA-Z]{3,9}|\d{1,2})(?:[-/\s]+(\d{2,4}))?', caseSensitive: false);

  static ParsedPendingDue? parsePendingDue(String text, DateTime detectedAt) {
    // If it's already completed (e.g. "has been debited"), it's not pending.
    if (RegExp(r'(has been debited|was debited|successfully debited)', caseSensitive: false).hasMatch(text)) {
      return null;
    }

    if (!_futureDebitKeywords.hasMatch(text)) return null;

    final amountMatch = _amountRegex.firstMatch(text);
    if (amountMatch == null) return null;
    final amountStr = amountMatch.group(1)?.replaceAll(',', '');
    if (amountStr == null) return null;
    final amount = double.tryParse(amountStr);
    if (amount == null) return null;

    final dateMatches = _dateRegex.allMatches(text);
    int day = -1;
    int month = -1;
    int year = -1;
    String? yearStr;

    for (final dateMatch in dateMatches) {
      final dStr = dateMatch.group(1);
      final mStr = dateMatch.group(2);
      final yStr = dateMatch.group(3);
      if (dStr == null || mStr == null) continue;

      int m = _parseMonth(mStr);
      if (m == -1) {
        m = int.tryParse(mStr) ?? -1;
      }
      if (m >= 1 && m <= 12) {
        day = int.parse(dStr);
        month = m;
        yearStr = yStr;
        year = yStr != null ? (yStr.length == 2 ? 2000 + int.parse(yStr) : int.parse(yStr)) : detectedAt.year;
        break; // Found valid date
      }
    }

    if (month == -1 || month < 1 || month > 12) return null;

    DateTime dueDate = DateTime(year, month, day);
    if (yearStr == null && dueDate.isBefore(detectedAt.subtract(const Duration(days: 30)))) {
       dueDate = DateTime(year + 1, month, day);
    }

    String? description;
    final merchantRegex = RegExp(r'(?:to|for)\s+([A-Za-z0-9\s@.-]+?)(?:\.|\s+on\s+|$)', caseSensitive: false);
    final descMatch = merchantRegex.firstMatch(text);
    if (descMatch != null) {
      description = descMatch.group(1)?.trim();
    }

    return ParsedPendingDue(amount: amount, dueDate: dueDate, description: description);
  }

  static int _parseMonth(String monthStr) {
    monthStr = monthStr.toLowerCase();
    if (monthStr.startsWith('jan')) return 1;
    if (monthStr.startsWith('feb')) return 2;
    if (monthStr.startsWith('mar')) return 3;
    if (monthStr.startsWith('apr')) return 4;
    if (monthStr.startsWith('may')) return 5;
    if (monthStr.startsWith('jun')) return 6;
    if (monthStr.startsWith('jul')) return 7;
    if (monthStr.startsWith('aug')) return 8;
    if (monthStr.startsWith('sep')) return 9;
    if (monthStr.startsWith('oct')) return 10;
    if (monthStr.startsWith('nov')) return 11;
    if (monthStr.startsWith('dec')) return 12;
    return -1;
  }

  static ParsedExpense? parse(String text) {
    final isDebit = _debitKeywords.hasMatch(text);
    final isCredit = _creditKeywords.hasMatch(text);

    if (!isDebit && !isCredit) return null;

    // If both match, it's often a transfer. We'll default to expense if debit keyword is present.
    final type = isDebit ? TransactionType.expense : TransactionType.income;

    final amountMatch = _amountRegex.firstMatch(text);
    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)?.replaceAll(',', '');
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          // Attempt to extract merchant after 'at', 'to', etc.
          String? merchant;
          final merchantRegex = RegExp(r'(?:at|to|info)\s+([A-Za-z0-9\s@.-]+?)(?:\.|\s+on\s+|$)', caseSensitive: false);
          final merchantMatch = merchantRegex.firstMatch(text);
          if (merchantMatch != null) {
            merchant = merchantMatch.group(1)?.trim();
            // Clean up common false positives
            if (merchant?.toLowerCase() == 'your' || merchant?.toLowerCase() == 'a/c') {
              merchant = null;
            }
          }

          double? availableBalance;
          final balMatch = _balRegex.firstMatch(text);
          if (balMatch != null) {
            final balStr = balMatch.group(1)?.replaceAll(',', '');
            if (balStr != null) availableBalance = double.tryParse(balStr);
          }

          String? accountNumber;
          final acMatch = _acRegex.firstMatch(text);
          if (acMatch != null) {
            accountNumber = acMatch.group(1);
          }

          return ParsedExpense(
            amount: amount,
            merchant: merchant,
            availableBalance: availableBalance,
            accountNumber: accountNumber,
            rawText: text,
            type: type,
          );
        }
      }
    }
    return null;
  }

  static double? extractBalance(String text) {
    final balMatch = _balRegex.firstMatch(text);
    if (balMatch != null) {
      final balStr = balMatch.group(1)?.replaceAll(',', '');
      if (balStr != null) return double.tryParse(balStr);
    }
    return null;
  }

  static String? extractAccountNumber(String text) {
    final acMatch = _acRegex.firstMatch(text);
    if (acMatch != null) {
      final digits = acMatch.group(1)?.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits != null && digits.length >= 4) {
        return digits.substring(digits.length - 4);
      }
    }
    return null;
  }

  static String guessCategory(String? merchant) {
    if (merchant == null || merchant.isEmpty) return 'Others';
    final lower = merchant.toLowerCase();
    
    if (lower.contains('zomato') || lower.contains('swiggy') || lower.contains('kfc') || lower.contains('mcdonald') || lower.contains('dominos') || lower.contains('food')) {
      return 'Food';
    }
    if (lower.contains('airtel') || lower.contains('jio') || lower.contains('recharge') || lower.contains('electricity') || lower.contains('bill') || lower.contains('kseb')) {
      return 'Bills';
    }
    if (lower.contains('amazon') || lower.contains('flipkart') || lower.contains('myntra') || lower.contains('shopping') || lower.contains('store') || lower.contains('mart')) {
      return 'Shopping';
    }
    return 'Others';
  }
}
