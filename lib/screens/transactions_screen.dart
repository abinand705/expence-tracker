import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_item.dart';

class TransactionsScreen extends StatefulWidget {
  final List<TransactionItem> transactions;
  final VoidCallback onAddTransaction;
  final Function(String id)? onDeleteTransaction;
  final VoidCallback? onOpenDrawer;

  const TransactionsScreen({
    super.key,
    required this.transactions,
    required this.onAddTransaction,
    this.onDeleteTransaction,
    this.onOpenDrawer,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All Types';
  DateTime? _selectedDate;

  final List<String> _filters = ['All Types', 'Expenses', 'Income', 'Transfers'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionItem> get _filteredTransactions {
    return widget.transactions.where((item) {
      // Type filter
      if (_selectedFilter == 'Expenses' && item.type != TransactionType.expense) {
        return false;
      }
      if (_selectedFilter == 'Income' && item.type != TransactionType.income) {
        return false;
      }
      if (_selectedFilter == 'Transfers' && item.type != TransactionType.transfer) {
        return false;
      }

      // Date filter
      if (_selectedDate != null) {
        final sameDay = item.date.year == _selectedDate!.year &&
            item.date.month == _selectedDate!.month &&
            item.date.day == _selectedDate!.day;
        if (!sameDay) return false;
      }

      // Search query
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final titleMatch = item.title.toLowerCase().contains(query);
        final categoryMatch = item.category.toLowerCase().contains(query);
        return titleMatch || categoryMatch;
      }

      return true;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final currencyFormat = NumberFormat('#,##0.00', 'en_IN');
    final dateFormat = DateFormat('MMM d, h:mm a');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardColor = Theme.of(context).cardColor;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: textColor, size: 24),
                    onPressed: widget.onOpenDrawer,
                    tooltip: 'Open menu',
                  ),
                  Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _selectedDate == null
                          ? Icons.calendar_today_outlined
                          : Icons.event_available,
                      color: _selectedDate == null
                          ? textColor
                          : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
                      size: 22,
                    ),
                    onPressed: () {
                      if (_selectedDate != null) {
                        setState(() => _selectedDate = null);
                      } else {
                        _pickDate();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search note, category, or account...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Filter Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => setState(() => _selectedFilter = filter),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected && filter == 'All Types' ? 14 : 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF165945) : const Color(0xFF0A3026))
                              : cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? const Color(0xFF165945) : const Color(0xFF0A3026))
                                : borderColor,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected && filter == 'All Types') ...[
                              const Icon(
                                Icons.check,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              filter,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Main Content Area (Empty or List)
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(isDark, textColor)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isIncome = item.type == TransactionType.income;
                        final isTransfer = item.type == TransactionType.transfer;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? (isDark ? const Color(0xFF14532D) : const Color(0xFFE8F7ED))
                                      : isTransfer
                                          ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                                          : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFDE8E8)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_downward_rounded
                                      : isTransfer
                                          ? Icons.swap_horiz_rounded
                                          : Icons.arrow_upward_rounded,
                                  color: isIncome
                                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                                      : isTransfer
                                          ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                          : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dateFormat.format(item.date)} • ${item.category}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIncome ? '+' : isTransfer ? '' : '-'} ₹ ${currencyFormat.format(item.amount)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isIncome
                                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                                      : isTransfer
                                          ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                          : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                ),
                              ),
                              if (widget.onDeleteTransaction != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onPressed: () =>
                                      _confirmDeleteTransaction(context, item),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTransaction(BuildContext context, TransactionItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Transaction?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${item.title}" (₹ ${item.amount.toStringAsFixed(2)})?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteTransaction?.call(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${item.title}"'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular Search / No Results Icon
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 56,
                    color: Colors.grey.shade300,
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No transactions found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "+ Add Transaction" to manually log an\nexpense.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: widget.onAddTransaction,
              icon: Icon(Icons.add, size: 18, color: textColor),
              label: Text(
                'Add Transaction',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
