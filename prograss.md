# Messages and Conversation Pages Progress

This document tracks the implementations and details for the messages and conversation pages in the expense tracker application.

## Available and Functioning Items

### SMS Inbox Screen (`sms_inbox_screen.dart`)
- **Conversation List**: Displays a list of all SMS conversations using `MockSmsService`.
- **Search Functionality**: A search bar that filters messages and contacts in real-time.
- **Filters**: Filter chips for categorizing messages:
  - All
  - Unread
  - Transactions
  - Personal
- **Unread Badges**: Highlights unread conversations and displays the unread message count.
- **Popup Menu Actions**: 
  - New message
  - Mark all as read
  - Message settings
  - Bin
- **Navigation**: Tapping a conversation opens the `ConversationViewScreen`.

### Conversation View Screen (`conversation_view_screen.dart`)
- **Message Bubbles**: Displays messages in a chat UI with different styling for sent (isMe) and received messages.
- **Bank Sender Indicator**: Displays a currency icon for messages from bank senders.
- **Send Message**: Input field to type and send new SMS messages.
- **Auto-scroll**: Automatically scrolls to the bottom of the chat when opened or when a new message is sent.
- **Options Modal**: A bottom sheet with options to:
  - Search
  - Mute Notifications
  - Clear Chat (Functional: deletes the conversation)
  - Block

## Items Pending or Not Implemented

### SMS Inbox Screen
- **New message**: Navigation is wired to `NewMessageScreen`, but sending new messages to numbers outside existing threads might require backend/service wiring.
- **Message settings**: Navigation is wired to `MessagesSettingsScreen`, but specific settings logic (theme, notifications, auto-delete, etc.) is pending implementation.
- **Bin**: Navigation is wired to `BinScreen`, but the recycling bin logic, restoring deleted messages, and permanent deletion logic is pending.

### Conversation View Screen
- **Search (Options Modal)**: Option exists in the bottom sheet but currently only dismisses the modal without performing a search within the conversation.
- **Mute Notifications (Options Modal)**: Option exists but does not actually toggle mute state for the conversation.
- **Block (Options Modal)**: Option exists but does not actually block the contact or filter future messages.

---

## Full Code Base for Pages

### `lib/screens/sms_inbox_screen.dart`
```dart
import 'package:flutter/material.dart';
import '../models/sms_models.dart';
import '../services/mock_sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'conversation_view_screen.dart';
import 'new_message_screen.dart';
import 'messages_settings_screen.dart';
import 'bin_screen.dart';
import 'package:intl/intl.dart';

class SmsInboxScreen extends StatefulWidget {
  const SmsInboxScreen({super.key});

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen> {
  final MockSmsService _smsService = MockSmsService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_smsService.conversations.isEmpty) {
      _smsService.initializeDummyData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays == 0 && now.day == time.day) {
      return DateFormat.jm().format(time);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Text('Messages', style: AppTypography.headlineMd),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.onSurface),
            color: AppColors.surfaceBright,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            onSelected: (value) {
              if (value == 'new') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NewMessageScreen()));
              } else if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesSettingsScreen()));
              } else if (value == 'read') {
                _smsService.markAllAsRead();
              } else if (value == 'bin') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BinScreen()));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'new',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, color: AppColors.onSurfaceVariant, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('New message', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'read',
                child: Row(
                  children: [
                    const Icon(Icons.checklist, color: AppColors.onSurfaceVariant, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Mark all as read', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, color: AppColors.onSurfaceVariant, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Message settings', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'bin',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Bin', style: AppTypography.bodyMd.copyWith(color: AppColors.errorRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _smsService,
        builder: (context, _) {
          final conversations = _smsService.filteredConversations;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.sm),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _smsService.setSearchQuery(value),
                  decoration: InputDecoration(
                    hintText: 'Search messages, contacts...',
                    hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                    prefixIcon: const Icon(Icons.search, color: AppColors.outline),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                  children: [
                    _buildFilterChip('All', SmsFilter.all),
                    _buildFilterChip('Unread', SmsFilter.unread),
                    _buildFilterChip('Transactions', SmsFilter.transactions),
                    _buildFilterChip('Personal', SmsFilter.personal),
                  ],
                ),
              ),
              Expanded(
                child: conversations.isEmpty 
                  ? Center(child: Text('No messages found.', style: AppTypography.bodyLg))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final bool hasUnread = conv.unreadCount > 0;
                        final latestMsg = conv.latestMessage;
                        
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.xs),
                          leading: CircleAvatar(
                            backgroundColor: conv.avatarColor,
                            child: Text(
                              conv.senderName.substring(0, 1).toUpperCase(),
                              style: AppTypography.headlineMd.copyWith(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            conv.senderName,
                            style: AppTypography.bodyLg.copyWith(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                              color: AppColors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            latestMsg?.text ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMd.copyWith(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w400,
                              color: hasUnread ? AppColors.onSurface : AppColors.onSurfaceVariant,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                latestMsg != null ? _formatTimestamp(latestMsg.timestamp) : '',
                                style: AppTypography.labelMuted.copyWith(
                                  color: hasUnread ? AppColors.smsPrimary : AppColors.outline,
                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.w400,
                                ),
                              ),
                              if (hasUnread) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.smsPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    conv.unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ]
                            ],
                          ),
                          onTap: () {
                            _smsService.markAsRead(conv.id);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ConversationViewScreen(conversation: conv)),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, SmsFilter filter) {
    final isSelected = _smsService.currentFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          label,
          style: AppTypography.bodyMd.copyWith(
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => _smsService.setFilter(filter),
        selectedColor: AppColors.smsPrimary,
        backgroundColor: AppColors.surfaceContainerLowest,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: BorderSide(
            color: isSelected ? AppColors.smsPrimary : AppColors.outlineVariant,
          ),
        ),
      ),
    );
  }
}
```

### `lib/screens/conversation_view_screen.dart`
```dart
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

  void _showOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBright,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                leading: const Icon(Icons.search, color: AppColors.primaryContainer),
                title: Text('Search', style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined, color: AppColors.primaryContainer),
                title: Text('Mute Notifications', style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.primaryContainer),
                title: Text('Clear Chat', style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _smsService.deleteConversation(widget.conversation.id);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.errorRed),
                title: Text('Block', style: AppTypography.bodyLg.copyWith(color: AppColors.errorRed)),
                onTap: () => Navigator.pop(context),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Divider(color: AppColors.outlineVariant, height: 24),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: AppTypography.bodyLg.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.onSurface),
            onPressed: () => _showOptionsModal(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: _smsService,
              builder: (context, _) {
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
```
