import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class MyAccountsScreen extends StatelessWidget {
  const MyAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Accounts', style: AppTypography.headlineMd),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          _buildAccountCard('HDFC Bank', '**** **** **** 1234', 45000.50, AppColors.primaryContainer),
          const SizedBox(height: AppSpacing.md),
          _buildAccountCard('SBI Account', '**** **** **** 9876', 12500.00, AppColors.successGreen),
          const SizedBox(height: AppSpacing.md),
          _buildAccountCard('Cash Wallet', 'Physical Cash', 3450.00, AppColors.tertiary),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primaryContainer,
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
    );
  }

  Widget _buildAccountCard(String bank, String number, double balance, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bank, style: AppTypography.headlineMd.copyWith(color: Colors.white)),
              const Icon(Icons.account_balance, color: Colors.white),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(number, style: AppTypography.bodyMd.copyWith(color: Colors.white70)),
          const SizedBox(height: AppSpacing.lg),
          Text('\$${balance.toStringAsFixed(2)}', style: AppTypography.displayCurrency.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
