import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_controller.dart';
import '../services/auth_service.dart';
import 'budget_settings_screen.dart';
import 'recurring_expenses_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/app_update_service.dart';
import '../widgets/update_dialog.dart';
import 'help_support_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.headlineMd),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          _buildSectionHeader(context, 'PREFERENCES'),
          const _AppearanceSetting(),
          _buildSettingsTile(context, Icons.notifications, 'Notifications', trailing: Switch(value: true, onChanged: (v) {})),
          _buildSettingsTile(context, Icons.security, 'Biometric Lock', trailing: Switch(value: false, onChanged: (v) {})),
          const _ExpenseCycleSetting(),
          _buildSettingsTile(
            context,
            Icons.account_balance_wallet, 
            'Budgets',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetSettingsScreen()));
            },
          ),
          _buildSettingsTile(
            context,
            Icons.repeat, 
            'Recurring Expenses',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RecurringExpensesScreen()));
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(context, 'DATA'),
          _buildSettingsTile(context, Icons.backup, 'Backup & Restore'),
          _buildSettingsTile(context, Icons.download, 'Export Data'),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(context, 'ABOUT'),
          const _AppVersionCard(),
          _buildSettingsTile(
            context,
            Icons.help, 
            'Help & Support',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen()));
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSettingsTile(
            context,
            Icons.logout, 
            'Logout', 
            textColor: AppColors.errorRed,
            iconColor: AppColors.errorRed,
            trailing: const SizedBox.shrink(),
            onTap: () async {
              try {
                await AuthService().logout();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.errorRed),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(title, style: AppTypography.labelCaps),
    );
  }

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, {String? subtitle, Widget? trailing, Color? textColor, Color? iconColor, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level1,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor ?? cs.primaryContainer),
        title: Text(title, style: AppTypography.bodyLg.copyWith(color: textColor)),
        subtitle: subtitle != null ? Text(subtitle, style: AppTypography.bodyMd) : null,
        trailing: trailing ?? Icon(Icons.chevron_right, color: cs.outline),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appearance Setting (Theme Mode Selector)
// ─────────────────────────────────────────────────────────────────────────────
class _AppearanceSetting extends StatelessWidget {
  const _AppearanceSetting();

  Future<void> _showAppearanceDialog(BuildContext context) async {
    ThemeMode selected = themeController.themeMode;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Appearance', style: AppTypography.headlineMd),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mode in [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
                    RadioListTile<ThemeMode>(
                      title: Text(_labelFor(mode), style: AppTypography.bodyLg),
                      value: mode,
                      groupValue: selected,
                      activeColor: Theme.of(context).colorScheme.primaryContainer,
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => selected = val);
                          await themeController.setThemeMode(val);
                        }
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: AppTypography.labelCaps.copyWith(color: Theme.of(context).colorScheme.primaryContainer)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return 'System Default';
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.level1,
          ),
          child: ListTile(
            onTap: () => _showAppearanceDialog(context),
            leading: Icon(Icons.palette_outlined, color: cs.primaryContainer),
            title: Text('Appearance', style: AppTypography.bodyLg),
            subtitle: Text(themeController.themeModeLabel, style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant)),
            trailing: Icon(Icons.chevron_right, color: cs.outline),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          ),
        );
      },
    );
  }
}

class _AppVersionCard extends StatefulWidget {
  const _AppVersionCard();


  @override
  State<_AppVersionCard> createState() => _AppVersionCardState();
}

class _AppVersionCardState extends State<_AppVersionCard> {
  PackageInfo? _packageInfo;
  bool _isChecking = false;
  String? _updateStatus; // "up_to_date" or "available" or null

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await AppUpdateService().getAppVersionInfo();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (_packageInfo == null) return;
    
    setState(() {
      _isChecking = true;
      _updateStatus = null;
    });

