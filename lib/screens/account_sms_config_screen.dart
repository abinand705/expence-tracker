import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/sms_recognition_rule.dart';
import '../repositories/account_repository.dart';
import '../repositories/sms_rule_repository.dart';
import '../services/sms_rule_builder.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/sms_service.dart';
import 'add_sms_rule_screen.dart';

/// Per-account SMS Recognition configuration screen.
///
/// Shows:
/// - SMS tracking toggle (ON/OFF)
/// - List of configured rules
/// - Add/Edit/Delete rule actions
/// - Test SMS feature (never creates a transaction)
class AccountSmsConfigScreen extends StatefulWidget {
  final Account account;

  const AccountSmsConfigScreen({super.key, required this.account});

  @override
  State<AccountSmsConfigScreen> createState() => _AccountSmsConfigScreenState();
}

class _AccountSmsConfigScreenState extends State<AccountSmsConfigScreen> {
  final _accountRepo = AccountRepository();
  final _ruleRepo = SmsRuleRepository();

  late Account _account;
  List<SmsRecognitionRule> _rules = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      final rules = await _ruleRepo.getRules(_account.id);
      setState(() {
        _rules = rules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSmsTracking(bool value) async {
    if (value && _rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Configure at least one SMS rule before enabling SMS tracking.'),
        ),
      );
      return;
    }
    try {
      final updated = _account.copyWith(smsTrackingEnabled: value);
      await _accountRepo.updateAccount(updated);
      setState(() => _account = updated);
      if (value) {
        await _syncAccountTransactions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  Future<void> _deleteRule(SmsRecognitionRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Delete "${rule.ruleLabel}" rule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _ruleRepo.deleteRule(_account.id, rule.id);
      await _loadRules();
      // If no rules left, disable SMS tracking
      if (_rules.isEmpty && _account.smsTrackingEnabled) {
        await _toggleSmsTracking(false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  Future<void> _addRule() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddSmsRuleScreen(account: _account),
      ),
    );
    if (result == true) {
      await _loadRules();
      // Auto-enable SMS tracking if first rule added
      if (_rules.isNotEmpty && !_account.smsTrackingEnabled) {
        final updated = _account.copyWith(smsTrackingEnabled: true);
        await _accountRepo.updateAccount(updated);
        setState(() => _account = updated);
      }
      await _syncAccountTransactions();
    }
  }

  Future<void> _syncAccountTransactions() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final summary = await SmsService().syncTransactions(targetAccountId: _account.id);
      final refreshed = await _accountRepo.getAccountById(_account.id);
      if (mounted) {
        if (refreshed != null) {
          setState(() => _account = refreshed);
        }
        setState(() => _isSyncing = false);
        final balStr = _account.currentBalance < 0
            ? '-₹${(-_account.currentBalance).toStringAsFixed(2)}'
            : '₹${_account.currentBalance.toStringAsFixed(2)}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              summary.imported > 0
                  ? 'Imported ${summary.imported} transactions! Balance updated to $balStr'
                  : 'SMS check complete. Balance: $balStr',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AccountSmsConfigScreen] sync error: $e');
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _editRule(SmsRecognitionRule rule) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddSmsRuleScreen(account: _account, ruleToEdit: rule),
      ),
    );
    if (result == true) await _loadRules();
  }

