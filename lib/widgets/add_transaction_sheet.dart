import 'package:flutter/material.dart';
import '../models/transaction_item.dart';

class AddTransactionSheet extends StatefulWidget {
  final TransactionType initialType;
  final Function(TransactionItem) onAdd;

  const AddTransactionSheet({
    super.key,
    required this.initialType,
    required this.onAdd,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionType _selectedType;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedCategory = 'General';

  final List<String> _expenseCategories = [
    'General',
    'Food & Dining',
    'Shopping',
    'Groceries',
    'Transportation',
    'Bills & Utilities',
    'Entertainment',
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Investment',
    'Business',
    'Gifts',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedCategory = _selectedType == TransactionType.income
        ? _incomeCategories.first
        : _expenseCategories.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? (_selectedType == TransactionType.transfer
            ? 'Account Transfer'
            : _selectedCategory)
        : _titleController.text.trim();

    final item = TransactionItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      type: _selectedType,
      date: DateTime.now(),
      category: _selectedType == TransactionType.transfer
          ? 'Transfer'
          : _selectedCategory,
    );

    widget.onAdd(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final inputBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final actionButtonColor = isDark ? const Color(0xFF165945) : const Color(0xFF0A3026);

    final categories = _selectedType == TransactionType.income
        ? _incomeCategories
        : _expenseCategories;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedType == TransactionType.expense
                    ? 'Log Expense'
                    : _selectedType == TransactionType.income
                        ? 'Log Income'
                        : 'New Transfer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Type selector segmented control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildTypeButton(TransactionType.expense, 'Expense', const Color(0xFFDC2626), isDark),
                _buildTypeButton(TransactionType.income, 'Income', const Color(0xFF16A34A), isDark),
                _buildTypeButton(TransactionType.transfer, 'Transfer', const Color(0xFF2563EB), isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Amount input
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              hintText: '0.00',
              hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              filled: true,
              fillColor: inputBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Title / note
          TextField(
            controller: _titleController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Note / Description (Optional)',
              hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              filled: true,
              fillColor: inputBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_selectedType != TransactionType.transfer) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: categories.contains(_selectedCategory) ? _selectedCategory : categories.first,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: textColor, fontSize: 15),
              iconEnabledColor: textColor,
              items: categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: TextStyle(color: textColor)),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                filled: true,
                fillColor: inputBgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: actionButtonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Save Transaction',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(TransactionType type, String label, Color activeColor, bool isDark) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            if (type == TransactionType.income) {
              _selectedCategory = _incomeCategories.first;
            } else if (type == TransactionType.expense) {
              _selectedCategory = _expenseCategories.first;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? activeColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
