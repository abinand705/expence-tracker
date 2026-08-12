import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

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

  Widget _buildSettingsTile(IconData icon, String title, {String? subtitle, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level1,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryContainer),
        title: Text(title, style: AppTypography.bodyLg),
        subtitle: subtitle != null ? Text(subtitle, style: AppTypography.bodyMd) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.outline),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
    );
  }
}
