import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/sms_service.dart';
class MessagesSettingsScreen extends StatefulWidget {
  const MessagesSettingsScreen({super.key});

  @override
  State<MessagesSettingsScreen> createState() => _MessagesSettingsScreenState();
}

class _MessagesSettingsScreenState extends State<MessagesSettingsScreen> {
  final SmsService _smsService = SmsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text('Message Settings', style: AppTypography.headlineMd),
      ),
      body: ListenableBuilder(
        listenable: _smsService,
        builder: (context, _) {
          final settings = _smsService.settings;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCard(
                  title: 'Appearance',
                  icon: Icons.palette_outlined,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Theme', style: AppTypography.bodyMd),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ThemeMode>(
                                value: settings.themeMode,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                items: const [
                                  DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                                ],
                                onChanged: (val) {
                                  if (val != null) _smsService.updateSettings(settings.copyWith(themeMode: val));
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildCard(
                  title: 'Notifications',
                  icon: Icons.notifications_none,
                  children: [
                    _buildSwitchTile(
                      title: 'Enable Notifications',
                      value: settings.notificationsEnabled,
                      onChanged: (val) => _smsService.updateSettings(settings.copyWith(notificationsEnabled: val)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildCard(
                  title: 'Storage & Data',
                  icon: Icons.storage_outlined,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Auto-delete old messages', style: AppTypography.bodyMd),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: settings.autoDeleteDays,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('Never')),
                                  DropdownMenuItem(value: 7, child: Text('After 7 Days')),
                                  DropdownMenuItem(value: 30, child: Text('After 30 Days')),
                                  DropdownMenuItem(value: 90, child: Text('After 90 Days')),
                                ],
                                onChanged: (val) {
                                  _smsService.updateSettings(settings.copyWith(autoDeleteDays: val, clearAutoDelete: val == null));
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primaryContainer, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: AppTypography.bodyLg.copyWith(color: AppColors.primaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      title: Text(title, style: AppTypography.bodyMd),
      subtitle: subtitle != null ? Text(subtitle, style: AppTypography.labelMuted) : null,
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
      inactiveThumbColor: Theme.of(context).colorScheme.onSurfaceVariant,
      inactiveTrackColor: Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    );
  }
}
