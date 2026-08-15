import '../models/account.dart';
import '../services/sms_service.dart';

class AccountRepository {
  Future<List<Account>> getAccounts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final mockAccounts = SmsService().linkedAccounts;
    // Map SmsService AccountInfo to new Account model
    return mockAccounts.map((a) => Account(
      id: a.accountNumber, // Mock ID
      name: '${a.bankName} Account',
      bankName: a.bankName,
      accountNumber: a.accountNumber,
      accountType: a.accountType,
      balance: a.balance,
      accentColor: a.accentColor,
      createdAt: DateTime.now(),
    )).toList();
  }

  Future<Account?> getAccountById(String id) async {
    final accounts = await getAccounts();
    try {
      return accounts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addAccount(Account account) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> updateAccount(Account account) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> deleteAccount(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
