import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../models/transaction.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';

enum QuickDateRange {
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  custom,
}

class ExportSummary {
  final int count;
  final double totalAmount;
  final DateTime startDate;
  final DateTime endDate;

  const ExportSummary({
    required this.count,
    required this.totalAmount,
    required this.startDate,
    required this.endDate,
  });

  bool get isEmpty => count == 0;
}

class ExportResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final ExportSummary summary;
  final String? errorMessage;
  final bool isEmpty;

  const ExportResult({
    required this.success,
    this.filePath,
    this.fileName,
    required this.summary,
    this.errorMessage,
    this.isEmpty = false,
  });

  factory ExportResult.success({
    required String filePath,
    required String fileName,
    required ExportSummary summary,
  }) {
    return ExportResult(
      success: true,
      filePath: filePath,
      fileName: fileName,
      summary: summary,
    );
  }

  factory ExportResult.empty({required ExportSummary summary}) {
    return ExportResult(
      success: true,
      summary: summary,
      isEmpty: true,
    );
  }

  factory ExportResult.failure({
    required String errorMessage,
    required ExportSummary summary,
  }) {
    return ExportResult(
      success: false,
      errorMessage: errorMessage,
      summary: summary,
    );
  }
}

class ExportService {
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;

  ExportService({
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
  })  : _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  /// Resolves the inclusive start and end DateTime bounds for a date range.
  static (DateTime start, DateTime end) getInclusiveBounds(DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return (start, end);
  }

  /// Calculates start and end dates for quick date ranges.
  static (DateTime start, DateTime end) calculateQuickRange(QuickDateRange range, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (range) {
      case QuickDateRange.today:
        return (today, today);

      case QuickDateRange.thisWeek:
        // Week starting on Monday
        final daysFromMonday = (today.weekday - DateTime.monday) % 7;
        final startOfWeek = today.subtract(Duration(days: daysFromMonday));
        return (startOfWeek, today);

      case QuickDateRange.thisMonth:
        final startOfMonth = DateTime(today.year, today.month, 1);
        return (startOfMonth, today);

      case QuickDateRange.lastMonth:
        final firstOfThisMonth = DateTime(today.year, today.month, 1);
        final lastOfLastMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        final firstOfLastMonth = DateTime(lastOfLastMonth.year, lastOfLastMonth.month, 1);
        return (firstOfLastMonth, lastOfLastMonth);

      case QuickDateRange.last3Months:
        // Beginning of 2 months prior to current month
        final monthOffset = today.month - 2;
        final startYear = monthOffset > 0 ? today.year : today.year - 1;
        final startMonth = monthOffset > 0 ? monthOffset : 12 + monthOffset;
        final start = DateTime(startYear, startMonth, 1);
        return (start, today);

      case QuickDateRange.thisYear:
        final startOfYear = DateTime(today.year, 1, 1);
        return (startOfYear, today);

      case QuickDateRange.custom:
        final startOfMonth = DateTime(today.year, today.month, 1);
        return (startOfMonth, today);
    }
  }

  /// Retrieves canonical expense transactions strictly within the selected inclusive date range.
  Future<List<Transaction>> getExpenseTransactions({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('Start date cannot be after end date.');
    }

    final (startBound, endBound) = getInclusiveBounds(startDate, endDate);
    final allTransactions = await _transactionRepo.getTransactions();

    final expenseTransactions = allTransactions.where((tx) {
      if (tx.type != TransactionType.expense) return false;
      return !tx.date.isBefore(startBound) && !tx.date.isAfter(endBound);
    }).toList();

    // Sort newest first
    expenseTransactions.sort((a, b) => b.date.compareTo(a.date));
    return expenseTransactions;
  }

  /// Calculates summary metrics (count and total amount) for given transactions.
  ExportSummary calculateSummary(
    List<Transaction> transactions, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final count = transactions.length;
    final totalAmount = transactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.amount,
    );

