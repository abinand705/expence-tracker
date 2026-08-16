import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ComposeSmsScreen extends StatefulWidget {
  final String? initialRecipient;
  final String? initialMessage;

  const ComposeSmsScreen({super.key, this.initialRecipient, this.initialMessage});

  @override
  State<ComposeSmsScreen> createState() => _ComposeSmsScreenState();
}

class _ComposeSmsScreenState extends State<ComposeSmsScreen> {
  late final TextEditingController _recipientController;
  final TextEditingController _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _recipientController = TextEditingController(text: widget.initialRecipient ?? '');
    _messageController.text = widget.initialMessage ?? '';
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendSms() async {
    if (_formKey.currentState!.validate()) {
      final String recipient = _recipientController.text.trim();
      final String message = _messageController.text.trim();

      // Ensure proper URI encoding for the body
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: recipient,
        queryParameters: <String, String>{
          'body': message,
        },
      );

      try {
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open SMS composer on this device.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Compose Message', style: AppTypography.headlineMd),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.primaryContainer),
            onPressed: _sendSms,
            tooltip: 'Send via SMS App',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _recipientController,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    hintText: 'Enter phone number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a recipient number';
                    }
                    // Basic sanity check for numeric characters and '+'
                    final hasValidChars = RegExp(r'^[\+0-9\-\(\)\s]+$').hasMatch(value);
                    if (!hasValidChars) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: TextFormField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Type your message here...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Message cannot be empty';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: _sendSms,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open System SMS Composer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
