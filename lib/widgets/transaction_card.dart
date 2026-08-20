import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'category_icon.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final bool isIncome = transaction.type == TransactionType.income;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (transaction.rawMessage != null) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Message Details', style: AppTypography.headlineMd),
              content: Text(
                transaction.rawMessage!,
                style: AppTypography.bodyMd,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close', style: AppTypography.labelCaps.copyWith(color: cs.primaryContainer)),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.level1,
        ),
        child: Row(
          children: [
            CategoryIcon(category: transaction.category),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.merchant,
                    style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('MMM dd, hh:mm a').format(transaction.date)} • ${transaction.subtitle ?? transaction.category}',
                    style: AppTypography.labelMuted.copyWith(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${isIncome ? '+' : '-'}₹ ${NumberFormat('#,##0').format(transaction.amount)}',
              style: AppTypography.headlineMd.copyWith(
                color: isIncome ? AppColors.successGreen : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
