import 'package:flutter/material.dart';
import '../models/dummy_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/sms_preview_card.dart';
import '../widgets/app_drawer.dart';

class SmsInboxScreen extends StatelessWidget {
  const SmsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final messages = DummyData.getSmsMessages();

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text('SMS Inbox', style: AppTypography.headlineMd),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(
          left: AppSpacing.containerMargin,
          right: AppSpacing.containerMargin,
          top: AppSpacing.md,
          bottom: 100, // For bottom nav
        ),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          return SmsPreviewCard(message: messages[index]);
        },
      ),
    );
  }
}
