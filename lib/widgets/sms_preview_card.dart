import 'package:flutter/material.dart';
import '../services/sms_service.dart';
import 'package:intl/intl.dart';
import '../models/sms_message.dart';
import '../models/sms_models.dart';
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
        final smsService = SmsService();
        final conversation = smsService.conversations.firstWhere(
          (c) => c.senderName == message.sender,
          orElse: () => Conversation(
            id: 'temp', 
            senderName: message.sender, 
            senderNumber: message.sender,
            avatarColor: AppColors.primaryContainer,
            messages: [
              Message(
                id: message.id, 
                text: message.snippet, 
                timestamp: message.date, 
                isMe: false,
              )
            ],
            unreadCount: 0,
            isBankSender: false,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationViewScreen(conversation: conversation),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.level1,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.surfaceContainerHigh,
              child: Text(
                message.sender.substring(0, 1).toUpperCase(),
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        message.sender,
                        style: AppTypography.bodyLg.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat.jm().format(message.date),
                        style: AppTypography.labelMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message.snippet,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.extractedAmount != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Extracted: ${currencyFormatter.format(message.extractedAmount)}',
                        style: AppTypography.labelCaps.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
