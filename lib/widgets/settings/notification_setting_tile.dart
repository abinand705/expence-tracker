import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class NotificationSettingTile extends StatefulWidget {
  const NotificationSettingTile({super.key});

  @override
  State<NotificationSettingTile> createState() => _NotificationSettingTileState();
}

class _NotificationSettingTileState extends State<NotificationSettingTile> {
  final SettingsService _settingsService = SettingsService();
  bool _enabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await _settingsService.getNotificationsEnabled();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await _settingsService.setNotificationsEnabled(value);
    if (value) {
      await NotificationService().requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.level1,
      ),
      child: ListTile(
        leading: Icon(
          _enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
          color: cs.primaryContainer,
        ),
        title: Text('Notifications', style: AppTypography.bodyLg),
        subtitle: Text(
          _enabled ? 'Budget limit alerts enabled' : 'Notifications disabled',
          style: AppTypography.bodyMd.copyWith(color: cs.outline),
        ),
        trailing: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(
                value: _enabled,
                activeThumbColor: cs.primaryContainer,
                onChanged: _toggle,
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
    );
  }
}
