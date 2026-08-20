import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../screens/settings_screen.dart';
import '../screens/help_support_screen.dart';
import '../services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // DrawerHeader brand color is intentional — keep as AppColors.primaryContainer
    return Drawer(
      // backgroundColor provided by DrawerThemeData in AppTheme
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: AppColors.primaryContainer),
                  child: StreamBuilder<Map<String, dynamic>?>(
                    stream: FirebaseAuth.instance.currentUser != null
                        ? UserRepository().watchProfile(FirebaseAuth.instance.currentUser!.uid)
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      final currentUser = FirebaseAuth.instance.currentUser;

                      String displayName = 'Loading...';
                      String email = '';
                      String? photoURL;

                      if (snapshot.connectionState == ConnectionState.active || snapshot.connectionState == ConnectionState.done) {
                        final data = snapshot.data;
                        displayName = data?['displayName'] as String? ?? currentUser?.displayName ?? 'User';
                        email = data?['email'] as String? ?? currentUser?.email ?? '';
                        photoURL = data?['photoURL'] as String? ?? currentUser?.photoURL;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              image: photoURL != null
                                  ? DecorationImage(image: NetworkImage(photoURL), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: photoURL == null ? const Icon(Icons.person, size: 36, color: AppColors.primaryContainer) : null,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(displayName, style: AppTypography.headlineMd.copyWith(color: AppColors.onPrimary)),
                          if (email.isNotEmpty)
                            Text(email, style: AppTypography.bodyMd.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.7))),
                        ],
                      );
                    },
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.settings, color: cs.primaryContainer),
                  title: Text('Settings', style: AppTypography.bodyLg),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.help_outline, color: cs.onSurfaceVariant),
                  title: Text('Help & Support', style: AppTypography.bodyLg),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context); // Close drawer
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
              icon: const Icon(Icons.logout, color: AppColors.errorRed),
              label: Text('Log Out', style: AppTypography.bodyLg.copyWith(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text('v1.0.2', style: AppTypography.labelMuted.copyWith(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

