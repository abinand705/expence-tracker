import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sms_message.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../screens/conversation_view_screen.dart';

class SmsPreviewCard extends StatelessWidget {
  final SmsMessage message;

  const SmsPreviewCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.simpleCurrency();
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationViewScreen(sender: message.sender),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.level1,
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                message.sender,
                style: AppTypography.labelCaps,
              ),
              Text(
                _formatTime(message.date),
                style: AppTypography.labelMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message.snippet,
            style: AppTypography.bodyLg,
          ),
          if (message.extractedAmount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Extracted: ',
                  style: AppTypography.labelMuted,
                ),
                Text(
                  currencyFormatter.format(message.extractedAmount),
                  style: AppTypography.headlineMd.copyWith(color: AppColors.errorRed),
                ),
              ],
            )
          ]
        ],
      ),
    ));
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
