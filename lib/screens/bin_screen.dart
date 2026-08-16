import 'package:flutter/material.dart';
import '../services/sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'package:intl/intl.dart';

class BinScreen extends StatefulWidget {
  const BinScreen({super.key});

  @override
  State<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends State<BinScreen> {
  final SmsService _smsService = SmsService();
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    // Automatically clean up old bin messages when this screen is opened
    _smsService.cleanUpBin();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _recoverSelected() {
    if (_selectedIds.isNotEmpty) {
      _smsService.recoverConversations(_selectedIds.toList());
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected messages recovered')),
      );
    }
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

  void _confirmPermanentDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceBright,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Permanently Delete?', style: AppTypography.headlineMd),
        content: Text('This conversation will be permanently deleted and cannot be recovered.', style: AppTypography.bodyLg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.bodyLg.copyWith(color: AppColors.primaryContainer)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _smsService.permanentlyDeleteConversation(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Bin',
          style: AppTypography.headlineMd,
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                });
              },
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _smsService,
        builder: (context, _) {
          final deletedConvs = _smsService.deletedConversations;
          
          if (deletedConvs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_outline, size: 64, color: AppColors.outline),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Bin is empty',
                    style: AppTypography.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Deleted messages will be stored here.',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.sm),
                child: Text(
                  'Messages in the bin will be permanently deleted after 1 month.',
                  style: AppTypography.labelMuted.copyWith(color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: deletedConvs.length,
                  itemBuilder: (context, index) {
                    final conv = deletedConvs[index];
                    final isSelected = _selectedIds.contains(conv.id);
                    final latestMsg = conv.latestMessage;
                    return Dismissible(
                      key: Key(conv.id),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: AppColors.primary,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: const Icon(Icons.restore, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        _smsService.recoverConversations([conv.id]);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Conversation restored')),
                        );
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin, vertical: AppSpacing.xs),
                        selected: isSelected,
                        selectedTileColor: AppColors.primaryContainer.withValues(alpha: 0.1),
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(conv.id),
                                activeColor: AppColors.primary,
                              )
                            : CircleAvatar(
                                backgroundColor: conv.avatarColor.withValues(alpha: 0.5),
                                child: Text(
                                  conv.senderName.substring(0, 1).toUpperCase(),
                                  style: AppTypography.headlineMd.copyWith(color: Colors.white),
                                ),
                              ),
                        title: Text(
                          conv.senderName,
                          style: AppTypography.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                        subtitle: Text(
                          latestMsg?.text ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              latestMsg != null ? _formatTimestamp(latestMsg.timestamp) : '',
                              style: AppTypography.labelMuted,
                            ),
                            if (!_isSelectionMode) ...[
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: AppColors.errorRed, size: 20),
                                onPressed: () => _confirmPermanentDelete(context, conv.id),
                              ),
                            ]
                          ],
                        ),
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelection(conv.id);
                          }
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(conv.id);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _isSelectionMode && _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ElevatedButton.icon(
                  onPressed: _recoverSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                  icon: const Icon(Icons.restore),
                  label: Text('Recover Selected', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )
          : null,
    );
  }
}
