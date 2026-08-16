import '../models/transaction.dart';

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
  static final RegExp _balRegex = RegExp(r'(?:AvlBal|Bal stands|Avl Bal|Balance)[\s:a-zA-Z]*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  static final RegExp _acRegex = RegExp(r'(?:(?:a/c|account|acct)\s*(?:no\.?|number)?\s*[-:]?\s*(?:ending(?:\s+in)?\s+)?(?:[xX\*\.]{2,}[-]*)?\s*|ending(?:\s+in)?\s+|[xX\*]{2,}[-]*\s*)(\d{4,})', caseSensitive: false);

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
    if (acMatch != null) return acMatch.group(1);
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
