import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_group.dart';
import '../repositories/transaction_group_repository.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class DuplicateReviewScreen extends StatefulWidget {
  const DuplicateReviewScreen({super.key});

  @override
  State<DuplicateReviewScreen> createState() => _DuplicateReviewScreenState();
}

class _DuplicateReviewScreenState extends State<DuplicateReviewScreen> {
  final TransactionGroupRepository _groupRepo = TransactionGroupRepository();
  final TransactionRepository _txRepo = TransactionRepository();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Needs Review', style: AppTypography.headlineMd),
        elevation: 0,
      ),
      body: StreamBuilder<List<TransactionGroup>>(
        stream: _groupRepo.watchPendingReviewGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: cs.primaryContainer));
          }

          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.containerMargin),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: cs.primaryContainer),
                    const SizedBox(height: AppSpacing.md),
                    Text('No duplicates to review', style: AppTypography.headlineMd),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'All transaction candidates have been classified and resolved.',
                      style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildReviewCard(context, group);
            },
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, TransactionGroup group) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('dd MMM, hh:mm a').format(group.transactionDate);
    final accountDisplay = group.bankName != null && group.bankName!.isNotEmpty
        ? '${group.bankName} ••••'
        : 'A/c ••••';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${group.canonicalAmount.toStringAsFixed(2)}',
                style: AppTypography.headlineMd.copyWith(
                  color: group.canonicalType.name == 'income'
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${group.candidateIds.length} related SMS',
                  style: AppTypography.labelMuted.copyWith(color: cs.primaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(group.canonicalMerchant, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            '$accountDisplay • $dateStr',
            style: AppTypography.labelMuted.copyWith(color: cs.onSurfaceVariant),
          ),
          if (group.aiReason != null && group.aiReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.base),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: cs.primaryContainer),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      group.aiReason!,
                      style: AppTypography.bodyMd.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _handleIgnore(group),
                child: Text('Ignore', style: AppTypography.bodyMd.copyWith(color: cs.outline)),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => _handleKeepSeparate(group),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                  side: BorderSide(color: cs.primaryContainer),
                ),
                child: Text('Keep Separate', style: AppTypography.bodyMd.copyWith(color: cs.primaryContainer)),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                onPressed: () => _handleMerge(group),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
                child: Text('Merge', style: AppTypography.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMerge(TransactionGroup group) async {
    try {
      // Mark group confirmed
      await _groupRepo.updateGroupStatus(group.groupId, TransactionGroupStatus.confirmed);
      // Remove excess duplicate transaction IDs, retaining canonical
      if (group.canonicalTransactionId != null) {
        for (final id in group.candidateIds) {
          if (id != group.canonicalTransactionId) {
            try {
              await _txRepo.deleteTransaction(id);
            } catch (_) {}
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions merged successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to merge: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _handleKeepSeparate(TransactionGroup group) async {
    try {
      await _groupRepo.updateGroupStatus(group.groupId, TransactionGroupStatus.confirmed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions kept separate')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _handleIgnore(TransactionGroup group) async {
    try {
      await _groupRepo.updateGroupStatus(group.groupId, TransactionGroupStatus.ignored);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction group ignored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}
