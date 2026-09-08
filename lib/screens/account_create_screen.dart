import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../repositories/account_repository.dart';
import '../repositories/sms_rule_repository.dart';
import '../services/sms_rule_builder.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Multi-step account creation wizard.
///
/// Step 1: Account Details
/// Step 2: SMS Recognition (paste sample SMS)
/// Step 3: Review detected fields
/// Step 4: Confirm & Save
/// Step 5: Done
///
/// IMPORTANT: Accounts start with smsTrackingEnabled = false.
/// SMS tracking is only enabled after the user confirms at least one rule.
class AccountCreateScreen extends StatefulWidget {
  /// When non-null, the screen operates in edit mode.
  final Account? accountToEdit;

  const AccountCreateScreen({super.key, this.accountToEdit});

  @override
  State<AccountCreateScreen> createState() => _AccountCreateScreenState();
}

class _AccountCreateScreenState extends State<AccountCreateScreen> {
  final _accountRepo = AccountRepository();
  final _ruleRepo = SmsRuleRepository();
  final _pageController = PageController();

  int _currentStep = 0;
  bool _isSaving = false;

  // ── Step 1 Controllers ────────────────────────────────────────────────────
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  String _accountType = 'Savings';
  Color _accentColor = const Color(0xFF3D7A6A);

  // ── Step 2 Controllers ────────────────────────────────────────────────────
  final _senderCtrl = TextEditingController();
  final _sampleSmsCtrl = TextEditingController();
  String _ruleLabelCtrl = 'Debit';
  SmsRuleSuggestion? _suggestion;
  bool _isDetecting = false;

  // ── Step 3 / Confirmed Rule ───────────────────────────────────────────────
  TransactionType _confirmedType = TransactionType.expense;
  String? _savedAccountId;

  // ── Step 4 Scanning State ──────────────────────────────────────────────────
  bool _isScanningSms = false;
  int _importedTxCount = 0;
  double? _syncedBalance;
  String? _scanMessage;

  // ── Known banks for suggestions ───────────────────────────────────────────
  static const List<String> _knownBanks = [
    'Kerala Grameena Bank',
    'State Bank of India',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Bank of Baroda',
    'Punjab National Bank',
    'Canara Bank',
    'Union Bank of India',
    'Kotak Mahindra Bank',
  ];

