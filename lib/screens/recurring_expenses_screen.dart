import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_expense.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../repositories/recurring_expense_repository.dart';
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/category_icon.dart';

class RecurringExpensesScreen extends StatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  State<RecurringExpensesScreen> createState() => _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> {
  final _repo = RecurringExpenseRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Recurring Expenses', style: AppTypography.headlineMd),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showExpenseModal(context),
          )
        ],
      ),
      body: StreamBuilder<List<RecurringExpense>>(
        stream: _repo.watchRecurringExpenses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading expenses'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data!;
          if (expenses.isEmpty) {
            return Center(
              child: Text(
                'No recurring expenses set.',
                style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface.withValues(alpha: 0.6)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final currencyFormatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
              final dateFormatter = DateFormat('MMM d, yyyy');

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                color: AppColors.surfaceBright,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  leading: CategoryIcon(category: expense.category, size: 48),
                  title: Text(
                    expense.title,
                    style: AppTypography.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: expense.isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${expense.frequency.toUpperCase()} • Next: ${dateFormatter.format(expense.nextOccurrence)}',
                        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface.withValues(alpha: 0.6)),
                      ),
                      if (expense.endDate != null)
                        Text(
                          'Ends: ${dateFormatter.format(expense.endDate!)}',
                          style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currencyFormatter.format(expense.amount),
                        style: AppTypography.headlineMd.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: expense.isActive,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          _repo.updateRecurringExpense(
                            RecurringExpense(
                              id: expense.id,
                              title: expense.title,
                              amount: expense.amount,
                              category: expense.category,
                              accountId: expense.accountId,
                              frequency: expense.frequency,
                              startDate: expense.startDate,
                              nextOccurrence: expense.nextOccurrence,
                              endDate: expense.endDate,
                              isActive: val,
                              createdAt: expense.createdAt,
                              updatedAt: DateTime.now(),
                            )
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () => _showExpenseModal(context, expense: expense),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showExpenseModal(BuildContext context, {RecurringExpense? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecurringExpenseForm(expense: expense, repo: _repo),
    );
  }
}

class _RecurringExpenseForm extends StatefulWidget {
  final RecurringExpense? expense;
  final RecurringExpenseRepository repo;

  const _RecurringExpenseForm({this.expense, required this.repo});

  @override
  State<_RecurringExpenseForm> createState() => _RecurringExpenseFormState();
}

class _RecurringExpenseFormState extends State<_RecurringExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  
  String? _selectedCategory;
  String? _selectedAccountId;
  String _frequency = 'monthly';
  DateTime _nextOccurrence = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;

  List<Category> _categories = [];
  List<Account> _accounts = [];
  bool _isLoadingDeps = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense?.title ?? '');
    _amountController = TextEditingController(
      text: widget.expense != null ? widget.expense!.amount.toStringAsFixed(0) : '',
    );
    _selectedCategory = widget.expense?.category;
    _selectedAccountId = widget.expense?.accountId;
    _frequency = widget.expense?.frequency ?? 'monthly';
    _nextOccurrence = widget.expense?.nextOccurrence ?? DateTime.now();
    _endDate = widget.expense?.endDate;
    _isActive = widget.expense?.isActive ?? true;

    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    final catRepo = CategoryRepository();
    final accRepo = AccountRepository();
    
    final cats = await catRepo.getCategories();
    final accs = await accRepo.getAccounts();
    
    if (mounted) {
      setState(() {
        _categories = cats;
        _accounts = accs;
        
        _selectedCategory ??= cats.isNotEmpty ? cats.first.name : 'General';
        
        if (_selectedAccountId == null && accs.isNotEmpty) {
          _selectedAccountId = accs.first.id;
        }
        
        _isLoadingDeps = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: _isLoadingDeps 
        ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
        : Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.expense == null ? 'New Recurring Expense' : 'Edit Recurring Expense',
                    style: AppTypography.headlineMd,
                  ),
                  if (widget.expense != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      onPressed: () async {
                        await widget.repo.deleteRecurringExpense(widget.expense!.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title / Merchant'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final amount = double.tryParse(val);
                  if (amount == null || amount <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  if (_categories.isEmpty && _selectedCategory != null)
                    DropdownMenuItem(value: _selectedCategory, child: Text(_selectedCategory!)),
                  ..._categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                ],
                onChanged: (val) => setState(() => _selectedCategory = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Account Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedAccountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  if (_accounts.isEmpty && _selectedAccountId != null)
                    DropdownMenuItem(value: _selectedAccountId, child: const Text('Unknown Account')),
                  ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (val) => setState(() => _selectedAccountId = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Frequency
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                ],
                onChanged: (val) => setState(() => _frequency = val!),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Next Occurrence Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next Occurrence'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(_nextOccurrence)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _nextOccurrence,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _nextOccurrence = date);
                  }
                },
              ),
              
              // End Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date (Optional)'),
                subtitle: Text(_endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : 'None'),
                trailing: _endDate != null 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _endDate = null))
                    : const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? _nextOccurrence.add(const Duration(days: 30)),
                    firstDate: _nextOccurrence,
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),

              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: const Text('Save Recurring Expense'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      if (_endDate != null && _endDate!.isBefore(_nextOccurrence)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date cannot precede next occurrence')));
        return;
      }
      
      final expense = RecurringExpense(
        id: widget.expense?.id ?? '',
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text),
        category: _selectedCategory!,
        accountId: _selectedAccountId!,
        frequency: _frequency,
        startDate: widget.expense?.startDate ?? DateTime.now(),
        nextOccurrence: _nextOccurrence,
        endDate: _endDate,
        isActive: _isActive,
        createdAt: widget.expense?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.expense == null) {
        await widget.repo.addRecurringExpense(expense);
      } else {
        await widget.repo.updateRecurringExpense(expense);
      }

      if (mounted) Navigator.pop(context);
    }
  }
}
