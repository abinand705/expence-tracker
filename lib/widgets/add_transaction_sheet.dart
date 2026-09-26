import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

Future<bool?> showAddTransactionSheet({
  required BuildContext context,
  TransactionRepository? transactionRepository,
  AccountRepository? accountRepository,
  CategoryRepository? categoryRepository,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AddTransactionSheet(
      transactionRepository: transactionRepository,
      accountRepository: accountRepository,
      categoryRepository: categoryRepository,
    ),
  );
}

class AddTransactionSheet extends StatefulWidget {
  final TransactionRepository? transactionRepository;
  final AccountRepository? accountRepository;
  final CategoryRepository? categoryRepository;

  const AddTransactionSheet({
    super.key,
    this.transactionRepository,
    this.accountRepository,
    this.categoryRepository,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TransactionRepository _transactionRepo;
  late final AccountRepository _accountRepo;
  late final CategoryRepository _categoryRepo;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  model.TransactionType _selectedType = model.TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String? _selectedAccountId;

  List<Category> _categories = [];
  List<Account> _accounts = [];
  bool _isLoadingDeps = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _transactionRepo = widget.transactionRepository ?? TransactionRepository();
    _accountRepo = widget.accountRepository ?? AccountRepository();
    _categoryRepo = widget.categoryRepository ?? CategoryRepository();

    _loadDependencies();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    try {
      final cats = await _categoryRepo.getCategories();
      final accs = await _accountRepo.getAccounts();

      if (mounted) {
        setState(() {
          _categories = cats;
          _accounts = accs;

          // Default category if available
          if (_selectedCategory == null && cats.isNotEmpty) {
            _selectedCategory = cats.first.name;
          }

          // Default account to first available if present
          if (_selectedAccountId == null && accs.isNotEmpty) {
            _selectedAccountId = accs.first.id;
          }

          _isLoadingDeps = false;
        });
      }
    } catch (e) {
      debugPrint('[AddTransactionSheet] Error loading dependencies: $e');
      if (mounted) {
        setState(() {
          _isLoadingDeps = false;
        });
      }
    }
  }

  String _formatAccountLabel(Account account) {
    final digitsOnly = account.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final last4 = digitsOnly.length >= 4
        ? digitsOnly.substring(digitsOnly.length - 4)
        : (account.accountNumber.length >= 4
            ? account.accountNumber.substring(account.accountNumber.length - 4)
            : account.accountNumber);
    final masked = last4.isNotEmpty ? ' ••••$last4' : '';
    final name = account.displayName.isNotEmpty ? account.displayName : account.name;
    return '$name$masked';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          now.hour,
          now.minute,
          now.second,
        );
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_accounts.isEmpty || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isSaving = true;
    });

    try {
      final title = _titleController.text.trim();
      final amount = double.parse(_amountController.text.trim());

      final selectedAcc = _accounts.firstWhere(
        (a) => a.id == _selectedAccountId,
        orElse: () => _accounts.first,
      );

      final newId = const Uuid().v4();
      final now = DateTime.now();

      final transaction = model.Transaction(
        id: newId,
        amount: amount,
        type: _selectedType,
        merchant: title,
        customTitle: title,
        category: model.TransactionCategory.normalize(_selectedCategory),
        customCategory: _selectedCategory,
        accountId: selectedAcc.id,
        accountNumber: selectedAcc.accountNumber,
        subtitle: _formatAccountLabel(selectedAcc),
        transactionSource: 'manual',
        source: 'manual',
        isManual: true,
        date: _selectedDate,
        createdAt: now,
        updatedAt: now,
      );

      await _transactionRepo.addTransaction(transaction);

      // Update selected account balance to reflect the transaction
      try {
        final delta = _selectedType == model.TransactionType.expense ? -amount : amount;
        final updatedAcc = selectedAcc.copyWith(
          currentBalance: selectedAcc.currentBalance + delta,
          balanceUpdatedAt: DateTime.now(),
          balanceSource: 'manual',
        );
        await _accountRepo.updateAccount(updatedAcc);
      } catch (accErr) {
        debugPrint('[AddTransactionSheet] Note: account balance update skipped/failed: $accErr');
      }

      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Transaction added successfully.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AddTransactionSheet] Error adding manual transaction: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Unable to add transaction: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: _isLoadingDeps
            ? const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: cs.onSurfaceVariant.withAlpha(80),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Transaction',
                            style: AppTypography.headlineMd.copyWith(color: cs.onSurface),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Title Field
                      TextFormField(
                        key: const Key('manual_tx_title_field'),
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g. Groceries',
                          prefixIcon: Icon(Icons.title, size: 20),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Title cannot be empty.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Amount Field
                      TextFormField(
                        key: const Key('manual_tx_amount_field'),
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.currency_rupee, size: 20),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Amount cannot be empty.';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null) {
                            return 'Please enter a valid numeric amount.';
                          }
                          if (parsed <= 0) {
                            return 'Amount must be greater than 0.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Credit / Debit Selector
                      Text(
                        'Transaction Type',
                        style: AppTypography.labelMuted.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SegmentedButton<model.TransactionType>(
                        key: const Key('manual_tx_type_segmented_button'),
                        segments: const [
                          ButtonSegment<model.TransactionType>(
                            value: model.TransactionType.expense,
                            label: Text('Debit'),
                            icon: Icon(Icons.arrow_upward, color: AppColors.errorRed, size: 18),
                          ),
                          ButtonSegment<model.TransactionType>(
                            value: model.TransactionType.income,
                            label: Text('Credit'),
                            icon: Icon(Icons.arrow_downward, color: AppColors.successGreen, size: 18),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _selectedType = newSelection.first;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Date Field
                      InkWell(
                        key: const Key('manual_tx_date_picker'),
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today, size: 20),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(_selectedDate),
                            style: AppTypography.bodyMd.copyWith(color: cs.onSurface),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        key: const Key('manual_tx_category_dropdown'),
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined, size: 20),
                        ),
                        hint: const Text('Select category'),
                        items: _categories.isEmpty
                            ? [
                                const DropdownMenuItem<String>(
                                  value: 'Food',
                                  child: Text('Food'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Bills',
                                  child: Text('Bills'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Shopping',
                                  child: Text('Shopping'),
                                ),
                                const DropdownMenuItem<String>(
                                  value: 'Others',
                                  child: Text('Others'),
                                ),
                              ]
                            : _categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat.name,
                                  child: Text(cat.name),
                                );
                              }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please select a category.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Account Dropdown / Empty state
                      if (_accounts.isEmpty) ...[
                        Container(
                          key: const Key('manual_tx_no_accounts_banner'),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: cs.errorContainer.withAlpha(80),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: cs.error.withAlpha(80)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: cs.error),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'No accounts available.\nPlease create an account first.',
                                  style: AppTypography.bodyMd.copyWith(
                                    color: cs.onErrorContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          key: const Key('manual_tx_account_dropdown'),
                          initialValue: _selectedAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Account',
                            prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                          ),
                          hint: const Text('Select account'),
                          items: _accounts.map((acc) {
                            return DropdownMenuItem<String>(
                              value: acc.id,
                              child: Text(_formatAccountLabel(acc)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedAccountId = val;
                            });
                          },
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please select an account.';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),

                      // Submit Button
                      FilledButton(
                        key: const Key('submit_transaction_button'),
                        onPressed: (_isSaving || _accounts.isEmpty) ? null : _saveTransaction,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Transaction'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