  bool get _isEditMode => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final a = widget.accountToEdit!;
      _bankNameCtrl.text = a.bankName;
      _accountNumberCtrl.text = a.accountNumber;
      _nicknameCtrl.text = a.nickname ?? '';
      _balanceCtrl.text = a.currentBalance != 0.0 ? a.currentBalance.toString() : '';
      _accountType = a.accountType;
      _accentColor = a.accentColor;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _nicknameCtrl.dispose();
    _balanceCtrl.dispose();
    _senderCtrl.dispose();
    _sampleSmsCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Step 1: Save Account Details ─────────────────────────────────────────
  Future<void> _saveAccountDetails() async {
    if (_bankNameCtrl.text.trim().isEmpty) {
      _showError('Bank name is required.');
      return;
    }
    if (_accountNumberCtrl.text.trim().isEmpty) {
      _showError('Account number / suffix is required.');
      return;
    }
    final digits = _accountNumberCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 3) {
      _showError('Account number must have at least 3 digits.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final bankName = _bankNameCtrl.text.trim();
      final accountName = _nicknameCtrl.text.trim().isNotEmpty
          ? _nicknameCtrl.text.trim()
          : '$bankName Account';

      final account = Account(
        id: _isEditMode ? widget.accountToEdit!.id : '',
        name: accountName,
        bankName: bankName,
        accountNumber: _accountNumberCtrl.text.trim(),
        accountType: _accountType,
        nickname: _nicknameCtrl.text.trim().isEmpty ? null : _nicknameCtrl.text.trim(),
        currentBalance: double.tryParse(_balanceCtrl.text.trim()) ?? 0.0,
        balance: double.tryParse(_balanceCtrl.text.trim()) ?? 0.0,
        balanceSource: 'manual',
        accentColor: _accentColor,
        isAutoDiscovered: false,
        smsTrackingEnabled: false, // OFF until user confirms SMS rule
        createdAt: _isEditMode ? widget.accountToEdit!.createdAt : DateTime.now(),
      );

      if (_isEditMode) {
        await _accountRepo.updateAccount(account);
        _savedAccountId = account.id;
      } else {
        _savedAccountId = await _accountRepo.addAccount(account);
      }

      // Move to SMS setup step
      _goToStep(1);
    } catch (e) {
      _showError('Failed to save account: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Step 2: Detect SMS Fields ─────────────────────────────────────────────
  void _detectSmsFields() {
    if (_sampleSmsCtrl.text.trim().isEmpty) {
      _showError('Please paste a sample SMS message.');
      return;
    }

    setState(() {
      _isDetecting = true;
      _suggestion = null;
    });

    // Run synchronously (ExpenseParser is CPU-bound, not async)
    final suggestion = SmsRuleBuilder.parseSampleSms(
      smsBody: _sampleSmsCtrl.text.trim(),
      sender: _senderCtrl.text.trim(),
      knownAccountIdentifier: _accountNumberCtrl.text.trim(),
    );

    setState(() {
      _suggestion = suggestion;
      _isDetecting = false;
      if (suggestion.transactionType != null) {
        _confirmedType = suggestion.transactionType!;
      }
    });

    if (suggestion.couldParse) {
      _goToStep(2); // Review step
    } else {
      // Show warning inline but still allow manual review
      _showSnack(suggestion.parseWarning ?? 'Could not fully parse the SMS. You can still review and adjust.');
      _goToStep(2);
    }
  }

  // ── Step 3: Confirm and Save Rule ─────────────────────────────────────────
  Future<void> _saveRuleAndEnable() async {
    if (_savedAccountId == null) {
      _showError('Account was not saved. Please start over.');
      return;
    }
    if (_senderCtrl.text.trim().isEmpty) {
      _showError('Please enter a sender pattern (e.g. VK-KGBANK).');
      return;
    }

    final accountSuffix = _accountNumberCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (accountSuffix.length < 3) {
      _showError('Invalid account number. Need at least 3 digits.');
      return;
    }
    final accountIdentifier = accountSuffix.substring(accountSuffix.length - (accountSuffix.length > 3 ? (accountSuffix.length > 6 ? 6 : accountSuffix.length) : 3));

    setState(() => _isSaving = true);
    try {
      // Build structural rule (NOT hardcoded values)
      final rule = SmsRuleBuilder.buildRule(
        accountId: _savedAccountId!,
        ruleLabel: _ruleLabelCtrl,
        senderPatterns: [_senderCtrl.text.trim()],
        accountIdentifier: accountIdentifier,
        suggestion: _suggestion ?? const SmsRuleSuggestion(couldParse: false),
        transactionType: _confirmedType,
        sampleSmsForReference: _sampleSmsCtrl.text.trim(),
      );

      final validationError = SmsRuleBuilder.validateRule(rule);
      if (validationError != null) {
        _showError(validationError);
        return;
      }

      await _ruleRepo.addRule(rule);

      // Enable SMS tracking now that user has confirmed a rule
      final savedAccount = await _accountRepo.getAccountById(_savedAccountId!);
      if (savedAccount != null) {
        await _accountRepo.updateAccount(savedAccount.copyWith(smsTrackingEnabled: true));
      }

      _goToStep(3); // Done
      _scanAndSyncNewAccount(_savedAccountId!);
    } catch (e) {
      _showError('Failed to save rule: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _scanAndSyncNewAccount(String accountId) async {
    if (!mounted) return;
    setState(() {
      _isScanningSms = true;
      _scanMessage = 'Scanning SMS messages for ${_bankNameCtrl.text.trim()}...';
    });

    try {
      final summary = await SmsService().syncTransactions(targetAccountId: accountId);
      final refreshedAccount = await _accountRepo.getAccountById(accountId);

      if (mounted) {
        setState(() {
          _isScanningSms = false;
          _importedTxCount = summary.imported;
          _syncedBalance = refreshedAccount?.currentBalance;
          _scanMessage = summary.imported > 0
              ? 'Found ${summary.imported} transaction${summary.imported == 1 ? '' : 's'}!'
              : 'Scan complete. No past SMS transactions found.';
        });
      }
    } catch (e) {
      debugPrint('[AccountCreateScreen] SMS scan error: $e');
      if (mounted) {
        setState(() {
          _isScanningSms = false;
          _scanMessage = 'Scan completed.';
        });
      }
    }
  }

  Future<void> _skipSmsSetup() async {
    // Account remains with smsTrackingEnabled = false
    _goToStep(3);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Account' : 'Add Account',
            style: AppTypography.headlineMd),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _goToStep(_currentStep - 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(cs),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1AccountDetails(cs),
                _buildStep2SmsSetup(cs),
                _buildStep3Review(cs),
                _buildStep4Done(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    const steps = ['Details', 'SMS Setup', 'Review', 'Done'];
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.successGreen
                              : isActive
                                  ? cs.primary
                                  : cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: AppTypography.labelMuted.copyWith(
                          fontSize: 10,
                          color: isActive ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      color: i < _currentStep ? AppColors.successGreen : cs.outlineVariant,
                      margin: const EdgeInsets.only(bottom: 20),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 1: Account Details
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStep1AccountDetails(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Details', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'MoneyTrack will not automatically create bank accounts from SMS. '
            'Create your account here to enable SMS transaction tracking.',
            style: AppTypography.bodyMd.copyWith(
                color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Bank Name
          _buildFieldLabel('Bank Name *'),
          TextField(
            controller: _bankNameCtrl,
            decoration: _inputDecoration('e.g. Kerala Grameena Bank'),
            onChanged: (val) {
              if (_senderCtrl.text.isEmpty) {
                final abbr = _buildSenderSuggestion(val);
                if (abbr != null) _senderCtrl.text = abbr;
              }
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _knownBanks.map((bank) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(bank, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _bankNameCtrl.text = bank;
                      final abbr = _buildSenderSuggestion(bank);
                      if (abbr != null) _senderCtrl.text = abbr;
                      setState(() {});
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Account Number
          _buildFieldLabel('Account Number / Suffix *'),
          TextField(
            controller: _accountNumberCtrl,
            decoration: _inputDecoration('Last 4–6 digits (e.g. 0544)'),
            keyboardType: TextInputType.number,
            maxLength: 20,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Account Type
          _buildFieldLabel('Account Type *'),
          DropdownButtonFormField<String>(
            initialValue: ['Savings', 'Current', 'Credit Card', 'Loan']
                    .contains(_accountType)
                ? _accountType
                : 'Savings',
            decoration: _inputDecoration(null),
            items: ['Savings', 'Current', 'Credit Card', 'Loan']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _accountType = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Nickname
          _buildFieldLabel('Nickname (optional)'),
          TextField(
            controller: _nicknameCtrl,
            decoration: _inputDecoration('e.g. Personal Savings'),
          ),
          const SizedBox(height: AppSpacing.md),

          // Initial Balance
          _buildFieldLabel('Initial Balance (optional)'),
          TextField(
            controller: _balanceCtrl,
            decoration: _inputDecoration('e.g. 5000 or -1500').copyWith(
              prefixText: '₹ ',
              suffixIcon: IconButton(
                tooltip: 'Toggle +/- sign',
                icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _balanceCtrl.text.trim().startsWith('-')
                        ? AppColors.errorRed.withValues(alpha: 0.15)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _balanceCtrl.text.trim().startsWith('-')
                          ? AppColors.errorRed
                          : cs.outlineVariant.withAlpha(100),
                    ),
                  ),
                  child: Text(
                    _balanceCtrl.text.trim().startsWith('-') ? '− NEG' : '+ POS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _balanceCtrl.text.trim().startsWith('-')
                          ? AppColors.errorRed
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    final text = _balanceCtrl.text.trim();
                    if (text.isEmpty) {
                      _balanceCtrl.text = '-';
                    } else if (text.startsWith('-')) {
                      _balanceCtrl.text = text.substring(1);
                    } else {
                      _balanceCtrl.text = '-$text';
                    }
                  });
                },
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),

          ElevatedButton(
            onPressed: _isSaving ? null : _saveAccountDetails,
            style: _primaryButtonStyle(cs),
            child: _isSaving
                ? CircularProgressIndicator(color: cs.onPrimary)
                : const Text('Continue →'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 2: SMS Setup
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStep2SmsSetup(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SMS Recognition', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Teach MoneyTrack how your bank sends transaction messages. '
            'MoneyTrack uses these rules to identify transactions — SMS that '
            'do not match will not create transactions.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Info box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: cs.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your sample SMS is used to detect patterns only. '
                    'The amount, balance, and reference shown are for preview '
                    'only — future SMS with different amounts will still work.',
                    style: AppTypography.bodyMd.copyWith(
                        color: cs.onSurface, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Rule Label
          _buildFieldLabel('Rule Type'),
          DropdownButtonFormField<String>(
            initialValue: _ruleLabelCtrl,
            decoration: _inputDecoration(null),
            items: ['Debit', 'Credit', 'UPI Debit', 'UPI Credit', 'Other']
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _ruleLabelCtrl = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Sender
          _buildFieldLabel('SMS Sender Pattern *'),
          TextField(
            controller: _senderCtrl,
            decoration:
                _inputDecoration('e.g. VK-KGBANK, AD-KGBANK, KGBANK'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The sender ID shown on your phone when you receive bank SMS.',
            style: AppTypography.labelMuted.copyWith(fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.md),

          // Sample SMS
          _buildFieldLabel('Paste a Sample Bank SMS *'),
          TextField(
            controller: _sampleSmsCtrl,
            decoration: _inputDecoration(
              'e.g. After debit of Rs 25, your A/c XXXXX544 Bal stands Rs 286.5...',
            ).copyWith(alignLabelWithHint: true),
            maxLines: 5,
            minLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDetecting ? null : _detectSmsFields,
                  icon: _isDetecting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_isDetecting ? 'Detecting…' : 'Detect Fields'),
                  style: _primaryButtonStyle(cs),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: _skipSmsSetup,
            child: Text(
              'Skip SMS setup for now',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 3: Review Detected Fields
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStep3Review(ColorScheme cs) {
    final s = _suggestion;
    if (s == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.error, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('No detection data available.', style: AppTypography.bodyLg),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => _goToStep(1),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Detected Fields', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'MoneyTrack detected the following from your sample SMS. '
            'These are PATTERNS — future SMS with different amounts will '
            'still be parsed correctly.',
            style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),

          if (s.parseWarning != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: cs.error, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(s.parseWarning!,
                        style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Transaction Type (editable)
          _buildFieldLabel('Transaction Type'),
          DropdownButtonFormField<TransactionType>(
            initialValue: _confirmedType,
            decoration: _inputDecoration(null),
            items: [
              DropdownMenuItem(
                  value: TransactionType.expense,
                  child: const Text('Debit (Expense)')),
              DropdownMenuItem(
                  value: TransactionType.income,
                  child: const Text('Credit (Income)')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _confirmedType = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Detected fields (read-only, with preview disclaimer)
          _buildDetectedFieldCard(cs, 'Amount (preview)', s.detectedAmount != null
              ? '₹${s.detectedAmount!.toStringAsFixed(2)}'
              : 'Not detected',
              note: 'Future SMS with any amount will be parsed'),
          _buildDetectedFieldCard(cs, 'Account Identifier', 
              s.detectedAccountSuffix != null ? '•••${s.detectedAccountSuffix}' : 'Not detected'),
          _buildDetectedFieldCard(cs, 'Balance (preview)', s.detectedBalance != null
              ? (s.detectedBalance! < 0
                  ? '-₹${(-s.detectedBalance!).toStringAsFixed(2)}'
                  : '₹${s.detectedBalance!.toStringAsFixed(2)}')
              : 'Not detected',
              note: 'Actual balance will be read from each SMS'),
          _buildDetectedFieldCard(cs, 'Transaction Date (preview)', s.detectedDateTime?.toString() ?? 'Not detected',
              note: 'Actual date will be read from each SMS'),
          _buildDetectedFieldCard(cs, 'Reference ID (preview)', s.detectedReferenceId ?? 'Not detected',
              note: 'Actual reference will be read from each SMS'),
          _buildDetectedFieldCard(cs, 'Bank Name', s.detectedBankName ?? 'Not detected'),
          const SizedBox(height: AppSpacing.md),

          // Sender confirmation
          _buildDetectedFieldCard(cs, 'Sender Pattern', _senderCtrl.text.isNotEmpty
              ? _senderCtrl.text
              : 'Not configured'),

          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'Is this correct? If yes, save these rules. '
              'You can always edit or add more rules later.',
              style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          ElevatedButton(
            onPressed: _isSaving ? null : _saveRuleAndEnable,
            style: _primaryButtonStyle(cs),
            child: _isSaving
                ? CircularProgressIndicator(color: cs.onPrimary)
                : const Text('Yes, Save Rules'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => _goToStep(1),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base)),
            ),
            child: const Text('Re-paste SMS'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _skipSmsSetup,
            child: Text('Skip — set up later',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Step 4: Done
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStep4Done(ColorScheme cs) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
    final lastDigits = _accountNumberCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final suffix = lastDigits.length > 3
        ? lastDigits.substring(lastDigits.length - 3)
        : lastDigits;

    if (_isScanningSms) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Checking Bank Transactions...',
                style: AppTypography.headlineMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Scanning SMS messages for ${_bankNameCtrl.text.trim()} to import transactions and update your balance.',
                style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              LinearProgressIndicator(
                color: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ],
          ),
        ),
      );
    }

    final hasRule = _suggestion != null && _suggestion!.couldParse != false;
    final displayBalance = _syncedBalance ??
        double.tryParse(_balanceCtrl.text.trim()) ??
        0.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: hasRule
                    ? AppColors.successGreen.withValues(alpha: 0.15)
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasRule ? Icons.check_circle_outline : Icons.account_balance,
                color: hasRule ? AppColors.successGreen : cs.onSurfaceVariant,
                size: 44,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              hasRule
                  ? '${_bankNameCtrl.text.trim()} is Ready!'
                  : 'Account Created',
              style: AppTypography.headlineMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasRule
                  ? 'Your bank account has been added and linked with SMS tracking.'
                  : 'SMS tracking is currently disabled. Go to My Accounts → SMS Recognition to configure it.',
              style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (hasRule) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'SMS Tracking Active',
                          style: AppTypography.labelMuted.copyWith(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (suffix.isNotEmpty)
                          Text(
                            '••••$suffix',
                            style: AppTypography.labelMuted,
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Balance',
                                style: AppTypography.labelMuted),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormatter.format(displayBalance),
                              style: AppTypography.headlineMd.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (_importedTxCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.receipt_long,
                                    size: 14, color: cs.onPrimaryContainer),
                                const SizedBox(width: 4),
                                Text(
                                  '$_importedTxCount imported',
                                  style: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (_scanMessage != null && _scanMessage!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _scanMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: _primaryButtonStyle(cs),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: AppTypography.labelMuted.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      )),
    );
  }

  Widget _buildDetectedFieldCard(ColorScheme cs, String label, String value, {String? note}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.labelMuted.copyWith(
                        fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600, color: cs.onSurface)),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note,
                      style: AppTypography.labelMuted.copyWith(
                          fontSize: 10, color: cs.primary,
                          fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      border: const OutlineInputBorder(),
      counterText: '',
    );
  }

  ButtonStyle _primaryButtonStyle(ColorScheme cs) {
    return ElevatedButton.styleFrom(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base)),
    );
  }

  String? _buildSenderSuggestion(String bankName) {
    final lower = bankName.toLowerCase();
    if (lower.contains('kerala grameena') || lower.contains('kgbank')) return 'VK-KGBANK';
    if (lower.contains('sbi') || lower.contains('state bank')) return 'SBIINB';
    if (lower.contains('hdfc')) return 'HDFCBK';
    if (lower.contains('icici')) return 'ICICIB';
    if (lower.contains('axis')) return 'AXISBK';
    if (lower.contains('baroda') || lower.contains('bob')) return 'BOBSMS';
    return null;
  }
}