  void _showTestSms() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => _TestSmsSheet(account: _account, rules: _rules),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('SMS Recognition', style: AppTypography.headlineMd),
        elevation: 0,
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_account.smsTrackingEnabled)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync SMS & Balance',
              onPressed: _syncAccountTransactions,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account info card
                  _buildAccountCard(cs),
                  const SizedBox(height: AppSpacing.lg),

                  // SMS Tracking toggle
                  _buildTrackingToggle(cs),
                  const SizedBox(height: AppSpacing.lg),

                  // Rules section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Configured Rules',
                          style: AppTypography.headlineMd.copyWith(fontSize: 16)),
                      TextButton.icon(
                        onPressed: _addRule,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Rule'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (_rules.isEmpty)
                    _buildNoRulesCard(cs)
                  else
                    ..._rules.map((rule) => _buildRuleCard(cs, rule)),

                  const SizedBox(height: AppSpacing.lg),

                  // Test SMS button
                  if (_rules.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _showTestSms,
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Test SMS'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.base)),
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildAccountCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _account.accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance, color: _account.accentColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_account.bankName,
                    style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${_account.accountType} • ${_account.maskedAccountNumber}',
                  style: AppTypography.labelMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingToggle(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SMS Transaction Tracking',
                    style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  _account.smsTrackingEnabled
                      ? 'Enabled — matching SMS will create transactions'
                      : 'Disabled — SMS will not create transactions',
                  style: AppTypography.labelMuted.copyWith(
                    color: _account.smsTrackingEnabled
                        ? AppColors.successGreen
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _account.smsTrackingEnabled,
            onChanged: _toggleSmsTracking,
            activeThumbColor: AppColors.successGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildNoRulesCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.sms_failed_outlined, color: cs.onSurfaceVariant, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text('SMS Not Configured',
              style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Add an SMS rule to enable automatic transaction tracking for this account.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: _addRule,
            icon: const Icon(Icons.add),
            label: const Text('Add SMS Rule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(ColorScheme cs, SmsRecognitionRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: rule.isEnabled
              ? AppColors.successGreen.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: rule.coversDebit
                      ? AppColors.errorRed.withValues(alpha: 0.1)
                      : AppColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  rule.ruleLabel,
                  style: AppTypography.labelMuted.copyWith(
                    color: rule.coversDebit
                        ? AppColors.errorRed
                        : AppColors.successGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: cs.primary),
                onPressed: () => _editRule(rule),
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                onPressed: () => _deleteRule(rule),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildRuleDetailRow(cs, 'Sender', rule.senderPatterns.join(', ')),
          _buildRuleDetailRow(cs, 'Account ID', '•••${rule.accountIdentifier}'),
          if (rule.debitKeywords.isNotEmpty)
            _buildRuleDetailRow(cs, 'Debit Keywords',
                rule.debitKeywords.take(3).join(', ') +
                    (rule.debitKeywords.length > 3 ? '…' : '')),
          if (rule.creditKeywords.isNotEmpty)
            _buildRuleDetailRow(cs, 'Credit Keywords',
                rule.creditKeywords.take(3).join(', ') +
                    (rule.creditKeywords.length > 3 ? '…' : '')),
          if (!rule.isEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Disabled',
                  style: TextStyle(color: cs.error, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildRuleDetailRow(ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: AppTypography.labelMuted.copyWith(fontSize: 11)),
          ),
          Expanded(
            child: Text(value,
                style: AppTypography.bodyMd.copyWith(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test SMS Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TestSmsSheet extends StatefulWidget {
  final Account account;
  final List<SmsRecognitionRule> rules;

  const _TestSmsSheet({required this.account, required this.rules});

  @override
  State<_TestSmsSheet> createState() => _TestSmsSheetState();
}

class _TestSmsSheetState extends State<_TestSmsSheet> {
  final _smsCtrl = TextEditingController();
  final _senderCtrl = TextEditingController();
  SmsRuleSuggestion? _result;
  bool _analyzed = false;
  String? _matchedSender;

  @override
  void dispose() {
    _smsCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  void _analyze() {
    if (_smsCtrl.text.trim().isEmpty) return;
    if (_senderCtrl.text.trim().isEmpty) return;

    // Check if any configured rule matches
    bool senderMatched = false;
    bool idMatched = false;
    SmsRecognitionRule? matchedRule;

    for (final rule in widget.rules) {
      if (rule.matchesSender(_senderCtrl.text.trim())) {
        senderMatched = true;
        if (rule.matchesAccountIdentifier(_smsCtrl.text.trim())) {
          idMatched = true;
          matchedRule = rule;
          break;
        }
      }
    }

    final suggestion = SmsRuleBuilder.parseSampleSms(
      smsBody: _smsCtrl.text.trim(),
      sender: _senderCtrl.text.trim(),
    );

    setState(() {
      _result = suggestion;
      _analyzed = true;
      _matchedSender = matchedRule != null ? 'Yes — ${matchedRule.ruleLabel} rule' : null;

      if (!senderMatched) {
        _matchedSender = 'No — sender "${_senderCtrl.text.trim()}" not in configured patterns';
      } else if (!idMatched) {
        _matchedSender = 'No — account identifier not found in SMS';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: cs.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Test SMS', style: AppTypography.headlineMd),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '⚠ This is a test only. No transaction will be saved.',
                style: AppTypography.bodyMd.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _senderCtrl,
              decoration: const InputDecoration(
                labelText: 'Sender ID',
                hintText: 'e.g. VK-KGBANK',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _smsCtrl,
              decoration: const InputDecoration(
                labelText: 'Paste SMS',
                hintText: 'Paste a real bank SMS here…',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              minLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base)),
              ),
              child: const Text('Analyse'),
            ),
            if (_analyzed && _result != null) ...[
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Text('Results', style: AppTypography.headlineMd.copyWith(fontSize: 16)),
              const SizedBox(height: AppSpacing.sm),
              _resultRow(cs, 'Matched Account',
                  _matchedSender ?? 'No match',
                  isGood: _matchedSender != null && _matchedSender!.startsWith('Yes')),
              _resultRow(cs, 'Transaction Type', _result!.transactionTypeDisplay),
              _resultRow(cs, 'Amount',
                  _result!.detectedAmount != null
                      ? '₹${_result!.detectedAmount!.toStringAsFixed(2)}'
                      : 'Not detected'),
              _resultRow(cs, 'Date',
                  _result!.detectedDateTime?.toString() ?? 'Not detected'),
              _resultRow(cs, 'Reference ID', _result!.detectedReferenceId ?? 'Not detected'),
              _resultRow(cs, 'Balance',
                  _result!.detectedBalance != null
                      ? (_result!.detectedBalance! < 0
                          ? '-₹${(-_result!.detectedBalance!).toStringAsFixed(2)}'
                          : '₹${_result!.detectedBalance!.toStringAsFixed(2)}')
                      : 'Not detected'),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (_matchedSender != null && _matchedSender!.startsWith('Yes'))
                      ? AppColors.successGreen.withValues(alpha: 0.1)
                      : AppColors.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  (_matchedSender != null && _matchedSender!.startsWith('Yes'))
                      ? '✓ Would create this transaction (test only — not saved)'
                      : '✗ Would NOT create a transaction for this SMS',
                  style: TextStyle(
                    color: (_matchedSender != null && _matchedSender!.startsWith('Yes'))
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(ColorScheme cs, String label, String value, {bool? isGood}) {
    Color? valueColor;
    if (isGood == true) valueColor = AppColors.successGreen;
    if (isGood == false) valueColor = AppColors.errorRed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTypography.labelMuted.copyWith(fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? cs.onSurface,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
