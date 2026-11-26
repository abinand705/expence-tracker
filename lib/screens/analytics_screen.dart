import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_item.dart';

class AnalyticsScreen extends StatefulWidget {
  final List<TransactionItem> transactions;
  final VoidCallback? onOpenDrawer;

  const AnalyticsScreen({
    super.key,
    required this.transactions,
    this.onOpenDrawer,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'This Month';
  final List<String> _periods = ['This Month', 'Last Month', '30 Days', 'This Year'];

  List<TransactionItem> get _filteredExpenses {
    final now = DateTime.now();
    return widget.transactions.where((item) {
      if (item.type != TransactionType.expense) return false;

      if (_selectedPeriod == 'This Month') {
        return item.date.year == now.year && item.date.month == now.month;
      } else if (_selectedPeriod == 'Last Month') {
        final lastMonth = DateTime(now.year, now.month - 1);
        return item.date.year == lastMonth.year && item.date.month == lastMonth.month;
      } else if (_selectedPeriod == '30 Days') {
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        return item.date.isAfter(thirtyDaysAgo);
      } else if (_selectedPeriod == 'This Year') {
        return item.date.year == now.year;
      }
      return true;
    }).toList();
  }

  Map<String, double> get _categoryTotals {
    final map = <String, double>{};
    for (var item in _filteredExpenses) {
      map[item.category] = (map[item.category] ?? 0.0) + item.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final expenses = _filteredExpenses;
    final categoryTotals = _categoryTotals;
    final totalSpent = expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
    final currencyFormat = NumberFormat('#,##0.00', 'en_IN');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardColor = Theme.of(context).cardColor;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFEDF2F7);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: textColor, size: 24),
                    onPressed: widget.onOpenDrawer,
                    tooltip: 'Open menu',
                  ),
                  Text(
                    'Analyse & Visualise',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Period Selector Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: _periods.map((period) {
                    final isSelected = _selectedPeriod == period;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPeriod = period),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF165945) : const Color(0xFF0A3026))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              period,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: expenses.isEmpty
                  ? _buildEmptyState(isDark, textColor)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Total Spent Summary Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL SPENT',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹ ${currencyFormat.format(totalSpent)}',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Across ${expenses.length} transaction${expenses.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'CATEGORY BREAKDOWN',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 12),

                          ...categoryTotals.entries.map((entry) {
                            final percent = totalSpent > 0
                                ? (entry.value / totalSpent)
                                : 0.0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        '₹ ${currencyFormat.format(entry.value)} (${(percent * 100).toStringAsFixed(1)}%)',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 7,
                                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular Quadrant / Pie Chart Icon
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 64,
              color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
            ),
            const SizedBox(height: 18),
            Text(
              'No spending data for this period',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log your daily expenses to see charts, breakdowns &\ntrends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
