import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'category_icon.dart';

class TransactionDetailDialog extends StatefulWidget {
  final Transaction transaction;
  final TransactionRepository? repository;

  const TransactionDetailDialog({
    super.key,
    required this.transaction,
    this.repository,
  });

  @override
  State<TransactionDetailDialog> createState() => _TransactionDetailDialogState();
}

class _TransactionDetailDialogState extends State<TransactionDetailDialog> {
  late Transaction _currentTransaction;

  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.transaction;
  }

  Future<void> _openEditTitleDialog() async {
    final updatedTitle = await showDialog<String?>(
      context: context,
      builder: (ctx) => EditTransactionTitleDialog(
        transaction: _currentTransaction,
        repository: widget.repository,
      ),
    );

    if (updatedTitle != null && mounted) {
      setState(() {
        final title = updatedTitle.trim().isEmpty ? null : updatedTitle.trim();
        _currentTransaction = _currentTransaction.copyWith(customTitle: title);
      });
    }
  }

  void _openCategorySelector() {
    final cs = Theme.of(context).colorScheme;
    final currentKey = TransactionCategory.normalize(_currentTransaction.effectiveCategory);

    final categories = [
      {'key': TransactionCategory.food, 'label': 'Food', 'icon': Icons.restaurant},
      {'key': TransactionCategory.bills, 'label': 'Bills', 'icon': Icons.receipt_long},
      {'key': TransactionCategory.shopping, 'label': 'Shopping', 'icon': Icons.shopping_bag},
      {'key': TransactionCategory.others, 'label': 'Others', 'icon': Icons.more_horiz},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withAlpha(100),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Text(
                    'Select Category',
                    style: AppTypography.headlineMd.copyWith(color: cs.onSurface),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...categories.map((cat) {
                  final key = cat['key'] as String;
                  final label = cat['label'] as String;
                  final icon = cat['icon'] as IconData;
                  final isSelected = key == currentKey;

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary.withAlpha(30) : cs.surfaceContainerLowest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      label,
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? cs.primary : cs.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: cs.primary, size: 22)
                        : Icon(Icons.radio_button_unchecked, color: cs.outlineVariant, size: 22),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final repo = widget.repository ?? TransactionRepository();
                      try {
                        await repo.updateTransactionCategory(_currentTransaction.id, key);
                      } catch (_) {}
                      if (mounted) {
                        setState(() {
                          _currentTransaction = _currentTransaction.copyWith(
                            customCategory: key,
                            category: key,
                          );
                        });
                      }
                    },
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = _currentTransaction.type == TransactionType.income;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Transaction Details',
                        style: AppTypography.headlineMd.copyWith(color: cs.onSurface),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: cs.onSurfaceVariant,
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Amount banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: cs.outlineVariant.withAlpha(80)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${isIncome ? '+' : '-'}₹ ${NumberFormat('#,##0.00').format(_currentTransaction.amount)}',
                        style: AppTypography.displayCurrency.copyWith(
                          color: isIncome ? AppColors.successGreen : cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isIncome ? 'Income' : 'Expense',
                        style: AppTypography.labelCaps.copyWith(
                          color: isIncome ? AppColors.successGreen : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title / Merchant Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: cs.outlineVariant.withAlpha(80)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Title',
                              style: AppTypography.labelCaps.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentTransaction.displayTitle,
                              style: AppTypography.bodyLg.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _openEditTitleDialog,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Title'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.primary,
                          side: BorderSide(color: cs.primary),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                          textStyle: AppTypography.labelCaps,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Category Section (Interactive Editable Control)
                InkWell(
                  onTap: _openCategorySelector,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: cs.outlineVariant.withAlpha(80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CategoryIcon(category: _currentTransaction.displayCategory, size: 36),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category',
                                style: AppTypography.labelCaps.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentTransaction.displayCategory,
                                style: AppTypography.bodyLg.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.unfold_more, color: cs.primary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Metadata Rows
                _buildInfoRow(
                  context,
                  icon: Icon(Icons.calendar_today_outlined, size: 20, color: cs.primary),
                  label: 'Date & Time',
                  value: DateFormat('MMM dd, yyyy • hh:mm a').format(_currentTransaction.date),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (_currentTransaction.subtitle != null && _currentTransaction.subtitle!.isNotEmpty) ...[
                  _buildInfoRow(
                    context,
                    icon: Icon(Icons.account_balance_outlined, size: 20, color: cs.primary),
                    label: 'Source / Bank',
                    value: _currentTransaction.subtitle!,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                if (_currentTransaction.upiReference != null && _currentTransaction.upiReference!.isNotEmpty) ...[
                  _buildInfoRow(
                    context,
                    icon: Icon(Icons.tag_outlined, size: 20, color: cs.primary),
                    label: 'Reference / ID',
                    value: _currentTransaction.upiReference!,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Original SMS / Message
                if (_currentTransaction.rawMessage != null && _currentTransaction.rawMessage!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Original Message',
                    style: AppTypography.labelCaps.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: cs.outlineVariant.withAlpha(80)),
                    ),
                    child: SelectableText(
                      _currentTransaction.rawMessage!,
                      style: AppTypography.bodyMd.copyWith(
                        color: cs.onSurface,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required Widget icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelMuted.copyWith(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                Text(
                  value,
                  style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500, color: cs.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditTransactionTitleDialog extends StatefulWidget {
  final Transaction transaction;
  final TransactionRepository? repository;

  const EditTransactionTitleDialog({
    super.key,
    required this.transaction,
    this.repository,
  });

  @override
  State<EditTransactionTitleDialog> createState() => _EditTransactionTitleDialogState();
}

class _EditTransactionTitleDialogState extends State<EditTransactionTitleDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialText = widget.transaction.customTitle ??
        (widget.transaction.merchant.isNotEmpty && widget.transaction.merchant.toLowerCase() != 'unknown merchant'
            ? widget.transaction.merchant
            : '');
    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveTitle() async {
    final text = _controller.text.trim();
    final customTitle = text.isEmpty ? null : text;
    final repo = widget.repository ?? TransactionRepository();

    setState(() => _isSaving = true);

    try {
      await repo.updateTransactionTitle(widget.transaction.id, customTitle);
      if (mounted) {
        Navigator.pop(context, customTitle ?? '');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update title: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text(
        'Edit Transaction Title',
        style: AppTypography.headlineMd.copyWith(color: cs.onSurface),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              keyboardType: TextInputType.text,
              style: AppTypography.bodyLg.copyWith(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: 'Transaction title',
                hintText: 'e.g. Amazon, Food, Rent',
                counterText: '',
                labelStyle: TextStyle(color: cs.onSurfaceVariant),
                hintStyle: TextStyle(color: cs.outline),
              ),
              onSubmitted: (_) => _saveTitle(),
            ),
            const SizedBox(height: 4),
            Text(
              'Leave empty to restore detected merchant name.',
              style: AppTypography.labelMuted.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: AppTypography.labelCaps.copyWith(color: cs.onSurfaceVariant)),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveTitle,
          style: FilledButton.styleFrom(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
