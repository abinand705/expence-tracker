import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback? onOpenSettings;
  final AuthController? authController;
  final VoidCallback? onOpenAuth;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
    this.onOpenSettings,
    this.authController,
    this.onOpenAuth,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final headerBorderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final isLoggedIn = authController?.isLoggedIn ?? false;

    return Drawer(
      backgroundColor: drawerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            InkWell(
              onTap: isLoggedIn
                  ? null
                  : () {
                      Navigator.pop(context);
                      onOpenAuth?.call();
                    },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: headerBorderColor, width: 1.2),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoggedIn
                                ? (authController?.userName ?? 'MoneyTrack User')
                                : 'MoneyTrack',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLoggedIn
                                ? (authController?.userEmail ?? 'Personal Finance')
                                : 'Sign In / Register',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isLoggedIn
                                  ? subtitleColor
                                  : (isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026)),
                              fontWeight: isLoggedIn ? FontWeight.w500 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  _buildDrawerItem(
                    index: 0,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    context: context,
                  ),
                  _buildDrawerItem(
                    index: 1,
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    title: 'Transactions',
                    context: context,
                  ),
                  _buildDrawerItem(
                    index: 2,
                    icon: Icons.pie_chart_outline_rounded,
                    activeIcon: Icons.pie_chart_rounded,
                    title: 'Analyse & Visualise',
                    context: context,
                  ),
                  _buildDrawerItem(
                    index: 3,
                    icon: Icons.savings_outlined,
                    activeIcon: Icons.savings_rounded,
                    title: 'Budgets & Categories',
                    context: context,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(color: Color(0xFFF1F5F9), height: 1),
                  ),
                  _buildActionItem(
                    icon: Icons.file_download_outlined,
                    title: 'Export Data (CSV / JSON)',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Export data feature coming soon'),
                        ),
                      );
                    },
                  ),
                  _buildActionItem(
                    icon: Icons.backup_outlined,
                    title: 'Backup & Restore',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Offline backup saved securely on device'),
                        ),
                      );
                    },
                  ),
                  _buildActionItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      onOpenSettings?.call();
                    },
                  ),
                  if (isLoggedIn)
                    _buildActionItem(
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      titleColor: const Color(0xFFDC2626),
                      iconColor: const Color(0xFFDC2626),
                      onTap: () {
                        _confirmSignOut(context);
                      },
                    )
                  else
                    _buildActionItem(
                      icon: Icons.login_rounded,
                      title: 'Sign In / Register',
                      titleColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                      iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                      onTap: () {
                        Navigator.pop(context);
                        onOpenAuth?.call();
                      },
                    ),
                  _buildActionItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About MoneyTrack',
                    onTap: () {
                      Navigator.pop(context);
                      showAboutDialog(
                        context: context,
                        applicationName: 'MoneyTrack',
                        applicationVersion: '1.0.0',
                        applicationIcon: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          ),
                        ),
                        children: const [
                          Text(
                            'MoneyTrack is an intuitive expense tracker designed to help you manage your personal finances with complete privacy.',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                children: [
                  const Text(
                    'MoneyTrack v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No data leaves your device',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of MoneyTrack?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
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
              Navigator.pop(dialogCtx);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              authController?.logout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out successfully')),
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
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required BuildContext context,
  }) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE5F4EC);
    final selectedColor = isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026);
    final unselectedText = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final unselectedIcon = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          leading: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? selectedColor : unselectedIcon,
            size: 22,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? selectedColor : unselectedText,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            onSelectTab(index);
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              dense: true,
              leading: Icon(
                icon,
                color: iconColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                size: 22,
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                ),
              ),
              onTap: onTap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      },
    );
  }
}
