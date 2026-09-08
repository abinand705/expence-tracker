import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/sms_recognition_rule.dart';
import '../models/transaction.dart';
import '../repositories/sms_rule_repository.dart';
import '../services/sms_rule_builder.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Screen for adding or editing an SMS recognition rule.
///
/// Two-step flow:
///   1. Paste sample SMS → Detect fields
///   2. Review / edit → Save
///
/// IMPORTANT: This screen saves STRUCTURAL rules only.
/// The detected amount, balance, reference ID are shown for PREVIEW only
/// and are NOT hardcoded in the saved rule. Future SMS with different
/// values will be parsed correctly.
class AddSmsRuleScreen extends StatefulWidget {
  final Account account;
  final SmsRecognitionRule? ruleToEdit;

  const AddSmsRuleScreen({
    super.key,
    required this.account,
    this.ruleToEdit,
  });

  @override
  State<AddSmsRuleScreen> createState() => _AddSmsRuleScreenState();
}

class _AddSmsRuleScreenState extends State<AddSmsRuleScreen> {
  final _ruleRepo = SmsRuleRepository();

  // Step tracking
  int _step = 0; // 0 = paste SMS, 1 = review

  // Controllers
  final _senderCtrl = TextEditingController();
  final _sampleSmsCtrl = TextEditingController();
  final _accountIdCtrl = TextEditingController();
  String _ruleLabel = 'Debit';

  SmsRuleSuggestion? _suggestion;
  TransactionType _txType = TransactionType.expense;
  bool _isSaving = false;
  bool _isDetecting = false;

