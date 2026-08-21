import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'main_layout.dart';

class SmsPermissionsScreen extends StatelessWidget {
  const SmsPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.message, color: cs.primaryContainer, size: 48),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('SMS Permissions', style: AppTypography.headlineLg, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              Text(
                'MoneyTrack needs SMS access to automatically read bank transactions and track your expenses.',
                style: AppTypography.bodyLg.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainLayout()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.base)),
                  ),
                  child: Text('Allow Access', style: AppTypography.headlineMd),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainLayout()),
                  );
                },
                child: Text('Skip for now', style: AppTypography.bodyLg.copyWith(color: cs.outline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

