import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class BudgetProgressCard extends StatelessWidget {
  final double target;
  final double currentSpend;
  final NumberFormat formatter;
  final bool isWithinTarget;
  final VoidCallback onDoubleTap;

  const BudgetProgressCard({
    super.key,
    required this.target,
    required this.currentSpend,
    required this.formatter,
    required this.isWithinTarget,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final double targetRemaining = target - currentSpend;
    
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isWithinTarget ? AppColors.primary : AppColors.errorRed,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isWithinTarget ? 'Target Remaining' : 'Over Target',
              style: AppTypography.bodyMd.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatter.format(targetRemaining.abs()),
              style: AppTypography.headlineMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(isWithinTarget ? Icons.check_circle_outline : Icons.warning_amber_rounded, 
                  color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  isWithinTarget ? 'On track' : 'Exceeded',
                  style: AppTypography.labelMuted.copyWith(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
