import '../models/transaction.dart';

class ParsedPendingDue {
  final double amount;
  final DateTime dueDate;
  final String? description;
  final String? accountSuffix;
  final String? bankName;
  final String source;

  ParsedPendingDue({
    required this.amount, 
    required this.dueDate, 
    this.description,
    this.accountSuffix,
    this.bankName,
    this.source = 'sms',
  });
}

class ParsedExpense {
  final double amount;
  final String? merchant;
  final String rawText;
  final double? availableBalance;
  final String? accountNumber;
  final TransactionType type;
  final DateTime? transactionTimestamp;
  final String? messageId;
  final String? bankName;

  ParsedExpense({
    required this.amount, 
    this.merchant, 
    this.availableBalance,
    this.accountNumber,
    required this.rawText,
    this.type = TransactionType.expense,
    this.transactionTimestamp,
    this.messageId,
    this.bankName,
  });
}

class ExpenseParser {
  static final RegExp _amountRegex = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  
  static final RegExp _debitKeywords = RegExp(
    r'(?:after\s+debit\s+of|debited|debit\s+of|debit|withdrawn|withdrawal|spent|paid|payment|purchase|transferred|sent|deducted|upi\s+debit|atm\s+withdrawal|pos\s+transaction|\bdr\b|dr\.)', 
    caseSensitive: false
  );
  
  static final RegExp _creditKeywords = RegExp(
    r'(?:credited|credit\s+of|credit|received|deposit(?:ed)?|refund|cashback|salary\s+credited|amount\s+received|\bcr\b|cr\.)', 
    caseSensitive: false
  );
  
  static final RegExp _balRegex = RegExp(
    r'(?:avl\s*bal|available\s*balance|available\s*bal|a/c\s*balance|a/c\s*bal|bal(?:\s*stands)?|balance|bal)\s*[:-]?\s*(?:is\s+)?(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)', 
    caseSensitive: false
  );

  static double? parseAvailableBalanceOnly(String text) {
    final match = _balRegex.firstMatch(text);
    if (match != null) {
      final balStr = match.group(1)?.replaceAll(',', '');
      if (balStr != null) {
        return double.tryParse(balStr);
      }
    }
    return null;
  }
  
  static final RegExp _acRegex = RegExp(
    r'(?:(?:a/c|account|acct|\bac\b)\s*(?:no\.?|number|num)?\s*[-:#]?\s*(?:ending(?:\s+(?:in|with))?|ends\s+with)?\s*(?:[xX\*\.\s-]{1,})?\s*|(?:ending(?:\s+(?:in|with))?|ends\s+with)\s*(?:[xX\*\.\s-]{1,})?\s*|(?:[xX\*]{2,}[\s-]*)+)(\d{3,})',
    caseSensitive: false,
  );

  static final RegExp _msgIdRegex = RegExp(
    r'(?:upi\s*ref(?:\s*no\.?)?|upi\s*txn(?:\s*id)?|txn\s*(?:id|ref|no\.?)|transaction\s*(?:id|ref|no\.?)|ref\s*(?:no\.?|num|id)?|reference\s*(?:no\.?|num|id)?|utr(?:\s*no\.?)?|rrn(?:\s*no\.?)?|imps\s*(?:ref|no\.?)?|neft\s*(?:ref|no\.?)?|msg\s*id|msgid)\s*[:#-]?\s*([a-zA-Z0-9]+)',
    caseSensitive: false,
  );
  
  static final RegExp _futureDebitKeywords = RegExp(
    r'(will be debited|scheduled payment|auto debit|will be deducted|to be debited|debit on|payment due|autopay|mandate|standing instruction|due on|upcoming sip|scheduled debit|will be charged on|autodebit)', 
    caseSensitive: false
  );
  
  static final RegExp _dateRegex = RegExp(
    r'(\d{1,2})(?:st|nd|rd|th)?[-/\s]+([a-zA-Z]{3,9}|\d{1,2})(?:[-/\s]+(\d{2,4}))?', 
    caseSensitive: false
  );
  
