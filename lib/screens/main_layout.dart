import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'sms_inbox_screen.dart';
import 'transactions_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const DashboardScreen(),
    const TransactionsScreen(),
    const SmsInboxScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: AppShadows.level2,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.primaryContainer,
              unselectedItemColor: AppColors.outline,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_outlined),
                  activeIcon: Icon(Icons.list_alt),
                  label: 'Transactions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.message_outlined),
                  activeIcon: Icon(Icons.message),
                  label: 'SMS',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
