import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/sms_models.dart';
import '../models/transaction.dart' as model_tx;
import '../repositories/transaction_repository.dart';
import '../utils/expense_parser.dart';

enum SmsImportResult { imported, duplicate, skipped, failed }

class SmsImportSummary {
  int scanned = 0;
  int imported = 0;
  int duplicates = 0;
  int skipped = 0;
  int failed = 0;

  @override
  String toString() {
    return '$scanned scanned • $imported imported • $duplicates duplicates • $skipped skipped';
  }
}

class SmsTransactionImporter {
  final TransactionRepository transactionRepo;

  SmsTransactionImporter({required this.transactionRepo});

  Future<SmsImportResult> importMessage(Message msg, String senderName) async {
    try {
      final parsed = ExpenseParser.parse(msg.text);
      if (parsed == null) {
        return SmsImportResult.skipped;
      }

      // Generate deterministic fingerprint
      final normalizedSender = senderName.trim().toLowerCase();
      final normalizedBody = msg.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final timestampIso = msg.timestamp.toUtc().toIso8601String();
      
      final rawString = '${normalizedSender}_${timestampIso}_$normalizedBody';
      final bytes = utf8.encode(rawString);
      final digest = sha256.convert(bytes);
      final fingerprint = digest.toString();
      final deterministicId = 'sms_$fingerprint';

      // Convert to Transaction
      final transaction = model_tx.Transaction(
        id: deterministicId,
        amount: parsed.amount,
        type: parsed.type,
        merchant: parsed.merchant ?? 'Unknown Merchant',
        category: ExpenseParser.guessCategory(parsed.merchant),
        date: msg.timestamp,
        subtitle: senderName,
        rawMessage: msg.text,
        source: 'sms',
        isManual: false,
      );

      // Duplicate prevention: Atomic check
      final success = await transactionRepo.addTransactionIfAbsent(transaction);
      if (!success) {
        return SmsImportResult.duplicate;
      }

      return SmsImportResult.imported;
    } catch (e) {
      return SmsImportResult.failed;
    }
  }

  Future<SmsImportSummary> importAllBankMessages(List<Conversation> conversations) async {
    final summary = SmsImportSummary();

    for (var conv in conversations) {
      if (conv.isBankSender) {
        for (var msg in conv.messages) {
          summary.scanned++;
          final result = await importMessage(msg, conv.senderName);
          switch (result) {
            case SmsImportResult.imported:
              summary.imported++;
              break;
            case SmsImportResult.duplicate:
              summary.duplicates++;
              break;
            case SmsImportResult.skipped:
              summary.skipped++;
              break;
            case SmsImportResult.failed:
              summary.failed++;
              break;
          }
        }
      }
    }

    return summary;
  }
}