  bool get _isEditMode => widget.ruleToEdit != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.ruleToEdit;
    if (rule != null) {
      _senderCtrl.text = rule.senderPatterns.join(', ');
      _sampleSmsCtrl.text = rule.sampleSms ?? '';
      _accountIdCtrl.text = rule.accountIdentifier;
      _ruleLabel = rule.ruleLabel;
      _txType = rule.coversDebit ? TransactionType.expense : TransactionType.income;
      _step = 1; // Go straight to review for edits
    } else {
      // Pre-fill account identifier from account
      final digits = widget.account.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 3) {
        _accountIdCtrl.text = digits.substring(digits.length - 3);
      }
    }
  }

  @override
  void dispose() {
    _senderCtrl.dispose();
    _sampleSmsCtrl.dispose();
    _accountIdCtrl.dispose();
    super.dispose();
  }

  void _detectFields() {
    if (_smsCtrlText.isEmpty) {
      _showError('Please paste a sample SMS.');
      return;
    }
    setState(() {
      _isDetecting = true;
      _suggestion = null;
    });

    final suggestion = SmsRuleBuilder.parseSampleSms(
      smsBody: _smsCtrlText,
      sender: _senderCtrl.text.trim(),
      knownAccountIdentifier: _accountIdCtrl.text.trim(),
    );

    setState(() {
      _suggestion = suggestion;
      _isDetecting = false;
      if (suggestion.transactionType != null) _txType = suggestion.transactionType!;
      // Auto-update account identifier if detected and field is empty
      if (suggestion.detectedAccountSuffix != null && _accountIdCtrl.text.trim().isEmpty) {
        _accountIdCtrl.text = suggestion.detectedAccountSuffix!;
      }
      _step = 1;
    });

    if (!suggestion.couldParse && suggestion.parseWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(suggestion.parseWarning!)));
    }
  }

  String get _smsCtrlText => _sampleSmsCtrl.text.trim();

  Future<void> _saveRule() async {
    if (_senderCtrl.text.trim().isEmpty) {
      _showError('Sender pattern is required (e.g. VK-KGBANK).');
      return;
    }
    if (_accountIdCtrl.text.trim().isEmpty) {
      _showError('Account identifier is required.');
      return;
    }

    final senders = _senderCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _isSaving = true);
    try {
      final rule = SmsRuleBuilder.buildRule(
        accountId: widget.account.id,
        ruleLabel: _ruleLabel,
        senderPatterns: senders,
        accountIdentifier: _accountIdCtrl.text.trim(),
        suggestion: _suggestion ?? const SmsRuleSuggestion(couldParse: false),
        transactionType: _txType,
        sampleSmsForReference: _smsCtrlText.isNotEmpty ? _smsCtrlText : null,
      );

      final validationError = SmsRuleBuilder.validateRule(rule);
      if (validationError != null) {
        _showError(validationError);
        return;
      }

      if (_isEditMode) {
        final updated = rule.copyWith(
          id: widget.ruleToEdit!.id,
          updatedAt: DateTime.now(),
        );
        await _ruleRepo.updateRule(updated);
      } else {
        await _ruleRepo.addRule(rule);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed to save rule: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit SMS Rule' : 'Add SMS Rule',
            style: AppTypography.headlineMd),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 1 && !_isEditMode) {
              setState(() => _step = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _step == 0 ? _buildStep0(cs) : _buildStep1(cs),
    );
  }

  // ── Step 0: Paste SMS ─────────────────────────────────────────────────────
  Widget _buildStep0(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paste a Sample SMS', style: AppTypography.headlineMd),
          const SizedBox(height: 4),
          Text(
            'MoneyTrack will detect the message structure. '
            'The actual amount, balance, and reference in the sample are '
            'used for preview only — they are NOT hardcoded as match criteria.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          _label('Rule Type'),
          DropdownButtonFormField<String>(
            initialValue: _ruleLabel,
            decoration: _dec(null),
            items: ['Debit', 'Credit', 'UPI Debit', 'UPI Credit', 'ATM', 'Other']
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _ruleLabel = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          _label('Sender Pattern(s) *'),
          TextField(
            controller: _senderCtrl,
            decoration: _dec('e.g. VK-KGBANK, AD-KGBANK (comma-separated)'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 4),
          Text('Separate multiple senders with commas.',
              style: AppTypography.labelMuted.copyWith(fontSize: 11)),
          const SizedBox(height: AppSpacing.md),

          _label('Account Identifier *'),
          TextField(
            controller: _accountIdCtrl,
            decoration: _dec('Last 3-6 digits, e.g. 544'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 4),
          Text(
              'The digit sequence that appears in SMS body to identify this account.',
              style: AppTypography.labelMuted.copyWith(fontSize: 11)),
          const SizedBox(height: AppSpacing.md),

          _label('Sample SMS *'),
          TextField(
            controller: _sampleSmsCtrl,
            decoration: _dec(
                'Paste a real bank SMS for this account…'),
            maxLines: 5,
            minLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),

          ElevatedButton.icon(
            onPressed: _isDetecting ? null : _detectFields,
            icon: _isDetecting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(_isDetecting ? 'Detecting…' : 'Detect Fields'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Step 1: Review & Save ─────────────────────────────────────────────────
  Widget _buildStep1(ColorScheme cs) {
    final s = _suggestion;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Confirm', style: AppTypography.headlineMd),
          const SizedBox(height: 4),
          Text(
            'Edit fields if needed, then save. '
            'The detected amounts and references are previews only.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (s?.parseWarning != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(s!.parseWarning!,
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
            ),

          // Editable fields
          _label('Rule Type'),
          DropdownButtonFormField<String>(
            initialValue: _ruleLabel,
            decoration: _dec(null),
            items: ['Debit', 'Credit', 'UPI Debit', 'UPI Credit', 'ATM', 'Other']
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _ruleLabel = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          _label('Transaction Type'),
          DropdownButtonFormField<TransactionType>(
            initialValue: _txType,
            decoration: _dec(null),
            items: [
              const DropdownMenuItem(
                  value: TransactionType.expense, child: Text('Debit (Expense)')),
              const DropdownMenuItem(
                  value: TransactionType.income, child: Text('Credit (Income)')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _txType = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          _label('Sender Pattern(s)'),
          TextField(
            controller: _senderCtrl,
            decoration: _dec('e.g. VK-KGBANK'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: AppSpacing.md),

          _label('Account Identifier'),
          TextField(
            controller: _accountIdCtrl,
            decoration: _dec('e.g. 544'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Preview of what was detected (read-only)
          if (s != null && s.couldParse) ...[
            Text('Detected from Sample (Preview Only)',
                style: AppTypography.labelMuted.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            _previewRow(cs, 'Amount', s.detectedAmount != null
                ? '₹${s.detectedAmount!.toStringAsFixed(2)}'
                : '—',
                note: 'Any amount will be extracted from future SMS'),
            _previewRow(cs, 'Balance', s.detectedBalance != null
                ? '₹${s.detectedBalance!.toStringAsFixed(2)}'
                : '—',
                note: 'Actual balance read from each SMS'),
            _previewRow(cs, 'Reference', s.detectedReferenceId ?? '—',
                note: 'Actual reference read from each SMS'),
            _previewRow(cs, 'Date/Time',
                s.detectedDateTime?.toString() ?? '—',
                note: 'Actual date read from each SMS'),
            const SizedBox(height: AppSpacing.lg),
          ],

          ElevatedButton(
            onPressed: _isSaving ? null : _saveRule,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base)),
            ),
            child: _isSaving
                ? CircularProgressIndicator(color: cs.onPrimary)
                : Text(_isEditMode ? 'Update Rule' : 'Save Rule'),
          ),
          if (!_isEditMode) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => setState(() => _step = 0),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base)),
              ),
              child: const Text('Re-paste SMS'),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _previewRow(ColorScheme cs, String label, String value, {String? note}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTypography.labelMuted.copyWith(fontSize: 11)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                if (note != null)
                  Text(note,
                      style: AppTypography.labelMuted.copyWith(
                          fontSize: 10, fontStyle: FontStyle.italic,
                          color: cs.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppTypography.labelMuted
                .copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
      );

  InputDecoration _dec(String? hint) => InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        counterText: '',
      );
}
