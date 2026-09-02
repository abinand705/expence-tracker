import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final SettingsService _settingsService = SettingsService();
  bool _isInitialized = false;

  @visibleForTesting
  FlutterLocalNotificationsPlugin get pluginForTesting => _notificationsPlugin;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    return true;
  }

  Future<void> showNotification({
    int id = 1001,
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications when spending hits or exceeds your budget limit',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Checks if current spending has reached or exceeded overall budget limit.
  /// If so, and notifications are enabled, triggers a notification alert to the phone.
  Future<bool> checkAndNotifyBudget({
    required double currentSpend,
    required double budgetLimit,
    String? periodKey,
  }) async {
    if (budgetLimit <= 0) return false;

    final notificationsEnabled = await _settingsService.getNotificationsEnabled();
    if (!notificationsEnabled) return false;

    final now = DateTime.now();
    final currentPeriod = periodKey ?? '${now.year}-${now.month.toString().padLeft(2, '0')}';

    if (currentSpend >= budgetLimit) {
      final lastAlertedPeriod = await _settingsService.getLastBudgetAlertPeriod();
      if (lastAlertedPeriod == currentPeriod) {
        // Already alerted for this period
        return false;
      }

      final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
      final formattedSpend = currencyFormatter.format(currentSpend);
      final formattedBudget = currencyFormatter.format(budgetLimit);

      final title = currentSpend == budgetLimit
          ? '⚠️ Budget Limit Reached!'
          : '⚠️ Budget Limit Exceeded!';

      final body = 'You have spent $formattedSpend of your $formattedBudget budget limit.';

      await showNotification(
        id: 2001,
        title: title,
        body: body,
      );

      await _settingsService.setLastBudgetAlertPeriod(currentPeriod);
      return true;
    } else {
      // If spend is below budget (e.g. after transaction deletion), reset alert for period
      final lastAlertedPeriod = await _settingsService.getLastBudgetAlertPeriod();
      if (lastAlertedPeriod == currentPeriod) {
        await _settingsService.clearLastBudgetAlertPeriod();
      }
      return false;
    }
  }
}
