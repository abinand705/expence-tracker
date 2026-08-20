import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class BalanceCard extends StatelessWidget {
  final double totalBalance;
  final NumberFormat formatter;

  const BalanceCard({
    super.key,
    required this.totalBalance,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL BALANCE',
                style: AppTypography.labelCaps.copyWith(color: cs.onSurfaceVariant),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance_wallet_outlined, size: 20, color: cs.primaryContainer),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatter.format(totalBalance),
            style: AppTypography.displayCurrency.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}
