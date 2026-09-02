import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../services/export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ExportDataScreen extends StatefulWidget {
  final ExportService? exportService;

  const ExportDataScreen({
    super.key,
    this.exportService,
  });

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  late final ExportService _exportService;

  QuickDateRange _selectedQuickRange = QuickDateRange.thisMonth;
  late DateTime _startDate;
  late DateTime _endDate;

  bool _isLoadingPreview = true;
  bool _isExporting = false;
  String _exportStatusText = 'Exporting...';

  ExportSummary? _currentSummary;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _exportService = widget.exportService ?? ExportService();

    final (start, end) = ExportService.calculateQuickRange(QuickDateRange.thisMonth);
    _startDate = start;
    _endDate = end;

    _loadPreview();
  }

  void _onQuickRangeSelected(QuickDateRange range) {
    setState(() {
      _selectedQuickRange = range;
      if (range != QuickDateRange.custom) {
        final (start, end) = ExportService.calculateQuickRange(range);
        _startDate = start;
        _endDate = end;
      }
    });
    _validateAndRefreshPreview();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _selectedQuickRange = QuickDateRange.custom;
      });
      _validateAndRefreshPreview();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _selectedQuickRange = QuickDateRange.custom;
      });
      _validateAndRefreshPreview();
    }
  }

  void _validateAndRefreshPreview() {
    if (_startDate.isAfter(_endDate)) {
      setState(() {
        _validationError = 'Start date cannot be after end date.';
        _currentSummary = null;
        _isLoadingPreview = false;
      });
      return;
    }

    setState(() {
      _validationError = null;
      _isLoadingPreview = true;
    });

    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final transactions = await _exportService.getExpenseTransactions(
        startDate: _startDate,
        endDate: _endDate,
      );

      if (mounted) {
        setState(() {
          _currentSummary = _exportService.calculateSummary(
            transactions,
            startDate: _startDate,
            endDate: _endDate,
          );
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      developer.log('Error loading export preview: $e', name: 'ExportDataScreen');
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
        });
      }
    }
  }

  Future<void> _executeExport() async {
    if (_isExporting || _validationError != null) return;

    if (_currentSummary != null && _currentSummary!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No expenses to export for the selected date range.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _exportStatusText = 'Preparing expenses...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      setState(() => _exportStatusText = 'Generating CSV file...');
      final result = await _exportService.exportExpensesToCsv(
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;

      setState(() => _isExporting = false);

      if (result.success && result.filePath != null) {
        _showSuccessDialog(result);
      } else if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No expense transactions found in the selected period.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to export data.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      developer.log('Export execution failed: $e', name: 'ExportDataScreen');
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred while exporting.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(ExportResult result) {
    final cs = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.successGreen,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Export Completed!',
                style: AppTypography.headlineMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${result.summary.count} expenses exported • ${currencyFormatter.format(result.summary.totalAmount)}',
                style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.insert_drive_file_outlined, size: 20, color: cs.primaryContainer),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            result.fileName ?? '',
                            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Saved to: ${result.filePath}',
                      style: AppTypography.labelCaps.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (result.filePath != null) {
                          try {
                            await SharePlus.instance.share(
                              ShareParams(
                                files: [XFile(result.filePath!)],
                              ),
                            );
                          } catch (e) {
                            developer.log('Share error: $e', name: 'ExportDataScreen');
                          }
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        side: BorderSide(color: cs.primaryContainer),
                        foregroundColor: cs.primaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (result.filePath != null) {
                          final openResult = await OpenFilex.open(result.filePath!);
                          if (openResult.type != ResultType.done && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open file: ${openResult.message}')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open File'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        backgroundColor: cs.primaryContainer,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(modalContext),
                child: Text('Done', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getQuickRangeLabel(QuickDateRange range) {
    switch (range) {
      case QuickDateRange.today:
        return 'Today';
      case QuickDateRange.thisWeek:
        return 'This Week';
      case QuickDateRange.thisMonth:
        return 'This Month';
      case QuickDateRange.lastMonth:
        return 'Last Month';
      case QuickDateRange.last3Months:
        return 'Last 3 Months';
      case QuickDateRange.thisYear:
        return 'This Year';
      case QuickDateRange.custom:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: Text('Export Expense Data', style: AppTypography.headlineMd),
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            children: [
              // Section 1: Quick Presets
              Text('QUICK PERIODS', style: AppTypography.labelCaps),
              const SizedBox(height: AppSpacing.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: QuickDateRange.values.map((range) {
                    final isSelected = _selectedQuickRange == range;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(_getQuickRangeLabel(range)),
                        labelStyle: AppTypography.bodyMd.copyWith(
                          color: isSelected ? Colors.white : cs.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        backgroundColor: cs.surface,
                        selectedColor: cs.primaryContainer,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          side: BorderSide(
                            color: isSelected ? cs.primaryContainer : cs.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        onSelected: (_) => _onQuickRangeSelected(range),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Section 2: Date Selector
              Text('DATE RANGE', style: AppTypography.labelCaps),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _buildDateCard(
                      context,
                      label: 'Start Date',
                      dateStr: dateFormat.format(_startDate),
                      onTap: _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildDateCard(
                      context,
                      label: 'End Date',
                      dateStr: dateFormat.format(_endDate),
                      onTap: _pickEndDate,
                    ),
                  ),
                ],
              ),

              if (_validationError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: AppTypography.bodyMd.copyWith(color: AppColors.errorRed),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Section 3: Summary / Live Preview Card
              Text('SUMMARY PREVIEW', style: AppTypography.labelCaps),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.level1,
                ),
                child: _isLoadingPreview
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : (_currentSummary == null || _currentSummary!.isEmpty)
                        ? Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 40, color: cs.outline),
                              const SizedBox(height: AppSpacing.sm),
                              Text('No expenses found', style: AppTypography.headlineMd),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'There are no expense transactions in the selected period (${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)}).',
                                style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Selected Period', style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant)),
                                  Text(
                                    '${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)}',
                                    style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const Divider(height: AppSpacing.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Expense Transactions', style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant)),
                                  Text(
                                    '${_currentSummary!.count}',
                                    style: AppTypography.headlineMd.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Amount', style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant)),
                                  Text(
                                    currencyFormatter.format(_currentSummary!.totalAmount),
                                    style: AppTypography.headlineMd.copyWith(
                                      color: AppColors.errorRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Section 4: File Format Info
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: cs.primaryContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Format: CSV (Compatible with Microsoft Excel, Google Sheets, LibreOffice). Saved to Android Downloads.',
                        style: AppTypography.bodyMd.copyWith(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Section 5: Export Button
              ElevatedButton.icon(
                onPressed: (_isExporting || _validationError != null || (_currentSummary?.isEmpty ?? true))
                    ? null
                    : _executeExport,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export Expense Data (CSV)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),

          // Loading Overlay
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.level2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: cs.primaryContainer),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _exportStatusText,
                        style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateCard(
    BuildContext context, {
    required String label,
    required String dateStr,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: AppShadows.level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.labelCaps.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateStr, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                Icon(Icons.calendar_today_outlined, size: 18, color: cs.primaryContainer),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
