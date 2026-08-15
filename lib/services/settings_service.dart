import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _monthlyTargetKey = 'monthly_target';

  Future<double> getMonthlyTargetAmount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_monthlyTargetKey) ?? 20000.0; // Default target
  }

  Future<void> setMonthlyTargetAmount(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_monthlyTargetKey, amount);
  }
}
