import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/transaction_repository.dart';
import '../models/transaction.dart';
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
  bool _hasError = false;
  StreamSubscription<List<Transaction>>? _transactionSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _transactionSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    _transactionSubscription = _transactionRepo.watchTransactions().listen(
      (transactions) {
        debugPrint('[TRANSACTION_PAGE] Transactions received: ${transactions.length}');
        if (mounted) {
          setState(() {
            _allTransactions = transactions;
            _isLoading = false;
            _hasError = false;
          });
        }
      },
      onError: (e) {
        debugPrint('[TRANSACTION_PAGE] Error loading transactions: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
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
        final matchTitle = t.displayTitle.toLowerCase().contains(query);
        final matchMerchant = t.merchant.toLowerCase().contains(query);
        final matchCategory = t.displayCategory.toLowerCase().contains(query) || t.category.toLowerCase().contains(query);
        final matchSubtitle = (t.subtitle ?? '').toLowerCase().contains(query);
        final matchDescription = (t.description ?? '').toLowerCase().contains(query);
        if (!matchTitle && !matchMerchant && !matchCategory && !matchSubtitle && !matchDescription) return false;
      }
      
      if (_selectedFilter == 'All') return true;
      final msg = t.rawMessage?.toLowerCase() ?? '';
      if (_selectedFilter == 'UPI') return msg.contains('upi');
      if (_selectedFilter == 'Debits') return t.type == TransactionType.expense;
      if (_selectedFilter == 'Credits') return t.type == TransactionType.income;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Text('Transactions', style: AppTypography.headlineMd),
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
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                hintText: 'Search expenses, merchants...',
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.md),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                final cs = Theme.of(context).colorScheme;
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
                    labelStyle: AppTypography.bodyMd.copyWith(
                      color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Loading transactions...',
                          style: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Unable to load transactions',
                              style: AppTypography.headlineMd.copyWith(color: Theme.of(context).colorScheme.onSurface),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FilledButton.tonal(
                              onPressed: _startListening,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      )
                    : filteredTransactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(120)),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                      ? 'No transactions found'
                                      : 'No transactions yet',
                                  style: AppTypography.bodyLg.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadTransactions,
                            color: Theme.of(context).colorScheme.primary,
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
