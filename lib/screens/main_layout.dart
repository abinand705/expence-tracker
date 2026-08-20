import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'sms_inbox_screen.dart';
import 'transactions_screen.dart';
import 'my_accounts_screen.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_drawer.dart';
import '../services/app_update_service.dart';
import '../widgets/update_dialog.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _performStartupUpdateCheck();
  }

  Future<void> _performStartupUpdateCheck() async {
    // Non-blocking check for updates
    try {
      if (AppUpdateService().hasPromptedThisSession) return;

      final result = await AppUpdateService().checkForUpdate();
      if (result.status == UpdateCheckStatus.updateAvailable && mounted) {
        AppUpdateService().markAsPrompted();
        final packageInfo = await AppUpdateService().getAppVersionInfo();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => UpdateDialog(
              checkResult: result,
              currentPackageInfo: packageInfo,
            ),
          );
        }
      }
    } catch (e) {
      // Silently fail on startup check
    }
  }

  List<Widget> get _screens => [
    DashboardScreen(
      onSeeAllClicked: () {
        setState(() {
          _currentIndex = 1;
        });
      },
    ),
    const TransactionsScreen(),
    const MyAccountsScreen(),
    const SmsInboxScreen(),
  ];

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = _currentIndex == index;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                size: 24,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ] else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: const AppDrawer(),
      body: _screens[_currentIndex],
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(
            left: AppSpacing.containerMargin,
            right: AppSpacing.containerMargin,
            bottom: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: AppShadows.level2,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(0, Icons.home_filled),
                _buildNavItem(1, Icons.receipt_long_outlined),
                _buildNavItem(2, Icons.account_balance_wallet_outlined),
                _buildNavItem(3, Icons.chat_outlined),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