  static final RegExp _financialContextRegex = RegExp(
    r'(bank|a/c|account|sip|mandate|auto debit|standing instruction|payment due|rs\.?|inr|₹)', 
    caseSensitive: false
  );

  static bool hasFutureDebitKeywords(String text) {
    return _futureDebitKeywords.hasMatch(text);
  }

  static bool isStrongFinancialMessage(String text) {
    if (!hasFutureDebitKeywords(text)) return false;
    if (!_amountRegex.hasMatch(text)) return false;
    if (!_financialContextRegex.hasMatch(text)) return false;
    // Actually verify there is a valid date
    if (parsePendingDue(text, DateTime.now()) == null) return false;
    return true;
  }

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
    
    // Check for SIP format
    final sipRegex = RegExp(r'upcoming SIP.*?(?:in|for)\s+(.*?)(?:\.|\s+Ensure|$)', caseSensitive: false);
    final sipMatch = sipRegex.firstMatch(text);
    if (sipMatch != null) {
      description = 'Upcoming SIP - ${sipMatch.group(1)?.trim()}';
    } else {
      final merchantRegex = RegExp(r'(?:to|for)\s+([A-Za-z0-9\s@.-]+?)(?:\.|\s+on\s+|$)', caseSensitive: false);
      final descMatch = merchantRegex.firstMatch(text);
      if (descMatch != null) {
        description = descMatch.group(1)?.trim();
      }
    }

    String? accountSuffix;
    String? bankName;
    final explicitBankRegex = RegExp(r'(?:from your\s+|from\s+)?(\d{3,6})\s*-\s*([A-Za-z\s]+?)(?=\s+for|\s+in|\.|\s+on|\s+due|$)', caseSensitive: false);
    final bankMatch = explicitBankRegex.firstMatch(text);
    if (bankMatch != null) {
      accountSuffix = bankMatch.group(1);
      bankName = bankMatch.group(2)?.trim();
    } else {
      accountSuffix = extractAccountNumber(text);
    }

    return ParsedPendingDue(
      amount: amount, 
      dueDate: dueDate, 
      description: description,
      accountSuffix: accountSuffix,
      bankName: bankName,
      source: 'sms',
    );
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

    // If both match, default to expense if debit keyword is present.
    final type = isDebit ? TransactionType.expense : TransactionType.income;

    // 1. Extract Balance if present
    double? availableBalance;
    Match? balMatch = _balRegex.firstMatch(text);
    int balStart = -1;
    int balEnd = -1;
    if (balMatch != null) {
      balStart = balMatch.start;
      balEnd = balMatch.end;
      final balStr = balMatch.group(1)?.replaceAll(',', '');
      if (balStr != null) {
        availableBalance = double.tryParse(balStr);
      }
    }

    // 2. Extract transaction amount (ensuring it is NOT the balance or part of balRegex)
    double? transactionAmount;
    final allAmountMatches = _amountRegex.allMatches(text);
    for (final m in allAmountMatches) {
      // If this match overlaps with the balance match, skip it
      if (balStart != -1 && m.start >= balStart && m.start < balEnd) {
        continue;
      }
      final rawAmtStr = m.group(1)?.replaceAll(',', '');
      if (rawAmtStr != null) {
        final parsedVal = double.tryParse(rawAmtStr);
        if (parsedVal != null) {
          transactionAmount = parsedVal;
          break; // First valid non-balance currency amount is the transaction amount
        }
      }
    }

    if (transactionAmount == null) return null;

    // 3. Merchant extraction
    String? merchant = extractMerchant(text);

    // 4. Account Number extraction
    String? accountNumber = extractAccountNumber(text);

    // 5. Transaction Timestamp extraction
    DateTime? transactionTimestamp = extractTransactionTimestamp(text);

    // 6. Message / Reference ID extraction
    String? messageId = extractMessageId(text);

    // 7. Bank Name extraction from text
    String? bankName = extractBankName(text);

