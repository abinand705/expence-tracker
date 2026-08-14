import 'package:flutter/material.dart';
import '../models/sms_models.dart';
import '../services/mock_sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'conversation_view_screen.dart';
import 'new_message_screen.dart';
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
    // Initialize dummy data if not already done
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
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0), // Padding to clear bottom nav
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewMessageScreen()),
            );
          },
          backgroundColor: AppColors.smsPrimary,
          icon: const Icon(Icons.message, color: Colors.white),
          label: Text('New Message', style: AppTypography.bodyMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      body: ListenableBuilder(
        listenable: _smsService,
        builder: (context, _) {
          final conversations = _smsService.filteredConversations;
          return Column(
            children: [
              // Search Bar
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
              // Filter Chips
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
              // List View
              Expanded(
                child: conversations.isEmpty 
                  ? Center(child: Text('No messages found.', style: AppTypography.bodyLg))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100), // For bottom nav padding
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
