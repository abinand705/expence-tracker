import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../screens/my_accounts_screen.dart';
import '../screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surfaceBright,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 36, color: AppColors.primaryContainer),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('John Doe', style: AppTypography.headlineMd.copyWith(color: AppColors.onPrimary)),
                Text('+91 9876543210', style: AppTypography.bodyMd.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: AppColors.primaryContainer),
            title: Text('My Accounts', style: AppTypography.bodyLg),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAccountsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.primaryContainer),
            title: Text('Settings', style: AppTypography.bodyLg),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }
}
