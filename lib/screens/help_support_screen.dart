import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message to send.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? 'Anonymous';
      final userEmail = user?.email ?? 'No email';

      await FirebaseFirestore.instance.collection('support_messages').add({
        'userId': user?.uid,
        'name': userName,
        'email': userEmail,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'new',
      });

      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully. We will get back to you soon!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'User Name';
    final userEmail = user?.email ?? 'user@example.com';

    return Scaffold(
      
      appBar: AppBar(
        title: Text('Help & Support', style: AppTypography.headlineMd),
        centerTitle: true,
        
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search help articles...',
                hintStyle: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.surface),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.surface),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // FAQ Section
            Text('Frequently Asked Questions', style: AppTypography.headlineMd.copyWith(fontSize: 18)),
            const SizedBox(height: AppSpacing.md),
            
            _buildFaqItem('How to link accounts?'),
            _buildFaqItem('Is my data secure?'),
            _buildFaqItem('Troubleshooting SMS parsing'),
            _buildFaqItem('Resetting PIN'),
            
            const SizedBox(height: AppSpacing.lg),

            // Contact Support Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.surface),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact Support', style: AppTypography.headlineMd.copyWith(fontSize: 18)),
                  const SizedBox(height: AppSpacing.md),
                  
                  _buildTextFieldLabel('Name'),
                  const SizedBox(height: AppSpacing.xs),
                  _buildTextField(userName, readOnly: true),
                  const SizedBox(height: AppSpacing.sm),
                  
                  _buildTextFieldLabel('Email Address'),
                  const SizedBox(height: AppSpacing.xs),
                  _buildTextField(userEmail, readOnly: true),
                  const SizedBox(height: AppSpacing.sm),
                  
                  _buildTextFieldLabel('Message'),
                  const SizedBox(height: AppSpacing.xs),
                  _buildTextField('Describe your issue...', maxLines: 4, controller: _messageController),
                  const SizedBox(height: AppSpacing.lg),
                  
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitMessage,
                    icon: _isSubmitting 
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                          )
                        : const Icon(Icons.send, color: AppColors.onPrimary, size: 18),
                    label: Text(
                      _isSubmitting ? 'Sending...' : 'Send Message', 
                      style: AppTypography.bodyLg.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // View on GitHub button
            Center(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.code, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                label: Text('View on GitHub', style: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.surface),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.surface),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
          iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Text(
                'This is a placeholder answer for the frequently asked question.',
                style: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextFieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.labelCaps.copyWith(color: Theme.of(context).colorScheme.primaryContainer, fontWeight: FontWeight.bold),
    );
  }
  
  Widget _buildTextField(String hint, {int maxLines = 1, bool readOnly = false, TextEditingController? controller}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.surface),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.surface),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
