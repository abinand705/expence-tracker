import 'package:flutter/material.dart';
import '../models/dummy_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/transaction_card.dart';
import '../widgets/app_drawer.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = DummyData.getTransactions();
    final allTransactions = [...transactions, ...transactions, ...transactions];

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
      body: ListView.builder(
        padding: const EdgeInsets.only(
          left: AppSpacing.containerMargin,
          right: AppSpacing.containerMargin,
          top: AppSpacing.md,
          bottom: 100,
        ),
        itemCount: allTransactions.length,
        itemBuilder: (context, index) {
          return TransactionCard(transaction: allTransactions[index]);
        },
      ),
    );
  }
}
