import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/controllers/auth_controller.dart';
import 'package:money_track/models/category_item.dart';
import 'package:money_track/models/transaction_item.dart';
import 'package:money_track/services/firestore_service.dart';

void main() {
  group('Firebase & Firestore Integration Unit Tests', () {
    test('TransactionItem converts toMap and fromMap correctly', () {
      final now = DateTime(2026, 11, 26, 14, 30);
      final item = TransactionItem(
        id: 'tx_123',
        title: 'Dinner at Bistro',
        amount: 850.50,
        type: TransactionType.expense,
        date: now,
        category: 'Food & Dining',
      );

      final map = item.toMap();
      expect(map['title'], 'Dinner at Bistro');
      expect(map['amount'], 850.50);
      expect(map['type'], 'expense');
      expect(map['date'], now.millisecondsSinceEpoch);
      expect(map['category'], 'Food & Dining');

      final reconstructed = TransactionItem.fromMap('tx_123', map);
      expect(reconstructed.id, 'tx_123');
      expect(reconstructed.title, 'Dinner at Bistro');
      expect(reconstructed.amount, 850.50);
      expect(reconstructed.type, TransactionType.expense);
      expect(reconstructed.category, 'Food & Dining');
      expect(reconstructed.date.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
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
  });
}