    return ExportSummary(
      count: count,
      totalAmount: totalAmount,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Generates sanitized filename for the export.
  String generateFileName({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);
    return 'MoneyTrack_Expenses_${startStr}_to_$endStr.csv';
  }

  /// Generates RFC-4180 compliant CSV string from canonical transactions.
  String generateCsvData(
    List<Transaction> transactions, {
    Map<String, Account>? accountMap,
  }) {
    final List<List<dynamic>> rows = [];

    // Header Row
    rows.add([
      'Date',
      'Time',
      'Title',
      'Merchant',
      'Amount (INR)',
      'Category',
      'Account',
      'Bank',
      'Payment Method',
      'Transaction Source',
      'Reference ID',
      'Notes',
    ]);

    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('hh:mm a');

    for (final tx in transactions) {
      final acc = tx.accountId != null && accountMap != null ? accountMap[tx.accountId] : null;

      // Date & Time
      final dateStr = dateFormat.format(tx.date);
      final timeStr = timeFormat.format(tx.date);

      // Title & Merchant
      final titleStr = tx.displayTitle;
      final merchantStr = (tx.merchant.isNotEmpty && tx.merchant.toLowerCase() != 'unknown merchant')
          ? tx.merchant
          : '';

      // Amount
      final amountStr = tx.amount.toStringAsFixed(2);

      // Category
      final categoryStr = tx.displayCategory;

      // Account & Bank
      String accountStr = '';
      if (acc != null && acc.accountNumber.isNotEmpty) {
        accountStr = acc.maskedAccountNumber;
      } else if (tx.accountNumber != null && tx.accountNumber!.isNotEmpty) {
        final accNum = tx.accountNumber!;
        accountStr = accNum.length > 4 ? '****${accNum.substring(accNum.length - 4)}' : accNum;
      }

      final bankStr = acc?.bankName ?? '';

      // Payment Method, Source, Reference ID, Notes
      final paymentMethodStr = tx.paymentMethod ?? '';
      final sourceStr = tx.transactionSource.toUpperCase();
      final refStr = tx.upiReference ?? '';
      final notesStr = tx.notes ?? '';

      rows.add([
        dateStr,
        timeStr,
        titleStr,
        merchantStr,
        amountStr,
        categoryStr,
        accountStr,
        bankStr,
        paymentMethodStr,
        sourceStr,
        refStr,
        notesStr,
      ]);
    }

    const converter = ListToCsvConverter(
      eol: '\r\n', // Standard Windows/Excel CRLF line endings
    );
    final csvBody = converter.convert(rows);

    // Prefix with UTF-8 BOM (\uFEFF) to ensure Microsoft Excel correctly opens UTF-8 characters
    return '\uFEFF$csvBody';
  }

  /// Determines the best user-accessible storage directory on the device.
  Future<Directory> getExportDirectory() async {
    if (Platform.isAndroid) {
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final moneyTrackDir = Directory(p.join(downloadDir.path, 'MoneyTrack'));
          if (!await moneyTrackDir.exists()) {
            await moneyTrackDir.create(recursive: true);
          }
          return moneyTrackDir;
        }
      } catch (e) {
        developer.log('Error creating Android Download/MoneyTrack directory: $e', name: 'ExportService');
      }

      try {
        final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (externalDirs != null && externalDirs.isNotEmpty) {
          return externalDirs.first;
        }
      } catch (e) {
        developer.log('Error getting external storage downloads: $e', name: 'ExportService');
      }
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir;
    } catch (_) {}

    return await getApplicationDocumentsDirectory();
  }

  /// Full export workflow: queries expenses, calculates summary, creates CSV and writes to storage.
  Future<ExportResult> exportExpensesToCsv({
    required DateTime startDate,
    required DateTime endDate,
    Directory? customDirectory,
  }) async {
    try {
      if (startDate.isAfter(endDate)) {
        return ExportResult.failure(
          errorMessage: 'Start date cannot be after end date.',
          summary: ExportSummary(count: 0, totalAmount: 0.0, startDate: startDate, endDate: endDate),
        );
      }

      developer.log(
        'Starting export for range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        name: 'ExportService',
      );

      // 1. Fetch filtered expense transactions
      final transactions = await getExpenseTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      final summary = calculateSummary(
        transactions,
        startDate: startDate,
        endDate: endDate,
      );

      if (transactions.isEmpty) {
        return ExportResult.empty(summary: summary);
      }

      // 2. Fetch accounts map for bank/account enrichment
      Map<String, Account> accountMap = {};
      try {
        final accounts = await _accountRepo.getAccounts();
        for (final acc in accounts) {
          accountMap[acc.id] = acc;
        }
      } catch (e) {
        developer.log('Warning: could not fetch accounts: $e', name: 'ExportService');
      }

      // 3. Generate CSV data
      final csvContent = generateCsvData(transactions, accountMap: accountMap);

      // 4. Resolve destination directory and file path
      final targetDir = customDirectory ?? await getExportDirectory();
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final fileName = generateFileName(startDate: startDate, endDate: endDate);
      final filePath = p.join(targetDir.path, fileName);
      final file = File(filePath);

      // 5. Write file with UTF-8 encoding
      await file.writeAsString(csvContent, encoding: utf8, flush: true);

      developer.log('Export file written successfully: $filePath', name: 'ExportService');

      return ExportResult.success(
        filePath: filePath,
        fileName: fileName,
        summary: summary,
      );
    } catch (e, stack) {
      developer.log('Export failed with error: $e', stackTrace: stack, name: 'ExportService');
      return ExportResult.failure(
        errorMessage: 'Failed to export expense data. Please try again.',
        summary: ExportSummary(count: 0, totalAmount: 0.0, startDate: startDate, endDate: endDate),
      );
    }
  }
}
