import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/auth_service.dart';

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
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader('DATA'),
          _buildSettingsTile(Icons.backup, 'Backup & Restore'),
          _buildSettingsTile(Icons.download, 'Export Data'),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader('ABOUT'),
          _buildSettingsTile(Icons.info, 'App Version', subtitle: '1.0.0'),
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
