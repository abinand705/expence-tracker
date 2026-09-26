import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/account_pattern_recommendation.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Bottom sheet dialog for reviewing newly discovered account recognition patterns.
///
/// Grouped by account, allowing the user to select which patterns to add to account rules.
class AccountPatternReviewSheet extends StatefulWidget {
  final List<AccountPatternRecommendation> recommendations;
  final List<Account> accounts;
  final Future<void> Function(List<AccountPatternRecommendation> approved)? onApprove;

  const AccountPatternReviewSheet({
    super.key,
    required this.recommendations,
    required this.accounts,
    this.onApprove,
  });

  @override
  State<AccountPatternReviewSheet> createState() => _AccountPatternReviewSheetState();
}

class _AccountPatternReviewSheetState extends State<AccountPatternReviewSheet> {
  late final Map<String, bool> _selectionMap;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-select confident recommendations attached to an account by default
    _selectionMap = {
      for (final r in widget.recommendations)
        if (r.accountId != null) r.recommendationId: true,
    };
  }

  bool get _allSelected {
    final accountRecs = widget.recommendations.where((r) => r.accountId != null);
    if (accountRecs.isEmpty) return false;
    return accountRecs.every((r) => _selectionMap[r.recommendationId] == true);
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      final select = value ?? false;
      for (final r in widget.recommendations) {
        if (r.accountId != null) {
          _selectionMap[r.recommendationId] = select;
        }
      }
    });
  }

  int get _selectedCount =>
      _selectionMap.values.where((selected) => selected).length;

  Future<void> _handleApprove() async {
    final approved = widget.recommendations
        .where((r) => _selectionMap[r.recommendationId] == true)
        .toList();

    if (approved.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      if (widget.onApprove != null) {
        await widget.onApprove!(approved);
      }
      if (mounted) {
        Navigator.of(context).pop(approved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding rules: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Filter and group recommendations by accountId
    final actionableRecs = widget.recommendations.where((r) => r.accountId != null).toList();
    final Map<String, List<AccountPatternRecommendation>> grouped = {};

    for (final rec in actionableRecs) {
      grouped.putIfAbsent(rec.accountId!, () => []).add(rec);
    }

    final accountMap = {for (final a in widget.accounts) a.id: a};

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'New Account Patterns Found',
                  style: AppTypography.headlineMd.copyWith(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${actionableRecs.length} found',
                  style: AppTypography.labelMuted.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Approve newly discovered patterns to improve automatic SMS transaction tracking.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),

          // Select All Checkbox Row
          if (grouped.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _allSelected,
                    onChanged: _isSaving ? null : _toggleSelectAll,
                    activeColor: cs.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Add recommended patterns',
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_selectedCount selected',
                    style: AppTypography.labelMuted.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Scrollable recommendations list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Grouped Account Recommendations
                for (final entry in grouped.entries) ...[
                  _buildAccountGroupCard(
                    context: context,
                    cs: cs,
                    account: accountMap[entry.key],
                    recommendations: entry.value,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Not Now'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_isSaving || _selectedCount == 0)
                      ? null
                      : _handleApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          _selectedCount > 0
                              ? 'Add to Rules ($_selectedCount)'
                              : 'Add to Rules',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountGroupCard({
    required BuildContext context,
    required ColorScheme cs,
    required Account? account,
    required List<AccountPatternRecommendation> recommendations,
  }) {
    final accountName = account != null
        ? '${account.name} ••••${account.last3Digits ?? account.accountNumber}'
        : '${recommendations.first.bankName} ••••${recommendations.first.accountLast4}';

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withAlpha(70)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account title header
          Row(
            children: [
              Icon(Icons.account_balance, size: 18, color: cs.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  accountName,
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                '${recommendations.length} new ${recommendations.length == 1 ? 'pattern' : 'patterns'}',
                style: AppTypography.labelMuted.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Pattern list
          for (final rec in recommendations) ...[
            _buildPatternRow(cs, rec),
            if (rec != recommendations.last) const SizedBox(height: AppSpacing.xs),
          ],

          // Display observed sender variations covered by bank identifier
          () {
            final allObserved = <String>{};
            String bankId = '';
            for (final r in recommendations) {
              if (r.bankIdentifier.isNotEmpty) bankId = r.bankIdentifier;
              allObserved.addAll(r.observedSenderVariations);
            }
            if (allObserved.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Sender Variations Observed (${allObserved.length})',
                            style: AppTypography.labelMuted.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${allObserved.join(", ")}\nAlready covered by bank identifier: ${bankId.isNotEmpty ? bankId : account?.bankName ?? "known bank"}',
                        style: AppTypography.labelMuted.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }(),
        ],
      ),
    );
  }

  Widget _buildPatternRow(ColorScheme cs, AccountPatternRecommendation rec) {
    final isSelected = _selectionMap[rec.recommendationId] ?? false;

    return InkWell(
      onTap: () {
        setState(() {
          _selectionMap[rec.recommendationId] = !isSelected;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  _selectionMap[rec.recommendationId] = val ?? false;
                });
              },
              activeColor: cs.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildPatternTypeChip(cs, rec.patternType),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rec.patternValue,
                          style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.sourceMessageCount > 1
                        ? '${rec.reason} • Found in ${rec.sourceMessageCount} messages'
                        : rec.reason,
                    style: AppTypography.labelMuted.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternTypeChip(ColorScheme cs, String patternType) {
    String label;
    Color color;

    switch (patternType) {
      case 'bank_identifier':
        label = 'Bank Identifier';
        color = Colors.indigo;
        break;
      case 'account_pattern':
        label = 'Account Pattern';
        color = Colors.blue;
        break;
      case 'transaction_pattern':
        label = 'Transaction Pattern';
        color = Colors.teal;
        break;
      case 'balance_pattern':
        label = 'Balance Pattern';
        color = Colors.green;
        break;
      case 'sender_fallback':
        label = 'Sender Fallback';
        color = Colors.deepPurple;
        break;
      case 'sender':
        label = 'Sender';
        color = Colors.purple;
        break;
      default:
        label = 'Pattern';
        color = cs.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

}

/// Helper function to show the review bottom sheet.
Future<List<AccountPatternRecommendation>?> showAccountPatternReviewSheet({
  required BuildContext context,
  required List<AccountPatternRecommendation> recommendations,
  required List<Account> accounts,
  Future<void> Function(List<AccountPatternRecommendation> approved)? onApprove,
}) {
  final actionableRecommendations = recommendations.where((r) => r.accountId != null).toList();
  if (actionableRecommendations.isEmpty) return Future.value(null);

  return showModalBottomSheet<List<AccountPatternRecommendation>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AccountPatternReviewSheet(
      recommendations: actionableRecommendations,
      accounts: accounts,
      onApprove: onApprove,
    ),
  );
}
