import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/auth_controller.dart';
import '../models/category_item.dart';
import '../models/transaction_item.dart';
import '../services/firestore_service.dart';

class AddTransactionSheet extends StatefulWidget {
  final TransactionType initialType;
  final Function(TransactionItem) onAdd;
  final FirestoreService? firestoreService;
  final AuthController? authController;

  const AddTransactionSheet({
    super.key,
    required this.initialType,
    required this.onAdd,
    this.firestoreService,
    this.authController,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionType _selectedType;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedCategory = '';

  late final FirestoreService _firestoreService;
  StreamSubscription<List<CategoryItem>>? _categoriesSub;

  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _firestoreService = widget.firestoreService ?? FirestoreService();

    // Default predefined categories while streaming
    _expenseCategories = [
      'General',
      ...CategoryItem.predefinedCategories
          .where((c) => c.subcategory == 'expense')
          .map((c) => c.name)
          .where((n) => n != 'General'),
    ];

    _incomeCategories = CategoryItem.predefinedCategories
        .where((c) => c.subcategory == 'income')
        .map((c) => c.name)
        .toList();

    _updateDefaultCategoryForType();
    _subscribeToCategories();
  }

  void _updateDefaultCategoryForType() {
    if (_selectedType == TransactionType.income) {
      if (_incomeCategories.isNotEmpty) {
        _selectedCategory = _incomeCategories.first;
      }
    } else if (_selectedType == TransactionType.expense) {
      _selectedCategory = _expenseCategories.contains('General')
          ? 'General'
          : (_expenseCategories.isNotEmpty ? _expenseCategories.first : 'General');
    } else {
      _selectedCategory = 'Transfer';
    }
  }

  void _subscribeToCategories() {
    _categoriesSub?.cancel();
    final userId = widget.authController?.userId ?? 'guest_user';
    _categoriesSub = _firestoreService.streamCategories(userId).listen((items) {
      if (!mounted) return;
      final expenses = [
        'General',
        ...items
            .where((c) => c.subcategory == 'expense')
            .map((c) => c.name)
            .where((n) => n != 'General')
            .toSet(),
      ];

      final incomes = items
          .where((c) => c.subcategory == 'income')
          .map((c) => c.name)
          .toSet()
          .toList();

      setState(() {
        if (expenses.isNotEmpty) _expenseCategories = expenses;
        if (incomes.isNotEmpty) _incomeCategories = incomes;

        final currentList = _selectedType == TransactionType.income
            ? _incomeCategories
            : _expenseCategories;

        if (!currentList.contains(_selectedCategory) && currentList.isNotEmpty) {
          _selectedCategory = currentList.first;
        }
      });
    });
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amountText = _amountController.text.trim();
    final amountInt = int.tryParse(amountText) ??
        (double.tryParse(amountText)?.round());

    if (amountInt == null || amountInt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final enteredNote = _noteController.text.trim();
    final note = enteredNote.isNotEmpty
        ? enteredNote
        : (_selectedType == TransactionType.transfer
            ? 'Transfer'
            : _selectedCategory);

    final now = DateTime.now();
    final category = _selectedType == TransactionType.transfer
        ? 'Transfer'
        : _selectedCategory;

    final item = TransactionItem(
      id: 'tx_${now.millisecondsSinceEpoch}',
      title: note,
      note: note,
      amount: amountInt.toDouble(),
      type: _selectedType,
      date: now,
      category: category,
      userId: widget.authController?.userId,
    );

    widget.onAdd(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final inputBgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final actionButtonColor =
        isDark ? const Color(0xFF165945) : const Color(0xFF0A3026);

    final currentCategories = _selectedType == TransactionType.income
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
                icon: Icon(Icons.close,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
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
                _buildTypeButton(TransactionType.expense, 'Expense',
                    const Color(0xFFDC2626), isDark),
                _buildTypeButton(TransactionType.income, 'Income',
                    const Color(0xFF16A34A), isDark),
                _buildTypeButton(TransactionType.transfer, 'Transfer',
                    const Color(0xFF2563EB), isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Amount input (Integer only)
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              hintText: '0.00',
              hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8)),
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
                  color: isDark
                      ? const Color(0xFF34D399)
                      : const Color(0xFF0A3026),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Note input
          TextField(
            controller: _noteController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Note',
              labelStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
              hintText: _selectedType == TransactionType.transfer
                  ? 'e.g. Sent to Savings'
                  : 'e.g. Grocery shopping',
              hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8)),
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
                  color: isDark
                      ? const Color(0xFF34D399)
                      : const Color(0xFF0A3026),
                  width: 1.5,
                ),
              ),
            ),
          ),
          // Category dropdown - shown only for expense and income
          if (_selectedType != TransactionType.transfer) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: currentCategories.contains(_selectedCategory)
                  ? _selectedCategory
                  : (currentCategories.isNotEmpty
                      ? currentCategories.first
                      : null),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: textColor, fontSize: 15),
              iconEnabledColor: textColor,
              items: currentCategories
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
                labelText: _selectedType == TransactionType.income
                    ? 'Income Category'
                    : 'Expense Category',
                labelStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
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

  Widget _buildTypeButton(
      TransactionType type, String label, Color activeColor, bool isDark) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _updateDefaultCategoryForType();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                color: isSelected
                    ? activeColor
                    : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
