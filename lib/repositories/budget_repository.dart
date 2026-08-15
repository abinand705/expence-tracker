import '../models/budget.dart';
import '../services/settings_service.dart';

class BudgetRepository {
  final SettingsService _settingsService = SettingsService();

  Future<Budget?> getMonthlyBudget() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final amount = await _settingsService.getMonthlyTargetAmount();
    return Budget(
      id: 'monthly_budget_1',
      category: 'Total',
      amount: amount,
      period: 'monthly',
      updatedAt: DateTime.now(),
    );
  }

  Future<void> setMonthlyBudget(double amount) async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _settingsService.setMonthlyTargetAmount(amount);
  }
}
