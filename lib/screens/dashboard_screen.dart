import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/transaction_card.dart';
import '../widgets/app_drawer.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/user_repository.dart';
import '../services/analytics_service.dart';
import '../services/recurring_expense_service.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../widgets/dashboard/balance_card.dart';
import '../widgets/dashboard/monthly_spending_card.dart';
import '../widgets/dashboard/budget_progress_card.dart';
import '../widgets/dashboard/spending_trend_card.dart';
import '../widgets/dashboard/spend_categories_card.dart';
import 'budget_settings_screen.dart';
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAllClicked;

  const DashboardScreen({
    super.key,
    this.onSeeAllClicked,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TransactionRepository _transactionRepo = TransactionRepository();
  final AccountRepository _accountRepo = AccountRepository();
  final BudgetRepository _budgetRepo = BudgetRepository();
  final UserRepository _userRepo = UserRepository();
  final AnalyticsService _analyticsService = AnalyticsService();

  bool _isLoading = true;
  String _userName = 'User';
  List<Transaction> _transactions = [];
  Budget? _monthlyBudget;
  StreamSubscription<List<Transaction>>? _transactionSubscription;
  StreamSubscription<List<Account>>? _accountSubscription;
  StreamSubscription<List<Budget>>? _budgetSubscription;
  
  // Cached analytics
  double _totalBalance = 0.0;
  double _currentMonthSpend = 0.0;
  double _currentMonthCredited = 0.0;
  double _spendChange = 0.0;
  List<Transaction> _recentTransactions = [];

  static bool _hasProcessedRecurring = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _transactionSubscription = _transactionRepo.watchTransactions().listen(
      (transactions) {
        if (mounted) {
          final now = DateTime.now();
          final lastMonth = now.month == 1 ? 12 : now.month - 1;
          final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
          
          final currentSpend = _analyticsService.calculateTotalExpenses(transactions, month: now.month, year: now.year);
          final currentCredited = _analyticsService.calculateTotalIncome(transactions, month: now.month, year: now.year);
          final lastSpend = _analyticsService.calculateTotalExpenses(transactions, month: lastMonth, year: lastMonthYear);
          final change = lastSpend == 0 ? 0.0 : ((currentSpend - lastSpend) / lastSpend) * 100;
          
          setState(() {
            _transactions = transactions;
            _currentMonthSpend = currentSpend;
            _currentMonthCredited = currentCredited;
            _spendChange = change;
            _recentTransactions = transactions.take(3).toList();
          });
        }
      },
      onError: (e) {}
    );
    _accountSubscription = _accountRepo.watchAccounts().listen(
      (accounts) {
        if (mounted) {
          setState(() {
            _totalBalance = accounts.fold(0.0, (sum, acc) => sum + acc.currentBalance);
          });
        }
      },
      onError: (e) {}
    );
    _budgetSubscription = _budgetRepo.watchBudgets().listen(
      (budgets) {
        if (mounted) {
          setState(() {
            try {
              _monthlyBudget = budgets.firstWhere((b) => b.category == 'Total');
            } catch (e) {
              _monthlyBudget = null; // No total budget found
            }
          });
        }
      },
      onError: (e) {}
    );
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _accountSubscription?.cancel();
    _budgetSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    if (!_hasProcessedRecurring) {
      _hasProcessedRecurring = true;
      try {
        await RecurringExpenseService().processDueExpenses();
      } catch (e) {
        // Continue if it fails, don't crash dashboard
      }
    }

    try {
      final userName = await _userRepo.getUserName();
      if (mounted) {
        setState(() {
          _userName = userName ?? 'User';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const SizedBox.shrink(),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        drawer: const AppDrawer(),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final currencyFormatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
    
    final now = DateTime.now();
    final hour = now.hour;
    String greeting = 'Good evening, $_userName';
    if (hour < 12) {
      greeting = 'Good morning, $_userName';
    } else if (hour < 17) {
      greeting = 'Good afternoon, $_userName';
    }
    
    final monthlyTarget = _monthlyBudget?.amount ?? 0.0;
    final isWithinTarget = monthlyTarget == 0.0 ? true : _currentMonthSpend <= monthlyTarget;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const SizedBox.shrink(),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: AppTypography.headlineMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    BalanceCard(totalBalance: _totalBalance, formatter: currencyFormatter),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      elevation: 0,
                      color: AppColors.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This Month',
                              style: AppTypography.labelCaps.copyWith(color: AppColors.outline),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Credited',
                                  style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  currencyFormatter.format(_currentMonthCredited),
                                  style: AppTypography.headlineMd.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: MonthlySpendingCard(
                            currentSpend: _currentMonthSpend,
                            spendChange: _spendChange,
                            formatter: currencyFormatter,
                            isWithinTarget: isWithinTarget,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: BudgetProgressCard(
                            target: monthlyTarget,
                            currentSpend: _currentMonthSpend,
                            formatter: currencyFormatter,
                            isWithinTarget: isWithinTarget,
                            onDoubleTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetSettingsScreen())),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SpendingTrendCard(transactions: _transactions, analyticsService: _analyticsService),
                    const SizedBox(height: AppSpacing.md),
                    SpendCategoriesCard(transactions: _transactions, analyticsService: _analyticsService),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: AppTypography.headlineMd.copyWith(
                            color: AppColors.primaryContainer,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onSeeAllClicked,
                          child: Text(
                            'SEE ALL',
                            style: AppTypography.labelCaps.copyWith(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
              sliver: _recentTransactions.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text("No recent transactions")),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return TransactionCard(transaction: _recentTransactions[index]);
                      },
                      childCount: _recentTransactions.length,
                    ),
                  ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}
