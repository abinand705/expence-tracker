import 'package:flutter/material.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'conversation_view_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final SmsService _smsService = SmsService();

  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final canSend = _toController.text.trim().isNotEmpty && _messageController.text.trim().isNotEmpty;
      if (canSend != _canSend) {
        setState(() => _canSend = canSend);
      }
    });
    _toController.addListener(() {
      final canSend = _toController.text.trim().isNotEmpty && _messageController.text.trim().isNotEmpty;
      if (canSend != _canSend) {
        setState(() => _canSend = canSend);
      }
    });
  }

  @override
  void dispose() {
    _toController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_canSend) {
      final conv = _smsService.startOrSendToNumber(_toController.text.trim(), _messageController.text.trim());
      Navigator.pop(context);
      if (conv != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationViewScreen(conversation: conv)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        title: Text('New Conversation', style: AppTypography.headlineMd),
        
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.md),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Text('To:', style: AppTypography.bodyLg.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _toController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Type a name or phone number...',
                      hintStyle: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: AppTypography.bodyLg,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          const Spacer(),
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type an SMS message...',
                        hintStyle: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CircleAvatar(
                    backgroundColor: _canSend ? AppColors.smsPrimary : Theme.of(context).colorScheme.surface,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _canSend ? _sendMessage : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
