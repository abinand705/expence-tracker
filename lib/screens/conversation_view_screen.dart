import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sms_models.dart';
import '../services/mock_sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/expense_parser.dart';

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

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _currentMatchIndex = -1;
  List<int> _matchIndices = [];

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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_canSend) {
      _smsService.sendMessage(widget.conversation.id, _messageController.text.trim());
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  String _formatDateHeader(DateTime time) {
    final now = DateTime.now();
    if (now.year == time.year && now.month == time.month && now.day == time.day) {
      return 'Today';
    } else if (now.year == time.year && now.month == time.month && now.day - time.day == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, y').format(time);
    }
  }

  Conversation _getCurrentConv() {
    return _smsService.conversations.firstWhere(
      (c) => c.id == widget.conversation.id,
      orElse: () => widget.conversation,
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _matchIndices = [];
        _currentMatchIndex = -1;
      });
      return;
    }
    final conv = _getCurrentConv();
    final lowerQuery = query.toLowerCase();
    final matches = <int>[];
    for (int i = 0; i < conv.messages.length; i++) {
      if (conv.messages[i].text.toLowerCase().contains(lowerQuery)) {
        matches.add(i);
      }
    }
    setState(() {
      _matchIndices = matches;
      if (matches.isNotEmpty) {
        _currentMatchIndex = matches.length - 1; // latest
      } else {
        _currentMatchIndex = -1;
      }
    });
  }

  void _confirmBlock(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceBright,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Block this sender?', style: AppTypography.headlineMd),
        content: Text("You won't see new messages from them.", style: AppTypography.bodyLg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.bodyLg.copyWith(color: AppColors.primaryContainer)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _smsService.blockConversation(widget.conversation.id);
              Navigator.pop(context); // pop conv view
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showOptionsModal(BuildContext context) {
    final currentConv = _getCurrentConv();
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
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isSearching = true;
                  });
                  _searchFocusNode.requestFocus();
                },
              ),
              ListTile(
                leading: Icon(
                  currentConv.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  color: AppColors.primaryContainer,
                ),
                title: Text(
                  currentConv.isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                  style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _smsService.toggleMute(currentConv.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.primaryContainer),
                title: Text('Clear Chat', style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _smsService.deleteConversation(currentConv.id);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.errorRed),
                title: Text('Block', style: AppTypography.bodyLg.copyWith(color: AppColors.errorRed)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock(context);
                },
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
      appBar: _isSearching
          ? AppBar(
              backgroundColor: AppColors.surfaceContainerLowest,
              elevation: 1,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _performSearch('');
                  });
                },
              ),
              title: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _performSearch,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                ),
                style: AppTypography.bodyLg,
              ),
              actions: [
                if (_matchIndices.isNotEmpty) ...[
                  Center(
                    child: Text(
                      '${_currentMatchIndex + 1} of ${_matchIndices.length}',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, color: AppColors.onSurface),
                    onPressed: () {
                      if (_currentMatchIndex > 0) {
                        setState(() {
                          _currentMatchIndex--;
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.onSurface),
                    onPressed: () {
                      if (_currentMatchIndex < _matchIndices.length - 1) {
                        setState(() {
                          _currentMatchIndex++;
                        });
                      }
                    },
                  ),
                ],
              ],
            )
          : AppBar(
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
                final conv = _getCurrentConv();
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.containerMargin),
                  itemCount: conv.messages.length,
                  itemBuilder: (context, index) {
                    final msg = conv.messages[index];
                    return _buildMessageBubble(msg, conv.isBankSender, index, conv);
                  },
                );
              }
            ),
          ),
          // Input Area
          ListenableBuilder(
            listenable: _smsService,
            builder: (context, _) {
              final conv = _getCurrentConv();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!conv.isBankSender)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      child: Row(
                        children: ['Okay', 'Thanks!', 'Paid!', "I'll check"].map((text) {
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: ActionChip(
                              label: Text(text, style: AppTypography.bodyMd.copyWith(color: AppColors.primary)),
                              backgroundColor: AppColors.surfaceContainerHigh,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onPressed: () {
                                _messageController.text = text;
                                _sendMessage();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  else 
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      child: Row(
                        children: ['View Statement', 'Mark as Spam', 'Copy Account'].map((text) {
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: ActionChip(
                              label: Text(text, style: AppTypography.bodyMd.copyWith(color: AppColors.primary)),
                              backgroundColor: AppColors.surfaceContainerHigh,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$text clicked!')),
                                );
                              },
                            ),
                          );
                        }).toList(),
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
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isBankSender, int index, Conversation conv) {
    bool showDateHeader = false;
    if (index == 0) {
      showDateHeader = true;
    } else {
      final prevMsg = conv.messages[index - 1];
      if (prevMsg.timestamp.day != msg.timestamp.day ||
          prevMsg.timestamp.month != msg.timestamp.month ||
          prevMsg.timestamp.year != msg.timestamp.year) {
        showDateHeader = true;
      }
    }

    final timeStr = DateFormat.jm().format(msg.timestamp);
    final isHighlighted = _isSearching && _matchIndices.isNotEmpty && _currentMatchIndex != -1 && _matchIndices[_currentMatchIndex] == index;
    final bubbleColor = isHighlighted 
        ? AppColors.primaryContainer 
        : (msg.isMe ? AppColors.smsPrimary : AppColors.surfaceContainerHighest);
    final textColor = isHighlighted
        ? Colors.white
        : (msg.isMe ? Colors.white : AppColors.onSurface);
        
    final parsed = ExpenseParser.parse(msg.text);

    return Column(
      children: [
        if (showDateHeader) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(_formatDateHeader(msg.timestamp), style: AppTypography.labelMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Align(
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
                      color: bubbleColor,
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
                          style: AppTypography.bodyLg.copyWith(color: textColor),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          timeStr,
                          style: AppTypography.labelMuted.copyWith(
                            color: msg.isMe || isHighlighted ? Colors.white70 : AppColors.outline,
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
        ),
        if (!msg.isMe && isBankSender && parsed != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xl, bottom: AppSpacing.md),
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ₹${parsed.amount.toStringAsFixed(0)} to expenses!')),
                  );
                },
                icon: const Icon(Icons.add, size: 16, color: AppColors.onPrimaryContainer),
                label: Text('Add ₹${parsed.amount.toStringAsFixed(0)} to Expenses', style: AppTypography.labelMuted.copyWith(fontWeight: FontWeight.bold, color: AppColors.onPrimaryContainer)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer.withOpacity(0.15),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
