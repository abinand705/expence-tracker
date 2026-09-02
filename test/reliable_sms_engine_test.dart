import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/sms_models.dart';
import 'package:expense_tracker/models/transaction.dart' as model_tx;
import 'package:expense_tracker/repositories/account_repository.dart';
import 'package:expense_tracker/repositories/pending_due_repository.dart';
import 'package:expense_tracker/repositories/transaction_repository.dart';
import 'package:expense_tracker/services/sms_account_resolver.dart';
import 'package:expense_tracker/services/sms_transaction_importer.dart';
import 'package:expense_tracker/models/pending_due.dart';
import 'package:expense_tracker/utils/expense_parser.dart';

class FakeTransactionRepository implements TransactionRepository {
  final Map<String, model_tx.Transaction> transactions = {};

  @override
  Future<bool> addTransactionIfAbsent(model_tx.Transaction transaction) async {
    if (transactions.containsKey(transaction.id)) {
      return false;
    }
    transactions[transaction.id] = transaction;
    return true;
  }

  @override
  Future<String> addTransaction(model_tx.Transaction transaction) async {
    transactions[transaction.id] = transaction;
    return transaction.id;
  }

  @override
  Future<List<model_tx.Transaction>> getTransactions() async {
    final list = transactions.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<List<model_tx.Transaction>> getTransactionsForAccount(String accountId) async {
    return transactions.values.where((t) => t.accountId == accountId).toList();
  }

  @override
  Future<model_tx.Transaction?> getTransactionById(String id) async => transactions[id];

  @override
  Future<void> batchAddTransactions(List<model_tx.Transaction> txList) async {
    for (var t in txList) {
      transactions[t.id] = t;
    }
  }

  @override
  Future<void> updateTransaction(model_tx.Transaction transaction) async {
    transactions[transaction.id] = transaction;
  }

  @override
  Future<void> updateTransactionTitle(String transactionId, String? customTitle) async {
    if (transactions.containsKey(transactionId)) {
      transactions[transactionId] = transactions[transactionId]!.copyWith(customTitle: customTitle);
    }
  }

  @override
  Future<void> updateTransactionCategory(String transactionId, String category) async {
    if (transactions.containsKey(transactionId)) {
      final normalized = model_tx.TransactionCategory.normalize(category);
      transactions[transactionId] = transactions[transactionId]!.copyWith(
        customCategory: normalized,
        category: normalized,
      );
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    transactions.remove(id);
  }

  @override
  Stream<List<model_tx.Transaction>> watchTransactions() => Stream.value(transactions.values.toList());
}

class FakeAccountRepository implements AccountRepository {
  final Map<String, Account> accounts = {};

  @override
  Future<List<Account>> getAccounts() async => accounts.values.toList();

  @override
  Future<Account?> getAccountById(String id) async => accounts[id];

  @override
  Future<String> addAccount(Account account) async {
    accounts[account.id] = account;
    return account.id;
  }

  @override
  Future<bool> addAccountIfAbsent(Account account) async {
    if (accounts.containsKey(account.id)) return false;
    accounts[account.id] = account;
    return true;
  }

  @override
  Future<void> updateAccount(Account account) async {
    accounts[account.id] = account;
  }

  @override
  Future<void> deleteAccount(String id) async {
    accounts.remove(id);
  }

  @override
  Stream<List<Account>> watchAccounts() => Stream.value(accounts.values.toList());

  @override
  Future<int> migrateAndCleanupAutoDiscoveredAccounts() async => 0;

  @override
  Future<void> cleanupLegacyAutoDiscoveredAccounts(String canonicalAccountId, String bankId, String last4) async {}

  @override
  void setInstancesForTesting(dynamic firestore, dynamic auth) {}
}

class FakePendingDueRepository implements PendingDueRepository {
  final List<PendingDue> dues = [];
  @override
  Future<bool> addPendingDueIfAbsent(PendingDue due) async {
    dues.add(due);
    return true;
  }
  @override
  Future<List<PendingDue>> getPendingDues() async => dues;
  @override
  Future<void> deletePendingDue(String id) async {
    dues.removeWhere((d) => d.id == id);
  }
  @override
  Stream<List<PendingDue>> watchPendingDues() => Stream.value(dues);
}

void main() {
  group('Reliable SMS Transaction & Account Balance Engine Tests', () {
    late FakeTransactionRepository txRepo;
    late FakeAccountRepository accRepo;
    late FakePendingDueRepository dueRepo;
    late SmsTransactionImporter importer;
    late SmsAccountResolver resolver;

    setUp(() {
      txRepo = FakeTransactionRepository();
      accRepo = FakeAccountRepository();
      dueRepo = FakePendingDueRepository();
      importer = SmsTransactionImporter(
        transactionRepo: txRepo,
        pendingDueRepo: dueRepo,
        accountRepo: accRepo,
      );
      resolver = SmsAccountResolver();
    });

    test('Section 32: Exact Real Sample Bank SMS parsing and execution', () async {
      final sampleSms = "After debit of Rs 25,your A/c XXXXXXXXXX0544 Bal standsRs 286.5 Msg Id 27123456 Time 01-09-2026 20:21:36 -Kerala Grameena Bank";

      // 1. Parser verification
      final parsed = ExpenseParser.parse(sampleSms);
      expect(parsed, isNotNull);
      expect(parsed!.type, model_tx.TransactionType.expense);
      expect(parsed.amount, 25.00);
      expect(parsed.availableBalance, 286.50);
      expect(parsed.accountNumber, '0544');
      expect(SmsAccountResolver.extractLast3Digits(parsed.accountNumber), '544');
      expect(parsed.bankName, 'Kerala Grameena Bank');
      expect(parsed.messageId, '27123456');
      expect(parsed.transactionTimestamp, DateTime(2026, 9, 1, 20, 21, 36));

      // 2. Setup user's existing account matching Kerala Grameena Bank + last 3 digits 544
      final kgbAccount = Account(
        id: 'user_kgb_canonical_123',
        name: 'My Savings',
        bankName: 'Kerala Grameena Bank',
        accountNumber: 'XXXX0544',
        accountType: 'Savings',
        currentBalance: 311.50,
        balanceSource: 'manual',
        accentColor: Colors.green,
      );
      await accRepo.addAccount(kgbAccount);

      // 3. Process the SMS
      final msg = Message(
        id: 'sms_1',
        text: sampleSms,
        timestamp: DateTime(2026, 9, 1, 20, 22, 00),
        isMe: false,
      );
      final result = await importer.importMessage(msg, 'VK-KGBANK', resolver, dueRepo, [kgbAccount]);

      expect(result, SmsImportResult.imported);

      // 4. Verify transaction created
      final allTx = await txRepo.getTransactions();
      expect(allTx.length, 1);
      final tx = allTx.first;
      expect(tx.amount, 25.00);
      expect(tx.type, model_tx.TransactionType.expense);
      expect(tx.accountId, 'user_kgb_canonical_123');
      expect(tx.upiReference, '27123456');
      expect(tx.date, DateTime(2026, 9, 1, 20, 21, 36));

      // 5. Verify account current balance updated
      final updatedAcc = await accRepo.getAccountById('user_kgb_canonical_123');
      expect(updatedAcc, isNotNull);
      expect(updatedAcc!.currentBalance, 286.50);
      expect(updatedAcc.balanceSource, 'sms');
      expect(updatedAcc.balanceUpdatedAt, DateTime(2026, 9, 1, 20, 21, 36));
    });

    test('Section 33: SMS with No Balance creates expense and calculates balance safely', () async {
      final noBalSms = "Rs 25 debited from your A/c XXXXX544 on 01-09-2026";

      final parsed = ExpenseParser.parse(noBalSms);
      expect(parsed, isNotNull);
      expect(parsed!.amount, 25.00);
      expect(parsed.type, model_tx.TransactionType.expense);
      expect(parsed.availableBalance, isNull);
      expect(SmsAccountResolver.extractLast3Digits(parsed.accountNumber), '544');

      // User account with previous reliable balance 311.50
      final acc = Account(
        id: 'acc_544',
        name: 'KGB Salary',
        bankName: 'Kerala Gramin Bank',
        accountNumber: 'XXXXX544',
        accountType: 'Savings',
        currentBalance: 311.50,
        balanceUpdatedAt: DateTime(2026, 8, 31),
        accentColor: Colors.blue,
      );
      await accRepo.addAccount(acc);

      final msg = Message(
        id: 'sms_nobal',
        text: noBalSms,
        timestamp: DateTime(2026, 9, 1, 10, 0, 0),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'KGBANK', resolver, dueRepo, [acc]);
      expect(result, SmsImportResult.imported);

      final updatedAcc = await accRepo.getAccountById('acc_544');
      expect(updatedAcc!.currentBalance, 286.50);
    });

    test('Section 34, 35, 36: Suffix variations (3-digit, 4-digit, 5-digit) all resolve to correct account', () {
      final acc = Account(
        id: 'acc_target',
        name: 'Target Account',
        bankName: 'Bank of Baroda',
        accountNumber: 'XXXXXXXXXX0544',
        accountType: 'Savings',
        accentColor: Colors.orange,
      );
      final accounts = [acc];

      // 3-digit: XXX544
      final r3 = resolver.resolveAccount(bankIdOrName: 'bob', rawAccountOrSuffix: 'XXX544', accounts: accounts);
      expect(r3, 'acc_target');

      // 4-digit: XXXX0544
      final r4 = resolver.resolveAccount(bankIdOrName: 'bob', rawAccountOrSuffix: 'XXXX0544', accounts: accounts);
      expect(r4, 'acc_target');

      // 5-digit: XXXXX0544
      final r5 = resolver.resolveAccount(bankIdOrName: 'bob', rawAccountOrSuffix: 'XXXXX0544', accounts: accounts);
      expect(r5, 'acc_target');

      // Direct 3 digits: 544
      final rDirect = resolver.resolveAccount(bankIdOrName: 'bob', rawAccountOrSuffix: '544', accounts: accounts);
      expect(rDirect, 'acc_target');
    });

    test('Section 37: Ambiguity Protection — same last 3 digits across multiple banks without bank returns null', () {
      final kgb = Account(
        id: 'kgb_1',
        name: 'KGB',
        bankName: 'Kerala Grameena Bank',
        accountNumber: 'XXXX544',
        accountType: 'Savings',
        accentColor: Colors.green,
      );
      final sbi = Account(
        id: 'sbi_1',
        name: 'SBI',
        bankName: 'State Bank of India',
        accountNumber: 'XXXX544',
        accountType: 'Savings',
        accentColor: Colors.blue,
      );
      final accounts = [kgb, sbi];

      // Without bank info, matching "544" is ambiguous across KGB and SBI
      final matched = resolver.resolveAccount(
        bankIdOrName: null,
        rawAccountOrSuffix: 'account ending 544',
        accounts: accounts,
      );
      expect(matched, isNull);
    });

    test('Section 38: Bank + Last3 resolves correct bank when multiple banks share last3', () {
      final kgb = Account(
        id: 'kgb_1',
        name: 'KGB',
        bankName: 'Kerala Grameena Bank',
        accountNumber: 'XXXX544',
        accountType: 'Savings',
        accentColor: Colors.green,
      );
      final sbi = Account(
        id: 'sbi_1',
        name: 'SBI',
        bankName: 'State Bank of India',
        accountNumber: 'XXXX544',
        accountType: 'Savings',
        accentColor: Colors.blue,
      );
      final accounts = [kgb, sbi];

      final matched = resolver.resolveAccount(
        bankIdOrName: 'Kerala Grameena Bank',
        rawAccountOrSuffix: 'XXXX544',
        accounts: accounts,
      );
      expect(matched, 'kgb_1');
    });

    test('Section 39: Deduplication — repeated scanning 10 times creates exactly 1 transaction', () async {
      final sampleSms = "After debit of Rs 25,your A/c XXXXXXXXXX0544 Bal standsRs 286.5 Msg Id 27123456 Time 01-09-2026 20:21:36 -Kerala Grameena Bank";
      final acc = Account(
        id: 'acc_dedup',
        name: 'KGB',
        bankName: 'Kerala Grameena Bank',
        accountNumber: '0544',
        accountType: 'Savings',
        currentBalance: 311.50,
        accentColor: Colors.green,
      );
      await accRepo.addAccount(acc);

      final msg = Message(
        id: 'msg_repeat',
        text: sampleSms,
        timestamp: DateTime(2026, 9, 1, 20, 22, 0),
        isMe: false,
      );

      // Run 1st time
      final r1 = await importer.importMessage(msg, 'VK-KGBANK', resolver, dueRepo, [acc]);
      expect(r1, SmsImportResult.imported);

      // Run 9 more times
      for (int i = 0; i < 9; i++) {
        final r = await importer.importMessage(msg, 'VK-KGBANK', resolver, dueRepo, [acc]);
        expect(r, SmsImportResult.duplicate);
      }

      final allTx = await txRepo.getTransactions();
      expect(allTx.length, 1);

      final finalAcc = await accRepo.getAccountById('acc_dedup');
      expect(finalAcc!.currentBalance, 286.50);
    });

    test('Section 40: Explicit Balance Priority — uses explicit balance rather than delta math', () async {
      final explicitSms = "Debit Rs 25 from A/c XX544. Available balance: Rs 286.50";
      final acc = Account(
        id: 'acc_explicit',
        name: 'KGB',
        bankName: 'Kerala Grameena Bank',
        accountNumber: '544',
        accountType: 'Savings',
        currentBalance: 311.50,
        accentColor: Colors.green,
      );
      await accRepo.addAccount(acc);

      final msg = Message(
        id: 'msg_exp',
        text: explicitSms,
        timestamp: DateTime(2026, 9, 1, 12, 0, 0),
        isMe: false,
      );

      await importer.importMessage(msg, 'KGBANK', resolver, dueRepo, [acc]);
      final updated = await accRepo.getAccountById('acc_explicit');
      expect(updated!.currentBalance, 286.50);
    });

    test('Section 41: Calculated Balance without double deduction on repeated scan', () async {
      final noBalSms = "Rs 25 debited from A/c XXX544";
      final acc = Account(
        id: 'acc_no_double',
        name: 'KGB',
        bankName: 'Kerala Grameena Bank',
        accountNumber: '544',
        accountType: 'Savings',
        currentBalance: 311.50,
        balanceUpdatedAt: DateTime(2026, 8, 31),
        accentColor: Colors.green,
      );
      await accRepo.addAccount(acc);

      final msg = Message(
        id: 'msg_calc',
        text: noBalSms,
        timestamp: DateTime(2026, 9, 1, 12, 0, 0),
        isMe: false,
      );

      // 1st scan -> 311.50 - 25 = 286.50
      await importer.importMessage(msg, 'KGBANK', resolver, dueRepo, [acc]);
      var updated = await accRepo.getAccountById('acc_no_double');
      expect(updated!.currentBalance, 286.50);

      // 2nd scan of same SMS -> duplicate -> stays 286.50, NEVER becomes 261.50!
      await importer.importMessage(msg, 'KGBANK', resolver, dueRepo, [updated]);
      var updated2 = await accRepo.getAccountById('acc_no_double');
      expect(updated2!.currentBalance, 286.50);
    });

    test('Section 42: Credit calculation adds amount to reliable previous balance', () async {
      final creditSms = "Rs 100 credited to your A/c ending 544";
      final acc = Account(
        id: 'acc_credit',
        name: 'KGB',
        bankName: 'Kerala Grameena Bank',
        accountNumber: '544',
        accountType: 'Savings',
        currentBalance: 286.50,
        balanceUpdatedAt: DateTime(2026, 9, 1, 10, 0),
        accentColor: Colors.green,
      );
      await accRepo.addAccount(acc);

      final msg = Message(
        id: 'msg_credit',
        text: creditSms,
        timestamp: DateTime(2026, 9, 1, 14, 0),
        isMe: false,
      );

      await importer.importMessage(msg, 'KGBANK', resolver, dueRepo, [acc]);
      final updated = await accRepo.getAccountById('acc_credit');
      expect(updated!.currentBalance, 386.50);
    });

    test('Section 43: Statement Authority — statement balance is preserved against older SMS', () async {
      final statementDate = DateTime(2026, 8, 30);
      final acc = Account(
        id: 'acc_statement',
        name: 'HDFC',
        bankName: 'HDFC Bank',
        accountNumber: '1234',
        accountType: 'Savings',
        currentBalance: 500.00,
        balanceSource: 'statement',
        balanceUpdatedAt: statementDate,
        lastStatementImportAt: statementDate,
        accentColor: Colors.blue,
      );
      await accRepo.addAccount(acc);

      // 1. Older SMS balance dated 2026-08-25: should NOT overwrite statement balance
      final olderSms = "Rs 50 debited from A/c 1234. Avl Bal Rs 450 on 25-08-2026";
      final msgOlder = Message(
        id: 'msg_older',
        text: olderSms,
        timestamp: DateTime(2026, 8, 25, 10, 0),
        isMe: false,
      );
      await importer.importMessage(msgOlder, 'HDFCBK', resolver, dueRepo, [acc]);
      var check1 = await accRepo.getAccountById('acc_statement');
      expect(check1!.currentBalance, 500.00); // Preserved!

      // 2. Newer SMS balance dated 2026-09-01: CAN update statement balance
      final newerSms = "Rs 25 debited from A/c 1234. Avl Bal Rs 475 on 01-09-2026";
      final msgNewer = Message(
        id: 'msg_newer',
        text: newerSms,
        timestamp: DateTime(2026, 9, 1, 10, 0),
        isMe: false,
      );
      await importer.importMessage(msgNewer, 'HDFCBK', resolver, dueRepo, [check1]);
      var check2 = await accRepo.getAccountById('acc_statement');
      expect(check2!.currentBalance, 475.00);
      expect(check2.balanceSource, 'sms');
    });

    test('Section 44: Random Numbers Safety — differentiates Amount, Balance, Msg ID, Time, and Account', () {
      final complexSms = "After debit of Rs 25,your A/c XXXXXXXXXX0544 Bal standsRs 286.5 Msg Id 27123456 Time 01-09-2026 20:21:36 -Kerala Grameena Bank";
      final parsed = ExpenseParser.parse(complexSms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 25.0); // Not 286.5, not 27123456, not 20
      expect(parsed.availableBalance, 286.5);
      expect(parsed.messageId, '27123456');
      expect(parsed.accountNumber, '0544');
      expect(parsed.transactionTimestamp, DateTime(2026, 9, 1, 20, 21, 36));
    });

    test('Section 24: Chronological Balance Timeline with multiple transactions and explicit checkpoint', () async {
      final acc = Account(
        id: 'acc_chrono',
        name: 'KGB',
        bankName: 'Kerala Grameena Bank',
        accountNumber: '544',
        accountType: 'Savings',
        currentBalance: 300.00,
        balanceUpdatedAt: DateTime(2026, 9, 1, 9, 0),
        accentColor: Colors.green,
      );
      await accRepo.addAccount(acc);

      final conv = Conversation(
        id: 'VK-KGBANK',
        senderName: 'VK-KGBANK',
        senderNumber: 'VK-KGBANK',
        avatarColor: Colors.green,
        isBankSender: true,
        messages: [
          // 10:00: Debit 25, No balance
          Message(
            id: 'm1',
            text: 'Rs 25 debited from A/c 544',
            timestamp: DateTime(2026, 9, 1, 10, 0),
            isMe: false,
          ),
          // 10:10: Debit 50, No balance
          Message(
            id: 'm2',
            text: 'Rs 50 debited from A/c 544',
            timestamp: DateTime(2026, 9, 1, 10, 10),
            isMe: false,
          ),
          // 10:20: Explicit balance SMS 225
          Message(
            id: 'm3',
            text: 'Your A/c 544 Bal stands Rs 225',
            timestamp: DateTime(2026, 9, 1, 10, 20),
            isMe: false,
          ),
        ],
      );

      final summary = await importer.importAllBankMessages([conv]);
      expect(summary.scanned, 3);
      expect(summary.imported, 2);
      expect(summary.skipped, 1);

      final finalAcc = await accRepo.getAccountById('acc_chrono');
      expect(finalAcc!.currentBalance, 225.00);
    });

    test('Section 29: Zero Unknown Account Creation — unresolvable accounts remain accountId = null without creating accounts', () async {
      // User has NO accounts registered
      expect(accRepo.accounts.isEmpty, isTrue);

      final sms = "Rs 150 debited from A/c XXXX999 at Store";
      final msg = Message(
        id: 'msg_unresolved',
        text: sms,
        timestamp: DateTime(2026, 9, 1, 12, 0),
        isMe: false,
      );

      final result = await importer.importMessage(msg, 'UNKNOWN-BANK', resolver, dueRepo, []);
      expect(result, SmsImportResult.imported);

      // Account repository must NOT have any new accounts created
      expect(accRepo.accounts.isEmpty, isTrue);

      // Transaction is still preserved with accountId = null
      final allTx = await txRepo.getTransactions();
      expect(allTx.length, 1);
      expect(allTx.first.amount, 150.0);
      expect(allTx.first.accountId, isNull);
    });
  });
}
