import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/sms_models.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'conversation_view_screen.dart';
import 'new_message_screen.dart';
import 'messages_settings_screen.dart';
import 'bin_screen.dart';
import '../services/sms_transaction_importer.dart';
import '../repositories/transaction_repository.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsInboxScreen extends StatefulWidget {
  const SmsInboxScreen({super.key});

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen> {
  final SmsService _smsService = SmsService();
  final TextEditingController _searchController = TextEditingController();
  bool _isSyncing = false;
  PermissionStatus? _smsPermissionStatus;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.sms.status;
    setState(() {
      _smsPermissionStatus = status;
    });
    if (status.isGranted) {
      _smsService.loadDeviceSms();
    }
  }

  Future<void> _requestPermission() async {
    if (_smsPermissionStatus == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
      return;
    }
    
    final status = await Permission.sms.request();
    setState(() {
      _smsPermissionStatus = status;
    });
    if (status.isGranted) {
      _smsService.loadDeviceSms();
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

  void _showConversationOptions(BuildContext context, Conversation conv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceBright,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: Icon(conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: AppColors.primaryContainer),
              title: Text(conv.isPinned ? 'Unpin' : 'Pin', style: AppTypography.bodyLg),
              onTap: () {
                Navigator.pop(context);
                _smsService.togglePin(conv.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.errorRed),
              title: Text('Delete', style: AppTypography.bodyLg.copyWith(color: AppColors.errorRed)),
              onTap: () {
                Navigator.pop(context);
                _smsService.deleteConversation(conv.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockedContacts(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return ListenableBuilder(
          listenable: _smsService,
          builder: (context, _) {
            final blocked = _smsService.blockedNumbers.toList();
            return AlertDialog(
              backgroundColor: AppColors.surfaceBright,
              title: Text('Blocked Contacts', style: AppTypography.headlineMd),
              content: SizedBox(
                width: double.maxFinite,
                child: blocked.isEmpty 
                  ? Text('No blocked contacts.', style: AppTypography.bodyLg)
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: blocked.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(blocked[index], style: AppTypography.bodyLg),
                          trailing: TextButton(
                            onPressed: () => _smsService.unblockNumber(blocked[index]),
                            child: Text('Unblock', style: AppTypography.bodyMd.copyWith(color: AppColors.primaryContainer)),
                          ),
                        );
                      },
                    ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: AppTypography.bodyLg.copyWith(color: AppColors.primaryContainer)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _syncTransactions() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final repo = TransactionRepository();
      final importer = SmsTransactionImporter(transactionRepo: repo);
      final summary = await importer.importAllBankMessages(_smsService.conversations);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$summary'),
          backgroundColor: AppColors.primaryContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sync transactions.'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Widget _buildPermissionUI() {
    if (_smsPermissionStatus == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final isPermanentlyDenied = _smsPermissionStatus == PermissionStatus.permanentlyDenied;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms_failed_outlined, size: 64, color: AppColors.outline),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'SMS Access Required',
              style: AppTypography.headlineMd,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPermanentlyDenied 
                ? 'SMS permission has been permanently denied. Please open Android settings to grant MoneyTrack access to read SMS.'
                : 'MoneyTrack needs SMS access to automatically read bank transactions and track your expenses.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
              ),
              child: Text(
                isPermanentlyDenied ? 'Open Settings' : 'Allow SMS Access',
                style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
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
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_smsPermissionStatus == PermissionStatus.granted)
            IconButton(
              icon: const Icon(Icons.sync, color: AppColors.primaryContainer),
              onPressed: _syncTransactions,
              tooltip: 'Sync Transactions',
            ),
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
              } else if (value == 'blocked') {
                _showBlockedContacts(context);
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
                value: 'blocked',
                child: Row(
                  children: [
                    const Icon(Icons.block, color: AppColors.onSurfaceVariant, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Blocked contacts', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface)),
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
      body: _smsPermissionStatus != PermissionStatus.granted
        ? _buildPermissionUI()
        : ListenableBuilder(
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
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final bool hasUnread = conv.unreadCount > 0;
                        final latestMsg = conv.latestMessage;
                        final parsed = conv.latestParsedExpense;
                        
                        return Dismissible(
                          key: Key(conv.id),
                          background: Container(
                            color: AppColors.primary,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: const Icon(Icons.mark_email_read, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: AppColors.errorRed,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              if (conv.unreadCount > 0) _smsService.markAsRead(conv.id);
                              return false;
                            }
                            return true;
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart) {
                              _smsService.deleteConversation(conv.id);
                            }
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.xs),
                            leading: CircleAvatar(
                              backgroundColor: conv.avatarColor,
                              child: Text(
                                conv.senderName.substring(0, 1).toUpperCase(),
                                style: AppTypography.headlineMd.copyWith(color: Colors.white),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    conv.senderName,
                                    style: AppTypography.bodyLg.copyWith(
                                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                if (conv.isPinned) const Icon(Icons.push_pin, size: 16, color: AppColors.outline),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                if (parsed != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.errorRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text('₹${parsed.amount.toStringAsFixed(0)}', style: AppTypography.labelMuted.copyWith(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                ],
                                Expanded(
                                  child: Text(
                                    latestMsg?.text ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMd.copyWith(
                                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w400,
                                      color: hasUnread ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (conv.isMuted) ...[
                                      const Icon(Icons.notifications_off, size: 14, color: AppColors.outline),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      latestMsg != null ? _formatTimestamp(latestMsg.timestamp) : '',
                                      style: AppTypography.labelMuted.copyWith(
                                        color: hasUnread ? AppColors.smsPrimary : AppColors.outline,
                                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.w400,
                                      ),
                                    ),
                                  ],
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
                            onLongPress: () => _showConversationOptions(context, conv),
                            onTap: () {
                              _smsService.markAsRead(conv.id);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ConversationViewScreen(conversation: conv)),
                              );
                            },
                          ),
                        ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05);
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
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceContainerLowest,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
      ),
    );
  }
}