    return ParsedExpense(
      amount: transactionAmount,
      merchant: merchant,
      availableBalance: availableBalance,
      accountNumber: accountNumber,
      rawText: text,
      type: type,
      transactionTimestamp: transactionTimestamp,
      messageId: messageId,
      bankName: bankName,
    );
  }

  static String? extractMerchant(String text) {
    // 1. Check UPI format, e.g. "UPI/AMAZON/123456", "UPI/P2M/1234/AMAZON/Ref", "UPI-AMAZON-..."
    final upiSlashRegex = RegExp(r'UPI/([A-Za-z0-9\s._&/-]+?)(?:\s+on|\s+ref|\.|\s+rs|\s+using|\s+bal|$)', caseSensitive: false);
    final upiMatch = upiSlashRegex.firstMatch(text);
    if (upiMatch != null) {
      final parts = upiMatch.group(1)!.split('/');
      for (final part in parts) {
        final candidate = _cleanMerchantCandidate(part);
        if (_isValidMerchant(candidate)) return candidate;
      }
    }

    // 2. Check POS format, e.g. "POS AMAZON Rs 250", "POS 1234 AMAZON Rs 250", "POS at AMAZON"
    final posRegex = RegExp(
      r'POS\s+(?:(?:\d+|[xX\*]+)\s+)?(?:at\s+)?([A-Za-z0-9\s._&-]+?)(?:\s+rs\.?|\s+inr|\s+₹|\s+on\s+|\s+bal|\.|\s+ref|$)', 
      caseSensitive: false,
    );
    final posMatch = posRegex.firstMatch(text);
    if (posMatch != null) {
      final candidate = _cleanMerchantCandidate(posMatch.group(1));
      if (_isValidMerchant(candidate)) return candidate;
    }

    // 3. Check explicit "paid to merchant", "merchant: XYZ", "paid to XYZ", "spent at XYZ", "debited for XYZ"
    final explicitMerchantRegex = RegExp(
      r'(?:paid\s+to\s+merchant|merchant\s*[:#-]?|paid\s+(?:(?:rs\.?|inr|₹)\s*[\d,.]+\s+)?to|transferred\s+(?:(?:rs\.?|inr|₹)\s*[\d,.]+\s+)?to|sent\s+(?:(?:rs\.?|inr|₹)\s*[\d,.]+\s+)?to|spent\s+(?:(?:rs\.?|inr|₹)\s*[\d,.]+\s+)?at|debited\s+for|debited\s+towards|credit\s+from|received\s+from)\s+([A-Za-z0-9\s._&-]+?)(?:\.|\s+rs\.?|\s+inr|\s+₹|\s+on\s+|\s+using|\s+via|\s+msg|\s+ref|\s+rrn|\s+txn|\s+bal|\s+avl|\s+from\s+a/c|\s+from\s+account|\s+from\s+your|\s+from|$)',
      caseSensitive: false,
    );
    final explicitMatch = explicitMerchantRegex.firstMatch(text);
    if (explicitMatch != null) {
      final candidate = _cleanMerchantCandidate(explicitMatch.group(1));
      if (_isValidMerchant(candidate)) return candidate;
    }

    // 4. Fallback standard regex: "at XYZ", "to XYZ", "for XYZ", "info XYZ"
    final fallbackRegex = RegExp(
      r'(?:at|to|info|for)\s+([A-Za-z0-9\s._&-]+?)(?:\.|\s+rs\.?|\s+inr|\s+₹|\s+on\s+|\s+using|\s+via|\s+msg|\s+ref|\s+rrn|\s+txn|\s+bal|\s+avl|\s+from\s+a/c|\s+from\s+account|\s+from\s+your|\s+from|$)',
      caseSensitive: false,
    );
    final fallbackMatch = fallbackRegex.firstMatch(text);
    if (fallbackMatch != null) {
      final candidate = _cleanMerchantCandidate(fallbackMatch.group(1));
      if (_isValidMerchant(candidate)) return candidate;
    }

    return null;
  }

  static String? _cleanMerchantCandidate(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    
    // Strip prefixes like "merchant ", "m/s ", "mr ", "mrs "
    s = s.replaceFirst(RegExp(r'^(?:merchant|m/s|mr|mrs)\s+', caseSensitive: false), '');
    // Strip trailing currency amounts like "Rs 150..."
    s = s.replaceFirst(RegExp(r'\s+(?:rs\.?|inr|₹)\s*[\d,.]*.*$', caseSensitive: false), '');
    // Strip trailing "from account / from a/c / from your..."
    s = s.replaceFirst(RegExp(r'\s+from\s+(?:a/c|account|your).*$', caseSensitive: false), '');
    // Strip trailing punctuation / connectors
    s = s.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');
    return s.trim();
  }

  static bool _isValidMerchant(String? candidate) {
    if (candidate == null || candidate.isEmpty) return false;
    if (candidate.length < 2 || candidate.length > 50) return false;

    // Reject purely numeric
    if (RegExp(r'^\d+$').hasMatch(candidate)) return false;

    // Reject account patterns like "A/c 1234", "XXXX1234", "ending 123"
    if (RegExp(r'^(?:a/c|account|acct|ac|ending|ends|xxxx|\.{2,})', caseSensitive: false).hasMatch(candidate)) {
      return false;
    }

    // Reject if it starts with or is a stop word / non-merchant financial term
    final lower = candidate.toLowerCase();
    final blacklistedExact = {
      'your', 'your account', 'your a/c', 'a/c', 'account', 'acct', 'ac', 'bank',
      'vpa', 'upi', 'self', 'card', 'credit card', 'debit card', 'atm', 'branch',
      'nach', 'neft', 'rtgs', 'imps', 'cheque', 'transfer', 'withdrawal',
      'deposit', 'payment', 'debit', 'credit', 'available', 'balance', 'bal',
      'ref', 'rrn', 'txn', 'otp', 'nominee', 'rs', 'inr', 'info', 'merchant',
    };
    if (blacklistedExact.contains(lower)) return false;

    // Reject if contains sentence fragments like "after debit of", "debited from", "credited to"
    if (lower.contains('after debit') ||
        lower.contains('after credit') ||
        lower.contains('debited from') ||
        lower.contains('credited to') ||
        lower.contains('is debited') ||
        lower.contains('is credited') ||
        lower.contains('has been')) {
      return false;
    }

    // Reject bank names to avoid mistaking bank as merchant
    final bankNames = [
      'hdfc', 'sbi', 'state bank', 'bank of baroda', 'bob', 'icici', 'axis',
      'kerala grameena', 'kg bank', 'kgbank', 'kotak', 'pnb', 'canara', 'union bank', 'idfc'
    ];
    for (final b in bankNames) {
      if (lower == b || lower == '$b bank') return false;
    }

    return true;
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
    // 1. Check explicit bank format first: e.g. "from your 123-BANK OF BARODA" or "0711-BANK OF BARODA"
    final explicitBankPrefixRegex = RegExp(r'(?:from your\s+|from\s+)?(\d{3,6})\s*-\s*[A-Za-z]', caseSensitive: false);
    final explicitMatch = explicitBankPrefixRegex.firstMatch(text);
    if (explicitMatch != null) {
      final digits = explicitMatch.group(1)?.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits != null && digits.length >= 3) {
        return digits;
      }
    }

    // 2. Match standard masked or prefixed account number expressions
    final acMatch = _acRegex.firstMatch(text);
    if (acMatch != null) {
      final digits = acMatch.group(1)?.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits != null && digits.length >= 3) {
        return digits;
      }
    }
    return null;
  }

  static String? extractMessageId(String text) {
    final matches = _msgIdRegex.allMatches(text);
    for (final match in matches) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      
      final cleaned = raw.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');
      if (cleaned.length < 2 || cleaned.length > 35) continue;
      
      // Reject common stop words
      final lower = cleaned.toLowerCase();
      if (['is', 'for', 'on', 'to', 'at', 'in', 'the', 'and', 'rs', 'inr', 'debited', 'credited', 'avlbl', 'bal', 'balance', 'account'].contains(lower)) {
        continue;
      }
      return cleaned;
    }
    return null;
  }

  static DateTime? extractTransactionTimestamp(String text) {
    // 1. Time DD-MM-YYYY HH:mm:ss or Time DD/MM/YYYY HH:mm:ss
    final timeWithDateRegex = RegExp(
      r'(?:time|date|on|dated)?\s*[:#-]?\s*(\d{1,2})[-/\.](\d{1,2})[-/\.](\d{2,4})\s+(?:at\s+)?(\d{1,2}):(\d{2})(?::(\d{2}))?',
      caseSensitive: false,
    );
    final match1 = timeWithDateRegex.firstMatch(text);
    if (match1 != null) {
      int d = int.parse(match1.group(1)!);
      int m = int.parse(match1.group(2)!);
      String yStr = match1.group(3)!;
      int y = yStr.length == 2 ? 2000 + int.parse(yStr) : int.parse(yStr);
      int hr = int.parse(match1.group(4)!);
      int min = int.parse(match1.group(5)!);
      int sec = match1.group(6) != null ? int.parse(match1.group(6)!) : 0;
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31 && hr < 24 && min < 60 && sec < 60) {
        return DateTime(y, m, d, hr, min, sec);
      }
    }

    // 2. Named month with time: DD-Mon-YYYY HH:mm:ss
    final namedMonthTimeRegex = RegExp(
      r'(\d{1,2})-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*-(\d{2,4})\s+(?:at\s+)?(\d{1,2}):(\d{2})(?::(\d{2}))?',
      caseSensitive: false,
    );
    final match2 = namedMonthTimeRegex.firstMatch(text);
    if (match2 != null) {
      int d = int.parse(match2.group(1)!);
      int m = _parseMonth(match2.group(2)!);
      String yStr = match2.group(3)!;
      int y = yStr.length == 2 ? 2000 + int.parse(yStr) : int.parse(yStr);
      int hr = int.parse(match2.group(4)!);
      int min = int.parse(match2.group(5)!);
      int sec = match2.group(6) != null ? int.parse(match2.group(6)!) : 0;
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31 && hr < 24 && min < 60 && sec < 60) {
        return DateTime(y, m, d, hr, min, sec);
      }
    }

    // 3. Standalone date DD-MM-YYYY or DD/MM/YYYY after "on" or "date"
    final dateRegex = RegExp(
      r'(?:on|date|dated)\s*[:#-]?\s*(\d{1,2})[-/\.](\d{1,2})[-/\.](\d{2,4})',
      caseSensitive: false,
    );
    final match3 = dateRegex.firstMatch(text);
    if (match3 != null) {
      int d = int.parse(match3.group(1)!);
      int m = int.parse(match3.group(2)!);
      String yStr = match3.group(3)!;
      int y = yStr.length == 2 ? 2000 + int.parse(yStr) : int.parse(yStr);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    }

    return null;
  }

  static String? extractBankName(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('kerala grameena bank') || lower.contains('kerala gramin bank') || lower.contains('kg bank') || lower.contains('kgbank')) {
      return 'Kerala Grameena Bank';
    }
    if (lower.contains('bank of baroda') || lower.contains('bob')) {
      return 'Bank of Baroda';
    }
    if (lower.contains('hdfc')) {
      return 'HDFC Bank';
    }
    if (lower.contains('state bank of india') || lower.contains('sbi')) {
      return 'State Bank of India';
    }
    if (lower.contains('icici')) {
      return 'ICICI Bank';
    }
    if (lower.contains('axis')) {
      return 'Axis Bank';
    }
    return null;
  }

  static String guessCategory(String? merchant) {
    if (merchant == null || merchant.isEmpty) return 'Others';
    final lower = merchant.toLowerCase();
    
    if (lower.contains('zomato') || lower.contains('swiggy') || lower.contains('kfc') || lower.contains('mcdonald') || lower.contains('dominos') || lower.contains('food') || lower.contains('dinner') || lower.contains('lunch') || lower.contains('cafe') || lower.contains('restaurant')) {
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
