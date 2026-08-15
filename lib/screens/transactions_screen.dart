import 'package:flutter/material.dart';
import '../services/mock_sms_service.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/transaction_card.dart';
import '../widgets/app_drawer.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'UPI', 'Credit Card', 'Debits', 'Credits'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockSmsService(),
      builder: (context, _) {
        final transactions = MockSmsService().parsedTransactions;
        List<Transaction> filteredTransactions = transactions.where((t) {
          if (_selectedFilter == 'All') return true;
          final msg = t.rawMessage?.toLowerCase() ?? '';
          if (_selectedFilter == 'UPI') return msg.contains('upi');
          if (_selectedFilter == 'Credit Card') return msg.contains('cc') || msg.contains('card') || msg.contains('credit');
          if (_selectedFilter == 'Debits') return t.type == TransactionType.expense;
          if (_selectedFilter == 'Credits') return t.type == TransactionType.income;
          return true;
        }).toList();

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Text('Transactions', style: AppTypography.headlineMd),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search expenses, merchants...',
                hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                prefixIcon: const Icon(Icons.search, color: AppColors.outline),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.xs),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: AppTypography.bodyMd.copyWith(
                        color: isSelected ? Colors.white : AppColors.primary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(
                left: AppSpacing.containerMargin,
                right: AppSpacing.containerMargin,
                top: AppSpacing.md,
                bottom: 100,
              ),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                return TransactionCard(transaction: filteredTransactions[index]);
              },
            ),
          ),
        ],
      ),
    );
    });
  }
}
