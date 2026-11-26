import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TotalBalanceCard extends StatelessWidget {
  final double balance;

  const TotalBalanceCard({
    super.key,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat('#,##0.00', 'en_IN');
    final formattedAmount = currencyFormat.format(balance);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEDF2F7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '₹ $formattedAmount',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
