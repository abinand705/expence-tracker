import 'package:intl/intl.dart';
import 'package:expense_tracker/models/recurring_expense.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/repositories/recurring_expense_repository.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';

class RecurringExpenseService {
  final RecurringExpenseRepository _recurringRepo;
  final TransactionRepository _transactionRepo;

  RecurringExpenseService({
    RecurringExpenseRepository? recurringRepo,
    TransactionRepository? transactionRepo,
  })  : _recurringRepo = recurringRepo ?? RecurringExpenseRepository(),
        _transactionRepo = transactionRepo ?? TransactionRepository();

  Future<void> processDueExpenses() async {
    final expenses = await _recurringRepo.getRecurringExpenses();
    final now = DateTime.now();

    for (var expense in expenses) {
      if (!expense.isActive) continue;

      var currentOccurrence = expense.nextOccurrence;
      bool updated = false;

      // Ensure we don't infinitely loop by setting a hard limit for catch-ups
      int loopSafeGuard = 0;
      const int maxCatchupLimit = 60; 

      while (currentOccurrence.isBefore(now) || isSameDay(currentOccurrence, now)) {
        if (expense.endDate != null && currentOccurrence.isAfter(expense.endDate!)) {
          break;
        }

        if (loopSafeGuard > maxCatchupLimit) {
          break; // Avoid infinite loops in extreme cases
        }
        loopSafeGuard++;

        final transactionId = _generateDeterministicTransactionId(expense.id, currentOccurrence);
        
        final tx = model_tx.Transaction(
          id: transactionId,
          amount: expense.amount,
          type: model_tx.TransactionType.expense,
          merchant: expense.title,
          category: expense.category,
          accountId: expense.accountId,
          date: currentOccurrence,
          isRecurring: true,
        );

        await _transactionRepo.addTransactionIfAbsent(tx);

        // Calculate next occurrence regardless of whether it already existed (self-healing iteration)
        currentOccurrence = _calculateNextOccurrence(currentOccurrence, expense.frequency);
        updated = true;
      }

      if (updated) {
        final updatedExpense = RecurringExpense(
          id: expense.id,
          title: expense.title,
          amount: expense.amount,
          category: expense.category,
          accountId: expense.accountId,
          frequency: expense.frequency,
          startDate: expense.startDate,
          nextOccurrence: currentOccurrence,
          endDate: expense.endDate,
          isActive: expense.isActive,
          createdAt: expense.createdAt,
          updatedAt: DateTime.now(),
        );
        await _recurringRepo.updateRecurringExpense(updatedExpense);
      }
    }
  }

  String _generateDeterministicTransactionId(String recurringId, DateTime occurrence) {
    final dateStr = DateFormat('yyyy-MM-dd').format(occurrence);
    return '${recurringId}_$dateStr';
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _calculateNextOccurrence(DateTime current, String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        // Handle month-end wrapping:
        // e.g., Jan 31 -> Feb 28/29
        final targetMonth = current.month == 12 ? 1 : current.month + 1;
        final targetYear = current.month == 12 ? current.year + 1 : current.year;
        
        // Get last day of target month
        final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        
        // Target day is the minimum of original day and last day of target month
        final targetDay = current.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : current.day;
        return DateTime(targetYear, targetMonth, targetDay, current.hour, current.minute);
      case 'yearly':
        // Handle leap years Feb 29 -> Feb 28 next year natively in most cases, 
        // but explicit bounds check is safe
        final targetYear = current.year + 1;
        final isLeapYear = (targetYear % 4 == 0) && ((targetYear % 100 != 0) || (targetYear % 400 == 0));
        
        if (current.month == 2 && current.day == 29 && !isLeapYear) {
           return DateTime(targetYear, 2, 28, current.hour, current.minute);
        }
        return DateTime(targetYear, current.month, current.day, current.hour, current.minute);
      default:
        return current.add(const Duration(days: 30)); // fallback
    }
  }
}
