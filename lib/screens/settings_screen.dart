import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/transaction_item.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeController? themeController;
  final AuthController? authController;
  final VoidCallback? onClearAllData;
  final VoidCallback? onOpenAuth;

  const SettingsScreen({
    super.key,
    this.themeController,
    this.authController,
    this.onClearAllData,
    this.onOpenAuth,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedCurrency = '₹';
  late String _selectedTheme;
  bool _shakeInApp = true;
  bool _shakeAnywhere = false;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.themeController?.themeName ?? 'Light';
  }

  void _chooseCurrency() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Currency Symbol',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...[
              '₹ - Indian Rupee (INR)',
              r'$ - US Dollar (USD)',
              '€ - Euro (EUR)',
              '£ - British Pound (GBP)',
              '¥ - Japanese Yen (JPY)',
            ].map((curr) {
              final symbol = curr.split(' ')[0];
              final isSelected = _selectedCurrency == symbol;
              return ListTile(
                title: Text(curr),
                trailing: isSelected
                    ? Icon(Icons.check,
                        color: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF0A3026))
                    : null,
                onTap: () {
                  setState(() => _selectedCurrency = symbol);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _chooseTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Theme Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...['Light', 'Dark', 'System'].map((theme) {
              final isSelected = _selectedTheme == theme;
              return ListTile(
                title: Text('$theme Mode'),
                trailing: isSelected
                    ? Icon(Icons.check,
                        color: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF0A3026))
                    : null,
                onTap: () {
                  setState(() => _selectedTheme = theme);
                  widget.themeController?.setThemeByName(theme);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _previewQuickExpense() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddTransactionSheet(
        initialType: TransactionType.expense,
        onAdd: (tx) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Test expense added: ₹ ${tx.amount}')),
          );
        },
      ),
    );
  }

  void _confirmSignOut() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              widget.authController?.logout();
              if (mounted) setState(() {});
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

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently erase all transactions and custom budgets stored on this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onClearAllData?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data has been cleared'),
                  backgroundColor: Color(0xFFDC2626),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFEDF2F7);
    final dividerColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconColor =
        isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Crucial: The '+' button is ignored / suppressed on this screen
      floatingActionButton: null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header with Back button and centered Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textColor,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 48), // Balances the back icon button
                ],
              ),
              const SizedBox(height: 18),

              // Account & Security Card
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: widget.authController?.isLoggedIn == true
                    ? _buildSettingsTile(
                        icon: Icons.account_circle_rounded,
                        iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                        title: widget.authController?.userName ?? 'User Profile',
                        titleColor: textColor,
                        subtitle: widget.authController?.userEmail ?? 'Logged In',
                        subtitleColor: subtitleColor,
                        trailing: OutlinedButton(
                          onPressed: _confirmSignOut,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Sign Out', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                        ),
                      )
                    : _buildSettingsTile(
                        icon: Icons.person_outline_rounded,
                        iconColor: iconColor,
                        title: 'Sign In / Register',
                        titleColor: textColor,
                        subtitle: 'Create an account to backup your data',
                        subtitleColor: subtitleColor,
                        trailing: ElevatedButton(
                          onPressed: () {
                            widget.onOpenAuth?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF165945) : const Color(0xFF0A3026),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Sign In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
              ),
              const SizedBox(height: 18),

              // General Settings Card
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Currency Symbol
                    _buildSettingsTile(
                      icon: Icons.currency_exchange_rounded,
                      iconColor: iconColor,
                      title: 'Currency Symbol',
                      titleColor: textColor,
                      subtitle: 'Selected: $_selectedCurrency',
                      subtitleColor: subtitleColor,
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onTap: _chooseCurrency,
                    ),
                    Divider(height: 1, indent: 60, color: dividerColor),

                    // Theme Mode
                    _buildSettingsTile(
                      icon: Icons.dark_mode_outlined,
                      iconColor: iconColor,
                      title: 'Theme Mode',
                      titleColor: textColor,
                      subtitle: '$_selectedTheme Mode',
                      subtitleColor: subtitleColor,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedTheme,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: _chooseTheme,
                    ),
                    Divider(height: 1, indent: 60, color: dividerColor),

                    // Shake to Add (In-App)
                    _buildSettingsTile(
                      icon: Icons.vibration_rounded,
                      iconColor: iconColor,
                      title: 'Shake to Add (In-App)',
                      titleColor: textColor,
                      subtitle:
                          'Shake your phone while inside the app to log an expense',
                      subtitleColor: subtitleColor,
                      trailing: Switch(
                        value: _shakeInApp,
                        activeThumbColor: Colors.white,
                        activeTrackColor: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF0A3026),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1),
                        trackOutlineColor:
                            WidgetStateProperty.all(Colors.transparent),
                        onChanged: (val) => setState(() => _shakeInApp = val),
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: dividerColor),

                    // Shake Anywhere (Outside App)
                    _buildSettingsTile(
                      icon: Icons.screen_lock_rotation_outlined,
                      iconColor: iconColor,
                      title: 'Shake Anywhere (Outside App)',
                      titleColor: textColor,
                      subtitle:
                          'Shake your phone from home screen or other apps to instantly open the expense sheet',
                      subtitleColor: subtitleColor,
                      trailing: Switch(
                        value: _shakeAnywhere,
                        activeThumbColor: Colors.white,
                        activeTrackColor: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF0A3026),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1),
                        trackOutlineColor:
                            WidgetStateProperty.all(Colors.transparent),
                        onChanged: (val) =>
                            setState(() => _shakeAnywhere = val),
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: dividerColor),

                    // Preview Quick Expense Panel
                    _buildSettingsTile(
                      icon: Icons.bolt_rounded,
                      iconColor: iconColor,
                      title: 'Preview Quick Expense Panel',
                      titleColor: textColor,
                      subtitle: 'Tap to test the quick expense popup',
                      subtitleColor: subtitleColor,
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onTap: _previewQuickExpense,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Data & Backup Section Header
              Text(
                'Data & Backup',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),

              // Data & Backup Card
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Export to CSV
                    _buildSettingsTile(
                      icon: Icons.download_rounded,
                      iconColor: iconColor,
                      title: 'Export to CSV',
                      titleColor: textColor,
                      subtitle: 'Download or share your full transaction history',
                      subtitleColor: subtitleColor,
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction history exported as CSV'),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 60, color: dividerColor),

                    // Clear All Data
                    _buildSettingsTile(
                      icon: Icons.delete_outline_rounded,
                      iconColor: const Color(0xFFDC2626),
                      title: 'Clear All Data',
                      titleColor: const Color(0xFFDC2626),
                      subtitle: 'Erase all transactions and custom budgets',
                      subtitleColor: subtitleColor,
                      onTap: _confirmClearData,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Footer
              Center(
                child: Column(
                  children: [
                    const Text(
                      'MoneyTrack v1.0.0',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Private • Manual Expense Tracker',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    Color? titleColor,
    required String subtitle,
    Color? subtitleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor ?? const Color(0xFF0A3026),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: subtitleColor ?? const Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}
