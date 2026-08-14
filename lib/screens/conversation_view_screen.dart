import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sms_models.dart';
import '../services/mock_sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ConversationViewScreen extends StatefulWidget {
  final Conversation conversation;

  const ConversationViewScreen({super.key, required this.conversation});

  @override
  State<ConversationViewScreen> createState() => _ConversationViewScreenState();
}

class _ConversationViewScreenState extends State<ConversationViewScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MockSmsService _smsService = MockSmsService();

  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final canSend = _messageController.text.trim().isNotEmpty;
      if (canSend != _canSend) {
        setState(() => _canSend = canSend);
      }
    });
    // Auto scroll to bottom initially if there are messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_canSend) {
      _smsService.sendMessage(widget.conversation.id, _messageController.text.trim());
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: widget.conversation.avatarColor,
              radius: 18,
              child: Text(
                widget.conversation.senderName.substring(0, 1).toUpperCase(),
                style: AppTypography.bodyLg.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.conversation.senderName, style: AppTypography.headlineMd),
                Text(
                  widget.conversation.senderNumber,
                  style: AppTypography.labelMuted,
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: _smsService,
              builder: (context, _) {
                // Find the updated conversation in case messages were added
                final conv = _smsService.conversations.firstWhere(
                  (c) => c.id == widget.conversation.id,
                  orElse: () => widget.conversation,
                );
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.containerMargin),
                  itemCount: conv.messages.length,
                  itemBuilder: (context, index) {
                    final msg = conv.messages[index];
                    return _buildMessageBubble(msg, conv.isBankSender);
                  },
                );
              }
            ),
          ),
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            color: AppColors.surfaceContainerLowest,
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
                        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                        filled: true,
                        fillColor: AppColors.surfaceContainer,
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
                    backgroundColor: _canSend ? AppColors.smsPrimary : AppColors.surfaceContainerHigh,
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

  Widget _buildMessageBubble(Message msg, bool isBankSender) {
    final timeStr = DateFormat.jm().format(msg.timestamp);
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!msg.isMe && isBankSender)
              const Padding(
                padding: EdgeInsets.only(right: 4, bottom: 4),
                child: Icon(Icons.currency_rupee, size: 14, color: AppColors.outline),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: msg.isMe ? AppColors.smsPrimary : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.xl),
                    topRight: const Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(msg.isMe ? AppRadius.xl : 0),
                    bottomRight: Radius.circular(msg.isMe ? 0 : AppRadius.xl),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.text,
                      style: AppTypography.bodyLg.copyWith(
                        color: msg.isMe ? Colors.white : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      timeStr,
                      style: AppTypography.labelMuted.copyWith(
                        color: msg.isMe ? Colors.white70 : AppColors.outline,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
