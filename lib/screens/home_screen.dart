import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_item.dart';
import '../widgets/cash_flow_card.dart';
import '../widgets/total_balance_card.dart';

class HomeScreen extends StatefulWidget {
  final List<TransactionItem> transactions;
  final Function(TransactionType) onAddTransaction;
  final VoidCallback onSeeAll;
  final Function(String id)? onDeleteTransaction;
  final VoidCallback? onOpenDrawer;

  const HomeScreen({
    super.key,
    required this.transactions,
    required this.onAddTransaction,
    required this.onSeeAll,
    this.onDeleteTransaction,
    this.onOpenDrawer,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedPeriod = 'This Month';

  double get _totalBalance {
    double balance = 0.0;
    for (var t in widget.transactions) {
      if (t.type == TransactionType.income) {
        balance += t.amount;
      } else if (t.type == TransactionType.expense) {
        balance -= t.amount;
      }
    }
    return balance;
  }

  double get _totalCredited {
    double credited = 0.0;
    for (var t in widget.transactions) {
      if (t.type == TransactionType.income) {
        credited += t.amount;
      }
    }
    return credited;
  }

  double get _totalSpent {
    double spent = 0.0;
    for (var t in widget.transactions) {
      if (t.type == TransactionType.expense) {
        spent += t.amount;
      }
    }
    return spent;
  }

  void _selectPeriod() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final checkColor = isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('This Month', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
              trailing: _selectedPeriod == 'This Month'
                  ? Icon(Icons.check, color: checkColor)
                  : null,
              onTap: () {
                setState(() => _selectedPeriod = 'This Month');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text('Last Month', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
              trailing: _selectedPeriod == 'Last Month'
                  ? Icon(Icons.check, color: checkColor)
                  : null,
              onTap: () {
                setState(() => _selectedPeriod = 'Last Month');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text('All Time', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
              trailing: _selectedPeriod == 'All Time'
                  ? Icon(Icons.check, color: checkColor)
                  : null,
              onTap: () {
                setState(() => _selectedPeriod = 'All Time');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  void _confirmDeleteTransaction(BuildContext context, TransactionItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Transaction?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${item.title}" (₹ ${item.amount.toStringAsFixed(2)})?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteTransaction?.call(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${item.title}"'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: 120, // space for bottom bar & FAB
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar (Title & Offline Pill)
            _buildTopHeader(isDark, textColor),
            const SizedBox(height: 22),

            // Greeting
            Text(
              _greeting,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 18),

            // Total Balance Card
            TotalBalanceCard(balance: _totalBalance),
            const SizedBox(height: 16),

            // Cash Flow Card
            CashFlowCard(
              creditedAmount: _totalCredited,
              spentAmount: _totalSpent,
              period: _selectedPeriod,
              onPeriodTap: _selectPeriod,
            ),
            const SizedBox(height: 24),

            // Recent Transactions Header
            _buildRecentTransactionsHeader(isDark, textColor),
            const SizedBox(height: 16),

            // Empty or Populated Transactions List
            if (widget.transactions.isEmpty)
              _buildEmptyState(isDark, textColor)
            else
              _buildTransactionList(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.menu, color: textColor, size: 24),
          onPressed: widget.onOpenDrawer,
          tooltip: 'Open menu',
        ),
        Text(
          'MoneyTrack',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 48), // Balances the menu button
      ],
    );
  }

  Widget _buildRecentTransactionsHeader(bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'RECENT TRANSACTIONS',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        InkWell(
          onTap: widget.onSeeAll,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right,
                  color: textColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: isDark ? const Color(0xFF475569) : Colors.grey.shade400,
          ),
          const SizedBox(height: 18),
          Text(
            'No recent transactions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the "+" button below to manually log your expenses &\nincome.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(bool isDark, Color textColor) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_IN');
    final dateFormat = DateFormat('MMM d, h:mm a');

    // Show up to top 5 recent transactions
    final recent = widget.transactions.take(5).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recent.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = recent[index];
        final isIncome = item.type == TransactionType.income;
        final isTransfer = item.type == TransactionType.transfer;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isIncome
                      ? (isDark ? const Color(0xFF14532D) : const Color(0xFFE8F7ED))
                      : isTransfer
                          ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                          : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFDE8E8)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome
                      ? Icons.arrow_downward_rounded
                      : isTransfer
                          ? Icons.swap_horiz_rounded
                          : Icons.arrow_upward_rounded,
                  color: isIncome
                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                      : isTransfer
                          ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                          : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(item.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : isTransfer ? '' : '-'} ₹ ${currencyFormat.format(item.amount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isIncome
                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                      : isTransfer
                          ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                          : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                ),
              ),
              if (widget.onDeleteTransaction != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () => _confirmDeleteTransaction(context, item),
                ),
            ],
          ),
        );
      },
    );
  }
}
