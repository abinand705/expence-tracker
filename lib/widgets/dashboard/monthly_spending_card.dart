import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class MonthlySpendingCard extends StatelessWidget {
  final double currentSpend;
  final double spendChange;
  final NumberFormat formatter;
  final bool isWithinTarget;

  const MonthlySpendingCard({
    super.key,
    required this.currentSpend,
    required this.spendChange,
    required this.formatter,
    required this.isWithinTarget,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSpendUp = spendChange > 0;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Spend',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatter.format(currentSpend),
            style: AppTypography.headlineMd.copyWith(
              color: isWithinTarget ? cs.onSurface : AppColors.errorRed,
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(isSpendUp ? Icons.trending_up : Icons.trending_down,
                color: isSpendUp ? AppColors.errorRed : AppColors.successGreen, size: 14),
              const SizedBox(width: 4),
              Text(
                '${spendChange.abs().toStringAsFixed(1)}% vs last month',
                style: AppTypography.labelMuted.copyWith(
                  color: isSpendUp ? AppColors.errorRed : AppColors.successGreen,
                  fontSize: 10
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