    try {
      final result = await AppUpdateService().checkForUpdate();
      if (!mounted) return;

      if (result.status == UpdateCheckStatus.updateAvailable) {
        setState(() => _updateStatus = 'available');
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(
            checkResult: result,
            currentPackageInfo: _packageInfo!,
          ),
        );
      } else if (result.status == UpdateCheckStatus.upToDate) {
        setState(() => _updateStatus = 'up_to_date');
      } else {
        String message;
        switch (result.status) {
          case UpdateCheckStatus.networkError:
            message = 'Unable to reach the update server.\nPlease check your internet connection and try again.';
            break;
          case UpdateCheckStatus.notAuthorized:
            // Since it's public update, we shouldn't hit this, but just in case
            message = 'Update check failed. Not authorized.';
            break;
          case UpdateCheckStatus.configurationError:
            message = 'Invalid update information.';
            break;
          case UpdateCheckStatus.unknownError:
          default:
            message = 'Unable to check for updates right now.\nPlease try again later.';
            break;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to check for updates right now.\nPlease try again later.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_packageInfo == null) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: cs.primaryContainer),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MoneyTrack', style: AppTypography.bodyLg),
                  Text('Version ${_packageInfo!.version}+${_packageInfo!.buildNumber}', style: AppTypography.bodyMd.copyWith(color: cs.outline)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_updateStatus == 'up_to_date') ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text('You\'re up to date', style: AppTypography.bodyMd.copyWith(color: Colors.green)),
              ],
            ),
          ] else if (_updateStatus == 'available') ...[
            Row(
              children: [
                Icon(Icons.fiber_manual_record, color: cs.primaryContainer, size: 16),
                const SizedBox(width: 8),
                Text('New version available', style: AppTypography.bodyMd.copyWith(color: cs.primaryContainer)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: _isChecking ? null : _checkForUpdates,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isChecking ? 'Checking for updates...' : (_updateStatus == 'available' ? 'Update Now' : 'Check for Updates'), 
                  style: AppTypography.labelCaps.copyWith(color: _isChecking ? cs.outline : cs.primaryContainer)
                ),
                if (_isChecking)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(Icons.arrow_forward, size: 20, color: cs.primaryContainer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _ExpenseCycleSetting extends StatefulWidget {
  const _ExpenseCycleSetting();

  @override
  State<_ExpenseCycleSetting> createState() => _ExpenseCycleSettingState();
}

class _ExpenseCycleSettingState extends State<_ExpenseCycleSetting> {
  Future<void> _showCycleDialog(BuildContext context, String currentCycle, int? customDays) async {
    String selected = currentCycle;
    int? days = customDays;
    final TextEditingController daysController = TextEditingController(text: days?.toString() ?? '14');

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Expense Cycle', style: AppTypography.headlineMd),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in ['daily', 'weekly', 'monthly', 'quarterly', 'yearly', 'custom'])
                      RadioListTile<String>(
                        title: Text(option[0].toUpperCase() + option.substring(1), style: AppTypography.bodyLg),
                        value: option,
                        groupValue: selected,
                        onChanged: (val) {
                          if (val != null) setState(() => selected = val);
                        },
                      ),
                    if (selected == 'custom')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: daysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Cycle length (days)'),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    int? parsedDays;
                    if (selected == 'custom') {
                      parsedDays = int.tryParse(daysController.text);
                      if (parsedDays == null || parsedDays <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid number of days')));
                        return;
                      }
                    }
                    Navigator.pop(context);
                    
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      await UserRepository().updateProfile(uid, {
                        'expenseCycle': selected,
                        'customCycleDays': parsedDays,
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserRepository().watchProfile(uid),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final currentCycle = data?['expenseCycle'] as String? ?? 'monthly';
        final customDays = data?['customCycleDays'] as int?;

        String subtitle = currentCycle[0].toUpperCase() + currentCycle.substring(1);
        if (currentCycle == 'custom' && customDays != null) {
          subtitle = 'Rolling $customDays days';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.level1,
          ),
          child: ListTile(
            onTap: () => _showCycleDialog(context, currentCycle, customDays),
            leading: Icon(Icons.access_time, color: Theme.of(context).colorScheme.primaryContainer),
            title: Text('Expense Cycle', style: AppTypography.bodyLg),
            subtitle: Text(subtitle, style: AppTypography.bodyMd),
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          ),
        );
      },
    );
  }
}
