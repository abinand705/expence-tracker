import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ConversationViewScreen extends StatelessWidget {
  final String sender;

  const ConversationViewScreen({super.key, required this.sender});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(sender, style: AppTypography.headlineMd),
        backgroundColor: AppColors.surfaceBright,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          _buildMessageBubble('Your account was debited \$14.99 at Netflix.', '10:30 AM', true),
          const SizedBox(height: AppSpacing.md),
          _buildMessageBubble('Your account was debited \$45.00 at Target.', '02:15 PM', true),
          const SizedBox(height: AppSpacing.md),
          _buildMessageBubble('Salary of \$3200 credited to your account.', '09:00 AM', true),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, String time, bool isReceived) {
    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isReceived ? AppColors.surfaceContainerLowest : AppColors.primaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.xl),
            topRight: const Radius.circular(AppRadius.xl),
            bottomLeft: Radius.circular(isReceived ? 0 : AppRadius.xl),
            bottomRight: Radius.circular(isReceived ? AppRadius.xl : 0),
          ),
          boxShadow: AppShadows.level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: AppTypography.bodyLg.copyWith(
                color: isReceived ? AppColors.onSurface : AppColors.onPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              time,
              style: AppTypography.labelMuted.copyWith(
                color: isReceived ? AppColors.outline : AppColors.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
