import '../models/transaction.dart';
import '../services/sms_service.dart';

class TransactionRepository {
  // Temporary mock implementation using SmsService
  
  Future<List<Transaction>> getTransactions() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return SmsService().parsedTransactions;
  }

  Future<Transaction?> getTransactionById(String id) async {
    final transactions = await getTransactions();
    try {
      return transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addTransaction(Transaction transaction) async {
    // In a real app, this would write to Firestore
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> updateTransaction(Transaction transaction) async {
    // In a real app, this would update Firestore
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> deleteTransaction(String id) async {
    // In a real app, this would delete from Firestore
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
