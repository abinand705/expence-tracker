import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/transaction_repository.dart';
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
  final TransactionRepository _transactionRepo = TransactionRepository();
  
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final List<String> _filters = ['All', 'UPI', 'Debits', 'Credits'];
  
  List<Transaction> _allTransactions = [];
  bool _isLoading = true;
  StreamSubscription<List<Transaction>>? _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _transactionSubscription = _transactionRepo.watchTransactions().listen(
      (transactions) {
        if (mounted) {
          setState(() {
            _allTransactions = transactions;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    // Kept for RefreshIndicator compatibility, stream handles actual data updates
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    List<Transaction> filteredTransactions = _allTransactions.where((t) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchMerchant = t.merchant.toLowerCase().contains(query);
        final matchCategory = t.category.toLowerCase().contains(query);
        final matchSubtitle = (t.subtitle ?? '').toLowerCase().contains(query);
        if (!matchMerchant && !matchCategory && !matchSubtitle) return false;
      }
      
      if (_selectedFilter == 'All') return true;
      final msg = t.rawMessage?.toLowerCase() ?? '';
      if (_selectedFilter == 'UPI') return msg.contains('upi');
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
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.sm),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search expenses, merchants...',
                hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                prefixIcon: const Icon(Icons.search, color: AppColors.outline),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.md),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) _selectedFilter = filter;
                      });
                    },
                    backgroundColor: AppColors.surfaceContainerLowest,
                    selectedColor: AppColors.primary,
                    labelStyle: AppTypography.bodyMd.copyWith(
                      color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : filteredTransactions.isEmpty 
                  ? const Center(child: Text("No transactions found"))
                  : RefreshIndicator(
                      onRefresh: _loadTransactions,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          return TransactionCard(transaction: filteredTransactions[index]);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
