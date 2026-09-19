import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({
    required this.question,
    required this.answer,
  });
}

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    _emailController.text = user?.email ?? '';
  }

  static const List<FaqItem> _faqList = [
    FaqItem(
      question: 'How to link accounts?',
      answer:
          'MoneyTrack automatically discovers and matches your bank accounts from incoming transaction and balance SMS alerts using your bank name and account suffix (last 3–4 digits).\n\nYou can also manually add, edit, or link accounts at any time:\n1. Open the side menu (drawer) and tap "Accounts".\n2. Tap the "+" button to add a new bank account.\n3. Enter your account name, bank name, account number (or last 4 digits), and opening balance.\n4. When new bank SMS messages arrive, MoneyTrack will automatically map them to your matching account.',
    ),
    FaqItem(
      question: 'Is my data secure?',
      answer:
          'Your financial privacy and data security are our highest priorities:\n\n• Local On-Device Processing: All SMS parsing and transaction detection take place strictly on your device.\n• Private Cloud Storage: Only your synchronized expense records and account metadata are saved in your private Firebase Firestore database, protected by Firebase Authentication and user-level security rules.\n• No Sensitive Credentials: MoneyTrack never requests, reads, or stores your banking passwords, MPINs, debit card PINs, or full card numbers.',
    ),
    FaqItem(
      question: 'Troubleshooting SMS parsing',
      answer:
          'If incoming bank messages are not showing up as transactions:\n\n1. Check SMS Permission: Ensure SMS permission is granted in Android Settings > Apps > MoneyTrack > Permissions > SMS.\n2. Manual Rescan / Sync: Open the "Messages" screen and tap the Sync (refresh) icon in the top app bar to scan recent messages.\n3. Verify Sender & Format: MoneyTrack looks for recognized bank senders and financial keywords (e.g., "debited", "credited", "spent", "INR", "Rs.", or available balance).\n4. Account Suffix Match: Ensure your account in MoneyTrack ends with the same digits mentioned in the SMS (e.g., A/c XX544).\n5. Bank Statements: If SMS is unavailable, you can also import official bank statements (PDF, Excel, CSV) under "Statements".',
    ),
    FaqItem(
      question: 'Resetting PIN',
      answer:
          'If you have App Lock enabled and need to reset your security PIN:\n\n1. On the PIN entry screen, tap "Forgot PIN?" below the numeric keypad.\n2. Authenticate using your account credentials or biometric authentication (Fingerprint / Face Unlock).\n3. Once verified, navigate to Drawer > Settings > Security & App Lock to set a new 4-digit PIN.',
    ),
    FaqItem(
      question: 'How are duplicate transactions prevented?',
      answer:
          'MoneyTrack uses a centralized multi-level transaction identity system:\n\n• Reference IDs: If the bank SMS contains a reference identifier (UPI Ref, UTR, Txn ID, RRN), MoneyTrack maps it uniquely. Duplicate alerts for the same reference ID are automatically ignored.\n• Exact & Fallback Matching: Messages without reference IDs are checked against bank, account, amount, and exact timestamp before creating a transaction.\n• Idempotent Sync: Rescanning SMS or refreshing will never create duplicate expenses or double-count your balances.',
    ),
    FaqItem(
      question: 'How to import Bank Statements?',
      answer:
          'You can upload official bank statements in PDF, Excel (.xlsx), Word (.docx), or CSV formats:\n\n1. Open the drawer menu and select "Statements".\n2. Tap "Upload Statement" and choose the target bank account.\n3. Pick your statement file. MoneyTrack will parse transactions, verify opening/closing balances, skip duplicates, and update your account balance.',
    ),
    FaqItem(
      question: 'How to edit transaction titles and categories?',
      answer:
          'To customize your transactions:\n\n1. Tap any transaction on your Dashboard or Transactions list to open its details.\n2. Tap the Edit (pencil) icon next to the title to assign a custom merchant or description (e.g., "Amazon Shopping" or "Groceries").\n3. Tap on the Category chip to reassign it (Food, Bills, Shopping, Others).\n4. All user customizations are permanently preserved and will never be overwritten by future SMS syncs.',
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitMessage() async {
    final message = _messageController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }

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
      final apiKey = dotenv.env['FORMCONNECT_API_KEY'] ??
          const String.fromEnvironment('FORMCONNECT_API_KEY', defaultValue: 'fc_live_09a08edc9b883d8dcf9735c5a71d2099');
      final apiUrl = dotenv.env['FORMCONNECT_API_URL'] ??
          const String.fromEnvironment('FORMCONNECT_API_URL', defaultValue: 'https://formconnect.onrender.com');

      final uri = Uri.parse('$apiUrl/api/submit');

      final payload = {
        'apiKey': apiKey,
        'data': {
          'name': name,
          'email': email,
          'message': message,
          'project': 'MoneyTrack',
          if (user?.uid != null) 'userId': user!.uid,
        },
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Optional non-blocking background backup to Firestore if online
        FirebaseFirestore.instance.collection('support_messages').add({
          'userId': user?.uid,
          'name': name,
          'email': email,
          'message': message,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'submitted_to_formconnect',
        }).then((_) {}, onError: (_) {});

        if (mounted) {
          _messageController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent successfully! We will get back to you soon.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        String errorMsg = 'Failed to submit form (${response.statusCode})';
        try {
          final resJson = jsonDecode(response.body);
          if (resJson is Map && resJson['message'] != null) {
            errorMsg = resJson['message'].toString();
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission error: $e'),
            backgroundColor: AppColors.error,
          ),
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
    final filteredFaqs = _faqList.where((faq) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return faq.question.toLowerCase().contains(query) ||
             faq.answer.toLowerCase().contains(query);
    }).toList();

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
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search help articles...',
                hintStyle: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
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
            
            if (filteredFaqs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Text(
                    'No help articles found for "$_searchQuery"',
                    style: AppTypography.bodyMd.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...filteredFaqs.map((faq) => _buildFaqItem(faq.question, faq.answer)),
            
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
                  _buildTextField('Your name', controller: _nameController),
                  const SizedBox(height: AppSpacing.sm),
                  
                  _buildTextFieldLabel('Email Address'),
                  const SizedBox(height: AppSpacing.xs),
                  _buildTextField('Your email', controller: _emailController),
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
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String title, String answer) {
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
          iconColor: Theme.of(context).colorScheme.primary,
          collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Text(
                answer,
                style: AppTypography.bodyMd.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
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

