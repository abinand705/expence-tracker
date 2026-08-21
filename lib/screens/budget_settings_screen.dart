import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/category_icon.dart';
import 'package:intl/intl.dart';

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final BudgetRepository _budgetRepo = BudgetRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  
  List<Budget> _budgets = [];
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _budgetRepo.getBudgets(),
        _categoryRepo.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _budgets = results[0] as List<Budget>;
          _categories = results[1] as List<Category>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBudgetModal({Budget? existingBudget}) {
    final amountController = TextEditingController(
      text: existingBudget != null ? existingBudget.amount.toStringAsFixed(0) : '',
    );
    String selectedCategory = existingBudget?.category ?? 'Total';
    
    // Determine available categories. Total is only available if we are editing the existing Total, or if no Total exists yet.
    final bool hasTotal = _budgets.any((b) => b.category == 'Total');
    final List<String> availableCategories = [];
    if (!hasTotal || selectedCategory == 'Total') {
      availableCategories.add('Total');
    }
    availableCategories.addAll(_categories.map((c) => c.name));

    if (!availableCategories.contains(selectedCategory) && selectedCategory != 'Total') {
       availableCategories.add(selectedCategory); // Handle deleted category resilience
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existingBudget == null ? 'Add Budget' : 'Edit Budget',
                    style: AppTypography.headlineMd,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: availableCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat == 'Total' ? 'Overall (Total)' : cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monthly Target Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid positive amount.')),
                        );
                        return;
                      }
                      
                      final now = DateTime.now();
                      if (existingBudget == null) {
                        final newBudget = Budget(
                          id: '', // Will be generated by repository
                          category: selectedCategory,
                          amount: amount,
                          period: 'monthly',
                          createdAt: now,
                          updatedAt: now,
                        );
                        await _budgetRepo.addBudget(newBudget);
                      } else {
                        final updatedBudget = Budget(
                          id: existingBudget.id,
                          category: selectedCategory,
                          amount: amount,
                          period: existingBudget.period,
                          createdAt: existingBudget.createdAt,
                          updatedAt: now,
                        );
                        await _budgetRepo.updateBudget(updatedBudget);
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Budget'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Budget'),
        content: Text('Are you sure you want to delete the ${budget.category} budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _budgetRepo.deleteBudget(budget.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      
      appBar: AppBar(
        title: Text('Budgets', style: AppTypography.headlineMd),
        
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryContainer),
            onPressed: () => _showBudgetModal(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
              ? Center(
                  child: Text('No budgets defined yet.', style: AppTypography.bodyLg),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.containerMargin),
                  itemCount: _budgets.length,
                  itemBuilder: (context, index) {
                    final budget = _budgets[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadows.level1,
                      ),
                      child: ListTile(
                        leading: budget.category == 'Total'
                            ? const CircleAvatar(backgroundColor: AppColors.primaryContainer, child: Icon(Icons.account_balance, color: Colors.white))
                            : CategoryIcon(category: budget.category, size: 40),
                        title: Text(budget.category == 'Total' ? 'Overall Budget' : budget.category, style: AppTypography.bodyLg),
                        subtitle: Text('${formatter.format(budget.amount)} / ${budget.period}', style: AppTypography.bodyMd),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              onPressed: () => _showBudgetModal(existingBudget: budget),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.errorRed),
                              onPressed: () => _deleteBudget(budget),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
