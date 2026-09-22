import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/discovered_bank_account.dart';
import '../models/sms_recognition_rule.dart';
import '../repositories/account_discovery_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/sms_rule_repository.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Shows the account discovery bottom sheet or dialog.
///
/// If multiple accounts are provided, displays a list allowing the user
/// to review/set up each account. If a single account is provided, opens
/// the initialization configuration dialog directly.
Future<void> showAccountDiscoveryDialog({
  required BuildContext context,
  required List<DiscoveredBankAccount> discoveries,
  VoidCallback? onCompleted,
}) async {
  if (discoveries.isEmpty) return;

  if (discoveries.length == 1) {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccountInitializationSheet(
        discovery: discoveries.first,
        onCompleted: onCompleted,
      ),
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiAccountDiscoverySheet(
        discoveries: discoveries,
        onCompleted: onCompleted,
      ),
    );
  }
}

/// Sheet listing multiple discovered bank accounts.
class MultiAccountDiscoverySheet extends StatelessWidget {
  final List<DiscoveredBankAccount> discoveries;
  final VoidCallback? onCompleted;

  const MultiAccountDiscoverySheet({
    super.key,
    required this.discoveries,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

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
          Text(
            'Bank Accounts Found',
            style: AppTypography.headlineMd.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            '${discoveries.length} potential bank accounts were detected from your messages.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: discoveries.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final d = discoveries[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance, color: cs.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.bankName,
                              style: AppTypography.bodyLg.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Account: ${d.maskedAccountNumber} • ${d.accountType}',
                              style: AppTypography.labelMuted.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            if (d.detectedBalance != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Balance: ${currencyFormatter.format(d.detectedBalance)}*',
                                style: AppTypography.labelMuted.copyWith(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              '${d.messageCount} bank messages found',
                              style: AppTypography.labelMuted.copyWith(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => AccountInitializationSheet(
                              discovery: d,
                              onCompleted: onCompleted,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Set Up'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  final repo = AccountDiscoveryRepository();
                  for (final d in discoveries) {
                    repo.dismissDiscovery(d.discoveryId);
                  }
                  Navigator.pop(context);
                },
                child: Text('Not Now', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Detailed account initialization & SMS recognition configuration sheet.
class AccountInitializationSheet extends StatefulWidget {
  final DiscoveredBankAccount discovery;
  final VoidCallback? onCompleted;

  const AccountInitializationSheet({
    super.key,
    required this.discovery,
    this.onCompleted,
  });

  @override
  State<AccountInitializationSheet> createState() => _AccountInitializationSheetState();
}

class _AccountInitializationSheetState extends State<AccountInitializationSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bankNameCtrl;
  late TextEditingController _accountNameCtrl;
  late TextEditingController _balanceCtrl;
  late String _accountType;

  late Map<String, bool> _selectedSenders;
  late Map<String, bool> _selectedPatterns;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.discovery;
    _bankNameCtrl = TextEditingController(text: d.bankName);
    _accountNameCtrl = TextEditingController(text: '${d.bankName} ${d.accountType}');
    _balanceCtrl = TextEditingController(
      text: d.detectedBalance != null ? d.detectedBalance!.toStringAsFixed(2) : '',
    );
    _accountType = d.accountType;

    _selectedSenders = {
      for (final s in d.detectedSenderIds) s: true,
    };

    _selectedPatterns = {
      for (final p in d.detectedMessagePatterns) p: true,
    };
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final d = widget.discovery;
      final enteredBalance = double.tryParse(_balanceCtrl.text.replaceAll(',', ''));

      // 1. Create Account
      final newAccount = Account(
        id: '', // Will be assigned by AccountRepository
        name: _accountNameCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim(),
        accountNumber: '••••${d.accountLast4}',
        accountType: _accountType,
        balance: enteredBalance ?? 0.0,
        currentBalance: enteredBalance ?? 0.0,
        balanceSource: enteredBalance != null ? 'sms' : 'manual',
        balanceUpdatedAt: enteredBalance != null ? d.lastSeen : null,
        currency: d.detectedCurrency,
        accentColor: const Color(0xFF004B8D),
        isAutoDiscovered: false, // Explicitly confirmed by user
        smsTrackingEnabled: true, // Enabled upon confirmation!
        createdAt: DateTime.now(),
      );

      final accountRepo = AccountRepository();
      final accountId = await accountRepo.addAccount(newAccount);

      // 2. Create SMS Recognition Rules
      final ruleRepo = SmsRuleRepository();
      final activeSenders = _selectedSenders.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      final effectiveSenders = activeSenders.isNotEmpty
          ? activeSenders
          : [d.bankCode.toUpperCase()];

      // Debit Rule
      final debitRule = SmsRecognitionRule(
        id: '',
        accountId: accountId,
        ruleLabel: 'Debit',
        bankIdentifier: d.bankCode.isNotEmpty ? d.bankCode.toUpperCase() : null,
        senderPatterns: effectiveSenders,
        accountIdentifier: d.accountLast4,
        debitKeywords: const [
          'debited', 'debit', 'spent', 'paid', 'transferred', 'deducted', 'upi debit', 'dr'
        ],
        creditKeywords: const [],
        coversDebit: true,
        coversCredit: false,
        sampleSms: d.sampleMessages.isNotEmpty ? d.sampleMessages.first : null,
        isEnabled: true,
        createdAt: DateTime.now(),
      );
      await ruleRepo.addRule(debitRule);

      // Credit Rule
      final creditRule = SmsRecognitionRule(
        id: '',
        accountId: accountId,
        ruleLabel: 'Credit',
        bankIdentifier: d.bankCode.isNotEmpty ? d.bankCode.toUpperCase() : null,
        senderPatterns: effectiveSenders,
        accountIdentifier: d.accountLast4,
        debitKeywords: const [],
        creditKeywords: const [
          'credited', 'credit', 'received', 'deposited', 'refund', 'cashback', 'cr'
        ],
        coversDebit: false,
        coversCredit: true,
        sampleSms: d.sampleMessages.isNotEmpty ? d.sampleMessages.first : null,
        isEnabled: true,
        createdAt: DateTime.now(),
      );
      await ruleRepo.addRule(creditRule);

      // 3. Mark discovery initialized
      final discoveryRepo = AccountDiscoveryRepository();
      await discoveryRepo.markInitialized(d.discoveryId);

      // 4. Trigger SMS import for this account
      SmsService().refreshAccounts();
      SmsService().syncTransactions(targetAccountId: accountId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "${_accountNameCtrl.text.trim()}" initialized successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        widget.onCompleted?.call();
      }
    } catch (e) {
      debugPrint('[AccountInitializationSheet] error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set up account: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleDismiss() async {
    final repo = AccountDiscoveryRepository();
    await repo.dismissDiscovery(widget.discovery.discoveryId);
    if (mounted) {
      Navigator.pop(context);
      widget.onCompleted?.call();
    }
  }

  Future<void> _handleIgnore() async {
    final repo = AccountDiscoveryRepository();
    await repo.ignoreDiscovery(widget.discovery.discoveryId);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account ignored. It will not be suggested again.')),
      );
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = widget.discovery;

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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance, color: cs.primary, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bank Account Found', style: AppTypography.headlineMd),
                        Text(
                          '${d.messageCount} bank messages found',
                          style: AppTypography.labelMuted.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Bank Name
              TextFormField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter bank name' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Account Name
              TextFormField(
                controller: _accountNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter account name' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Account Type & Identifier Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _accountType,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Savings', child: Text('Savings')),
                        DropdownMenuItem(value: 'Current', child: Text('Current')),
                        DropdownMenuItem(value: 'Credit Card', child: Text('Credit Card')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _accountType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      initialValue: d.maskedAccountNumber,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Account Identifier',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Initial Balance
              TextFormField(
                controller: _balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Initial Balance',
                  border: const OutlineInputBorder(),
                  prefixText: '₹ ',
                  helperText: d.detectedBalance != null
                      ? '* Balance detected from recent bank SMS'
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // SMS Understanding Section
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How should MoneyTrack recognize this account?',
                      style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Recognize messages matching these criteria:',
                      style: AppTypography.labelMuted.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_selectedSenders.isNotEmpty) ...[
                      Text('Senders:', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                      ..._selectedSenders.keys.map((sender) {
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(sender),
                          value: _selectedSenders[sender] ?? true,
                          onChanged: (val) {
                            setState(() => _selectedSenders[sender] = val ?? false);
                          },
                        );
                      }),
                    ],
                    if (_selectedPatterns.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Patterns:', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                      ..._selectedPatterns.keys.map((pat) {
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(pat),
                          value: _selectedPatterns[pat] ?? true,
                          onChanged: (val) {
                            setState(() => _selectedPatterns[pat] = val ?? false);
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleConfirm,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Setting up...' : 'Save & Start Tracking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : _handleDismiss,
                    child: Text('Not Now', style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _handleIgnore,
                    child: Text('Ignore this account', style: TextStyle(color: cs.error)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
