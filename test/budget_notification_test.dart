import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/repositories/budget_repository.dart';
import 'package:expense_tracker/models/budget.dart';
import 'package:expense_tracker/services/settings_service.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:expense_tracker/widgets/settings/notification_setting_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgetRepository Default Budget Tests', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late BudgetRepository repository;
    const uid = 'test_user_budget_123';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      final mockUser = MockUser(uid: uid);
      auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      repository = BudgetRepository();
      repository.setInstancesForTesting(firestore, auth);
    });

    test('ensureDefaultBudget automatically creates 10,000 Total budget if none exists', () async {
      final initialBudgets = await repository.getBudgets();
      expect(initialBudgets, isEmpty);

      final defaultBudget = await repository.ensureDefaultBudget();
      expect(defaultBudget, isNotNull);
      expect(defaultBudget!.category, 'Total');
      expect(defaultBudget.amount, 10000.0);
      expect(defaultBudget.period, 'monthly');

      final storedBudgets = await repository.getBudgets();
      expect(storedBudgets.length, 1);
      expect(storedBudgets.first.category, 'Total');
      expect(storedBudgets.first.amount, 10000.0);
    });

    test('ensureDefaultBudget does not overwrite existing Total budget', () async {
      final now = DateTime.now();
      await repository.addBudget(Budget(
        id: '',
        category: 'Total',
        amount: 25000.0,
        period: 'monthly',
        createdAt: now,
        updatedAt: now,
      ));

      final existingBudget = await repository.ensureDefaultBudget();
      expect(existingBudget, isNotNull);
      expect(existingBudget!.amount, 25000.0);

      final storedBudgets = await repository.getBudgets();
      expect(storedBudgets.length, 1);
      expect(storedBudgets.first.amount, 25000.0);
    });
  });

  group('SettingsService Notification Settings Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getNotificationsEnabled defaults to true', () async {
      final settings = SettingsService();
      final enabled = await settings.getNotificationsEnabled();
      expect(enabled, isTrue);
    });

    test('setNotificationsEnabled toggles and persists preference', () async {
      final settings = SettingsService();
      await settings.setNotificationsEnabled(false);
      expect(await settings.getNotificationsEnabled(), isFalse);

      await settings.setNotificationsEnabled(true);
      expect(await settings.getNotificationsEnabled(), isTrue);
    });

    test('Last budget alert period tracking persists and clears correctly', () async {
      final settings = SettingsService();
      expect(await settings.getLastBudgetAlertPeriod(), isNull);

      await settings.setLastBudgetAlertPeriod('2026-09');
      expect(await settings.getLastBudgetAlertPeriod(), '2026-09');

      await settings.clearLastBudgetAlertPeriod();
      expect(await settings.getLastBudgetAlertPeriod(), isNull);
    });
  });

  group('NotificationService Budget Logic Tests', () {
    late NotificationService notificationService;
    late SettingsService settingsService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      notificationService = NotificationService();
      settingsService = SettingsService();
    });

    test('checkAndNotifyBudget returns false when spend is below budget limit', () async {
      final notified = await notificationService.checkAndNotifyBudget(
        currentSpend: 5000.0,
        budgetLimit: 10000.0,
        periodKey: '2026-09',
      );
      expect(notified, isFalse);
      expect(await settingsService.getLastBudgetAlertPeriod(), isNull);
    });

    test('checkAndNotifyBudget triggers alert when spend hits or exceeds budget limit', () async {
      final notified = await notificationService.checkAndNotifyBudget(
        currentSpend: 10500.0,
        budgetLimit: 10000.0,
        periodKey: '2026-09',
      );
      expect(notified, isTrue);
      expect(await settingsService.getLastBudgetAlertPeriod(), '2026-09');
    });

    test('checkAndNotifyBudget does not re-notify if already alerted for same period', () async {
      await notificationService.checkAndNotifyBudget(
        currentSpend: 10000.0,
        budgetLimit: 10000.0,
        periodKey: '2026-09',
      );

      // Second check with higher spend in same period
      final notifiedAgain = await notificationService.checkAndNotifyBudget(
        currentSpend: 12000.0,
        budgetLimit: 10000.0,
        periodKey: '2026-09',
      );
      expect(notifiedAgain, isFalse);
    });

    test('checkAndNotifyBudget suppresses alert if notifications are disabled in settings', () async {
      await settingsService.setNotificationsEnabled(false);

      final notified = await notificationService.checkAndNotifyBudget(
        currentSpend: 15000.0,
        budgetLimit: 10000.0,
        periodKey: '2026-09',
      );
      expect(notified, isFalse);
      expect(await settingsService.getLastBudgetAlertPeriod(), isNull);
    });

    test('checkAndNotifyBudget clears period alert state if spend falls back below budget', () async {
      await settingsService.setLastBudgetAlertPeriod('2026-09');
      expect(await settingsService.getLastBudgetAlertPeriod(), '2026-09');

      await notificationService.checkAndNotifyBudget(
        currentSpend: 8000.0,
        budgetLimit: 10000.0,
        periodKey: '2026-09',
      );
      expect(await settingsService.getLastBudgetAlertPeriod(), isNull);
    });
  });

  group('NotificationSettingTile UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('NotificationSettingTile displays interactive toggle and persists changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationSettingTile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Budget limit alerts enabled'), findsOneWidget);

      // Find the Switch widget for notifications
      final notifSwitchFinder = find.byType(Switch);
      expect(notifSwitchFinder, findsOneWidget);

      final notifSwitch = tester.widget<Switch>(notifSwitchFinder);
      expect(notifSwitch.value, isTrue);

      // Tap to toggle switch OFF
      await tester.tap(notifSwitchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Notifications disabled'), findsOneWidget);
      final updatedSwitch = tester.widget<Switch>(notifSwitchFinder);
      expect(updatedSwitch.value, isFalse);

      final settingsService = SettingsService();
      expect(await settingsService.getNotificationsEnabled(), isFalse);
    });
  });
}
