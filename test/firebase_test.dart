import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/controllers/auth_controller.dart';
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
  });
}
