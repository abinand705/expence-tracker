import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'main_layout.dart';

class SplashLoginScreen extends StatelessWidget {
  const SplashLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1A0D3B2E), // primaryContainer 10%
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x3388F798), // secondaryContainer 20%
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.containerMargin),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.level1,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: AppColors.onPrimary, size: 32),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('MoneyTrack', style: AppTypography.displayCurrency.copyWith(color: AppColors.primary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Track every rupee', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.xl),
                    
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mobile Number', style: AppTypography.labelCaps.copyWith(color: AppColors.onSurfaceVariant)),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBright,
                            borderRadius: BorderRadius.circular(AppRadius.base),
                            border: Border.all(color: AppColors.surfaceVariant),
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                child: Icon(Icons.call, color: AppColors.outline),
                              ),
                              Container(
                                padding: const EdgeInsets.only(right: AppSpacing.sm),
                                decoration: const BoxDecoration(
                                  border: Border(right: BorderSide(color: AppColors.surfaceVariant)),
                                ),
                                child: Text('+91', style: AppTypography.bodyLg),
                              ),
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your number',
                                    hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.outlineVariant),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                  ),
                                  style: AppTypography.bodyLg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const MainLayout()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.base)),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Get OTP', style: AppTypography.headlineMd.copyWith(color: AppColors.onPrimary)),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.surfaceVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Text('OR', style: AppTypography.labelMuted.copyWith(color: AppColors.outline)),
                        ),
                        const Expanded(child: Divider(color: AppColors.surfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceBright,
                          side: const BorderSide(color: AppColors.surfaceVariant),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.base)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('G', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20)),
                            const SizedBox(width: AppSpacing.md),
                            Text('Continue with Google', style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Don\'t have an account?', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                        const SizedBox(width: AppSpacing.xs),
                        Text('Sign up', style: AppTypography.headlineMd.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
