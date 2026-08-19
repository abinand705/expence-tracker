import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/auth_service.dart';
import 'budget_settings_screen.dart';
import 'recurring_expenses_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/app_update_service.dart';
import '../widgets/update_dialog.dart';
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.headlineMd),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          _buildSectionHeader('PREFERENCES'),
          _buildSettingsTile(Icons.dark_mode, 'Dark Mode', trailing: Switch(value: false, onChanged: (v) {})),
          _buildSettingsTile(Icons.notifications, 'Notifications', trailing: Switch(value: true, onChanged: (v) {})),
          _buildSettingsTile(Icons.security, 'Biometric Lock', trailing: Switch(value: false, onChanged: (v) {})),
          _buildSettingsTile(
            Icons.account_balance_wallet, 
            'Budgets',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetSettingsScreen()));
            },
          ),
          _buildSettingsTile(
            Icons.repeat, 
            'Recurring Expenses',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RecurringExpensesScreen()));
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader('DATA'),
          _buildSettingsTile(Icons.backup, 'Backup & Restore'),
          _buildSettingsTile(Icons.download, 'Export Data'),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader('ABOUT'),
          const _AppVersionCard(),
          _buildSettingsTile(Icons.help, 'Help & Support'),
          const SizedBox(height: AppSpacing.lg),
          _buildSettingsTile(
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(title, style: AppTypography.labelCaps),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, {String? subtitle, Widget? trailing, Color? textColor, Color? iconColor, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level1,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor ?? AppColors.primaryContainer),
        title: Text(title, style: AppTypography.bodyLg.copyWith(color: textColor)),
        subtitle: subtitle != null ? Text(subtitle, style: AppTypography.bodyMd) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.outline),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
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

      if (result.status == UpdateCheckStatus.updateAvailable && result.release != null) {
        setState(() => _updateStatus = 'available');
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(
            release: result.release!,
            currentPackageInfo: _packageInfo!,
          ),
        );
      } else if (result.status == UpdateCheckStatus.upToDate) {
        setState(() => _updateStatus = 'up_to_date');
      } else {
        String message;
        switch (result.status) {
          case UpdateCheckStatus.networkError:
            message = 'Unable to connect to the update service.\nPlease check your internet connection and try again.';
            break;
          case UpdateCheckStatus.notAuthorized:
            message = 'Your tester account is not authorized for this app.';
            break;
          case UpdateCheckStatus.configurationError:
            message = 'App updates are not currently available for this installation.';
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

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info, color: AppColors.primaryContainer),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MoneyTrack', style: AppTypography.bodyLg),
                  Text('Version ${_packageInfo!.version}+${_packageInfo!.buildNumber}', style: AppTypography.bodyMd.copyWith(color: AppColors.outline)),
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
                const Icon(Icons.fiber_manual_record, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text('New version available', style: AppTypography.bodyMd.copyWith(color: AppColors.primary)),
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
                  style: AppTypography.labelCaps.copyWith(color: _isChecking ? AppColors.outline : AppColors.primary)
                ),
                if (_isChecking)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(Icons.arrow_forward, size: 20, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
