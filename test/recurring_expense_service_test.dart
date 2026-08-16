import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/recurring_expense_service.dart';
import 'package:expense_tracker/repositories/recurring_expense_repository.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/models/recurring_expense.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;

class MockRecurringExpenseRepository implements RecurringExpenseRepository {
  List<RecurringExpense> expenses = [];
  bool updateCalled = false;

  @override
  Future<List<RecurringExpense>> getRecurringExpenses() async {
    return expenses;
  }

  @override
  Future<void> updateRecurringExpense(RecurringExpense expense) async {
    updateCalled = true;
    final index = expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) expenses[index] = expense;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTransactionRepository implements TransactionRepository {
  List<model_tx.Transaction> transactions = [];

  @override
  Future<model_tx.Transaction?> getTransactionById(String id) async {
    try {
      return transactions.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> addTransaction(model_tx.Transaction transaction) async {
    transactions.add(transaction);
    return transaction.id;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RecurringExpenseService Logic', () {
    late MockRecurringExpenseRepository recurringRepo;
    late MockTransactionRepository transactionRepo;
    late RecurringExpenseService service;

    setUp(() {
      recurringRepo = MockRecurringExpenseRepository();
      transactionRepo = MockTransactionRepository();
      service = RecurringExpenseService(
        recurringRepo: recurringRepo,
        transactionRepo: transactionRepo,
      );
    });

    test('isSameDay correctly identifies same day regardless of time', () {
      final d1 = DateTime(2026, 1, 1, 12, 0);
      final d2 = DateTime(2026, 1, 1, 23, 59);
      final d3 = DateTime(2026, 1, 2, 0, 1);

      expect(service.isSameDay(d1, d2), isTrue);
      expect(service.isSameDay(d1, d3), isFalse);
    });

    test('processDueExpenses prevents duplicates for same occurrence', () async {
      final now = DateTime.now();
      final expense = RecurringExpense(
        id: 'req_1',
        title: 'Netflix',
        amount: 15.0,
        category: 'Entertainment',
        accountId: 'bank_id',
        frequency: 'monthly',
        startDate: now,
        nextOccurrence: now,
        createdAt: now,
        updatedAt: now,
      );

      recurringRepo.expenses.add(expense);

      // First run
      await service.processDueExpenses();
      expect(transactionRepo.transactions.length, 1);
      final createdTxId = transactionRepo.transactions.first.id;
      expect(recurringRepo.updateCalled, isTrue);

      // Rewind date back to simulate running it again improperly
      final updatedExpense = recurringRepo.expenses.first;
      recurringRepo.expenses[0] = RecurringExpense(
        id: updatedExpense.id,
        title: updatedExpense.title,
        amount: updatedExpense.amount,
        category: updatedExpense.category,
        accountId: updatedExpense.accountId,
        frequency: updatedExpense.frequency,
        startDate: updatedExpense.startDate,
        nextOccurrence: now, // rewound
        createdAt: updatedExpense.createdAt,
        updatedAt: updatedExpense.updatedAt,
      );
      
      recurringRepo.updateCalled = false;

      // Second run
      await service.processDueExpenses();

      // Transaction shouldn't be duplicated, but nextOccurrence should still advance.
      expect(transactionRepo.transactions.length, 1);
      expect(transactionRepo.transactions.first.id, createdTxId);
      expect(recurringRepo.updateCalled, isTrue); // Should self-heal and advance the date
    });
  });
}
