import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/controllers/auth_controller.dart';
import 'package:money_track/models/budget_item.dart';
import 'package:money_track/models/category_item.dart';
import 'package:money_track/models/transaction_item.dart';
import 'package:money_track/services/firestore_service.dart';

void main() {
  group('Firebase & Firestore Integration Unit Tests', () {
    test('TransactionItem converts toMap and fromMap correctly with integer amount and note', () {
      final now = DateTime(2026, 11, 26, 14, 30);
      final item = TransactionItem(
        id: 'tx_123',
        title: 'Dinner at Bistro',
        note: 'Dinner with colleagues',
        amount: 850,
        type: TransactionType.expense,
        date: now,
        category: 'Food & Dining',
      );

      final map = item.toMap(userId: 'user_test');
      expect(map['title'], 'Dinner at Bistro');
      expect(map['note'], 'Dinner with colleagues');
      expect(map['amount'], 850);
      expect(map['amount'], isA<int>());
      expect(map['type'], 'expense');
      expect(map['category'], 'Food & Dining');
      expect(map['date'], now.millisecondsSinceEpoch);
      expect(map['date_time'], now.toIso8601String());
      expect(map['date_string'], '2026-11-26');
      expect(map['time_string'], '14:30:00');
      expect(map['user_Id'], 'user_test');

      final reconstructed = TransactionItem.fromMap('tx_123', map);
      expect(reconstructed.id, 'tx_123');
      expect(reconstructed.note, 'Dinner with colleagues');
      expect(reconstructed.amount, 850.0);
      expect(reconstructed.integerAmount, 850);
      expect(reconstructed.type, TransactionType.expense);
      expect(reconstructed.category, 'Food & Dining');
      expect(reconstructed.date.millisecondsSinceEpoch, now.millisecondsSinceEpoch);

      // Verify transfer transaction
      final transferItem = TransactionItem(
        id: 'tx_transfer_1',
        title: 'Sent to savings',
        note: 'Monthly savings transfer',
        amount: 5000,
        type: TransactionType.transfer,
        date: now,
        category: 'General',
      );
      final transferMap = transferItem.toMap();
      expect(transferMap['type'], 'transfer');
      expect(transferMap['category'], 'Transfer');
      expect(transferMap['amount'], 5000);
      expect(transferMap['amount'], isA<int>());
      expect(transferMap['note'], 'Monthly savings transfer');
    });

    test('FirestoreService saves, streams, and deletes transactions in fallback mode', () async {
      final service = FirestoreService();
      final item1 = TransactionItem(
        id: '1',
        title: 'Salary',
        amount: 50000.0,
        type: TransactionType.income,
        date: DateTime.now(),
        category: 'Salary',
      );
      final item2 = TransactionItem(
        id: '2',
        title: 'Rent',
        amount: 15000.0,
        type: TransactionType.expense,
        date: DateTime.now(),
        category: 'Bills & Utilities',
      );

      final streamFuture = service.streamTransactions('test_user').first;
      await service.saveTransaction('test_user', item1);
      final emitted = await streamFuture;
      expect(emitted.length, 1);
      expect(emitted.first.title, 'Salary');

      await service.saveTransaction('test_user', item2);
      await service.deleteTransaction('test_user', '1');
      await service.clearAllTransactions('test_user');
      service.dispose();
    });

    test('AuthController manages login, register, and guest states gracefully', () async {
      final auth = AuthController();
      expect(auth.isLoggedIn, false);

      // Test guest mode
      await auth.continueAsGuest();
      expect(auth.isGuest, true);
      expect(auth.userId, isNotEmpty);

      // Test registration
      final regError = await auth.register(
        name: 'Jane Doe',
        email: 'jane@example.com',
        password: 'password123',
      );
      expect(regError, isNull);
      expect(auth.isLoggedIn, true);
      expect(auth.userName, 'Jane Doe');
      expect(auth.userEmail, 'jane@example.com');

      // Test logout
      await auth.logout();
      expect(auth.isLoggedIn, false);
      expect(auth.userEmail, isNull);

      // Test login
      final loginError = await auth.login(
        email: 'jane@example.com',
        password: 'password123',
      );
      expect(loginError, isNull);
      expect(auth.isLoggedIn, true);
      expect(auth.userEmail, 'jane@example.com');
    });

    test('FirestoreService saves and retrieves user registration details with exact fields', () async {
      final service = FirestoreService();
      await service.saveUserData(
        userId: 'uid_test_123',
        username: 'Alex Morgan',
        emailId: 'alex@example.com',
      );

      final userData = await service.getUserData('uid_test_123');
      expect(userData, isNotNull);
      expect(userData!['username'], 'Alex Morgan');
      expect(userData['user_Id'], 'uid_test_123');
      expect(userData['email_Id'], 'alex@example.com');
    });

    test('AuthController saves user details to users collection on register and google sign-in', () async {
      final firestoreService = FirestoreService();
      final auth = AuthController(firestoreService: firestoreService);

      // Register with email and password
      final regError = await auth.register(
        name: 'Sarah Connor',
        email: 'sarah@example.com',
        password: 'password123',
      );
      expect(regError, isNull);

      final regUserData = await firestoreService.getUserData(auth.userId);
      expect(regUserData, isNotNull);
      expect(regUserData!['username'], 'Sarah Connor');
      expect(regUserData['user_Id'], auth.userId);
      expect(regUserData['email_Id'], 'sarah@example.com');

      // Logout and test Google Sign-In
      await auth.logout();
      expect(auth.isLoggedIn, false);

      final googleError = await auth.signInWithGoogle();
      expect(googleError, isNull);
      expect(auth.isLoggedIn, true);

      final googleUserData = await firestoreService.getUserData(auth.userId);
      expect(googleUserData, isNotNull);
      expect(googleUserData!['username'], 'Google User');
      expect(googleUserData['user_Id'], auth.userId);
      expect(googleUserData['email_Id'], 'user@gmail.com');
    });

    test('CategoryItem serializes fields correctly and includes all predefined categories', () {
      final predefined = CategoryItem.predefinedCategories;
      expect(predefined.length, 15);

      final expenses =
          predefined.where((c) => c.subcategory == 'expense').toList();
      final incomes =
          predefined.where((c) => c.subcategory == 'income').toList();
      expect(expenses.length, 10);
      expect(incomes.length, 5);

      expect(expenses.map((c) => c.name), containsAll([
        'Food & Dining',
        'Groceries',
        'Transportation',
        'Shopping',
        'Bills & Utilities',
        'Entertainment',
        'Healthcare',
        'Education',
        'Travel',
        'Other Expense',
      ]));

      expect(incomes.map((c) => c.name), containsAll([
        'Salary',
        'Freelance & Business',
        'Investments',
        'Gifts & Allowance',
        'Other Income',
      ]));

      final item = CategoryItem(
        id: 'cat_custom_1',
        name: 'Photography',
        subcategory: 'expense',
        icon: 'camera_alt_outlined',
        colour: '#FFF2E8',
        userId: 'user_xyz',
      );
      final map = item.toMap();
      expect(map['category/expense_name'], 'Photography');
      expect(map['subcategory'], 'expense');
      expect(map['icon'], 'camera_alt_outlined');
      expect(map['colour'], '#FFF2E8');
      expect(map['user_Id'], 'user_xyz');

      final reconstructed = CategoryItem.fromMap('cat_custom_1', map);
      expect(reconstructed.name, 'Photography');
      expect(reconstructed.subcategory, 'expense');
      expect(reconstructed.userId, 'user_xyz');
    });

    test('FirestoreService manages predefined categories and user-specific custom categories', () async {
      final service = FirestoreService();

      // User A streams categories
      final userAStream = await service.streamCategories('user_A').first;
      expect(userAStream.length, 15); // Starts with 15 predefined

      // User A creates a custom category
      final customCatA = CategoryItem(
        id: 'cat_custom_A',
        name: 'Pet Care',
        subcategory: 'expense',
        icon: 'pets_outlined',
        colour: '#FFF0F6',
        userId: 'user_A',
      );
      await service.saveCategory(customCatA);

      // User A sees their custom category
      final userAUpdated = await service.streamCategories('user_A').first;
      expect(userAUpdated.any((c) => c.name == 'Pet Care'), true);

      // User B streams categories: should NOT see User A's custom category
      final userBStream = await service.streamCategories('user_B').first;
      expect(userBStream.any((c) => c.name == 'Pet Care'), false);

      // User A deletes custom category
      await service.deleteCategory('cat_custom_A', 'expense');
      final userAAfterDelete = await service.streamCategories('user_A').first;
      expect(userAAfterDelete.any((c) => c.name == 'Pet Care'), false);

      service.dispose();
    });

    test('BudgetItem serializes fields correctly (category/expense_name, monthly_limit as integer)', () {
      final budget = BudgetItem(
        id: 'budget_user1_groceries',
        categoryName: 'Groceries',
        monthlyLimit: 7500,
        userId: 'user_1',
      );

      final map = budget.toMap();
      expect(map['category/expense_name'], 'Groceries');
      expect(map['monthly_limit'], 7500);
      expect(map['monthly_limit'], isA<int>());
      expect(map['user_Id'], 'user_1');

      final reconstructed = BudgetItem.fromMap('budget_user1_groceries', map);
      expect(reconstructed.id, 'budget_user1_groceries');
      expect(reconstructed.categoryName, 'Groceries');
      expect(reconstructed.category, 'Groceries');
      expect(reconstructed.monthlyLimit, 7500);
      expect(reconstructed.limit, 7500.0);
      expect(reconstructed.userId, 'user_1');

      // Test numeric coercion from double/num
      final mapWithDouble = {
        'category/expense_name': 'Dining',
        'monthly_limit': 4500.80,
        'user_Id': 'user_2',
      };
      final reconstructedDouble = BudgetItem.fromMap('b_2', mapWithDouble);
      expect(reconstructedDouble.monthlyLimit, 4501);
      expect(reconstructedDouble.monthlyLimit, isA<int>());
    });

    test('FirestoreService saves, streams, and deletes budgets for users', () async {
      final service = FirestoreService();

      final budgetA = BudgetItem(
        id: 'budget_userA_food',
        categoryName: 'Food & Dining',
        monthlyLimit: 12000,
        userId: 'user_A',
      );

      final budgetB = BudgetItem(
        id: 'budget_userB_food',
        categoryName: 'Food & Dining',
        monthlyLimit: 6000,
        userId: 'user_B',
      );

      await service.saveBudget(budgetA);
      await service.saveBudget(budgetB);

      // User A should only see their own budget
      final userABudgets = await service.streamBudgets('user_A').first;
      expect(userABudgets.length, 1);
      expect(userABudgets.first.categoryName, 'Food & Dining');
      expect(userABudgets.first.monthlyLimit, 12000);

      // User B should only see their own budget
      final userBBudgets = await service.streamBudgets('user_B').first;
      expect(userBBudgets.length, 1);
      expect(userBBudgets.first.monthlyLimit, 6000);

      // User A deletes their budget
      await service.deleteBudget(budgetA.id, userId: 'user_A');
      final userAAfterDelete = await service.streamBudgets('user_A').first;
      expect(userAAfterDelete.isEmpty, true);

      // User B's budget should remain intact
      final userBAfterDelete = await service.streamBudgets('user_B').first;
      expect(userBAfterDelete.length, 1);

      service.dispose();
    });

    test('Income, Expense, and Transfer transactions serialize and stream with integer amounts and proper date/time', () async {
      final service = FirestoreService();
      final now = DateTime(2026, 11, 27, 10, 15, 30);

      // Income transaction
      final income = TransactionItem(
        id: 'tx_income_1',
        title: 'Freelance Design',
        note: 'Mobile app UI work',
        amount: 25000,
        type: TransactionType.income,
        date: now,
        category: 'Freelance & Business',
        userId: 'user_A',
      );
      final incomeMap = income.toMap();
      expect(incomeMap['amount'], 25000);
      expect(incomeMap['amount'], isA<int>());
      expect(incomeMap['note'], 'Mobile app UI work');
      expect(incomeMap['category'], 'Freelance & Business');
      expect(incomeMap['type'], 'income');
      expect(incomeMap['date_time'], now.toIso8601String());

      // Expense transaction
      final expense = TransactionItem(
        id: 'tx_expense_1',
        title: 'Weekly Groceries',
        note: 'Supermarket shopping',
        amount: 3200,
        type: TransactionType.expense,
        date: now,
        category: 'Groceries',
        userId: 'user_A',
      );
      final expenseMap = expense.toMap();
      expect(expenseMap['amount'], 3200);
      expect(expenseMap['amount'], isA<int>());
      expect(expenseMap['note'], 'Supermarket shopping');
      expect(expenseMap['category'], 'Groceries');
      expect(expenseMap['type'], 'expense');

      // Transfer transaction
      final transfer = TransactionItem(
        id: 'tx_transfer_1',
        title: 'Bank Transfer',
        note: 'Transfer to emergency fund',
        amount: 10000,
        type: TransactionType.transfer,
        date: now,
        category: '',
        userId: 'user_A',
      );
      final transferMap = transfer.toMap();
      expect(transferMap['amount'], 10000);
      expect(transferMap['amount'], isA<int>());
      expect(transferMap['note'], 'Transfer to emergency fund');
      expect(transferMap['category'], 'Transfer');
      expect(transferMap['type'], 'transfer');

      await service.saveTransaction('user_A', income);
      await service.saveTransaction('user_A', expense);
      await service.saveTransaction('user_A', transfer);

      final transactions = await service.streamTransactions('user_A').first;
      expect(transactions.length, 3);
      service.dispose();
    });
  });
}
