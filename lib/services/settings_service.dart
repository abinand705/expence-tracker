import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _monthlyTargetKey = 'monthly_target';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _lastBudgetAlertPeriodKey = 'last_budget_alert_period';

  Future<double> getMonthlyTargetAmount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_monthlyTargetKey) ?? 10000.0; // Default target 10k
  }

  Future<void> setMonthlyTargetAmount(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_monthlyTargetKey, amount);
    notifyListeners();
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    notifyListeners();
  }

  Future<String?> getLastBudgetAlertPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBudgetAlertPeriodKey);
  }

  Future<void> setLastBudgetAlertPeriod(String period) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBudgetAlertPeriodKey, period);
  }

  Future<void> clearLastBudgetAlertPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastBudgetAlertPeriodKey);
  }
}

