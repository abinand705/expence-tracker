import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bank_statement.dart';
import '../../models/account.dart';
import '../../services/bank_statement_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

import 'package:firebase_auth/firebase_auth.dart';

class ImportStatementPreviewScreen extends StatefulWidget {
  final Account account;
  final ParsedBankStatement parsedStatement;
  final String fileName;
  final String fileType;

  const ImportStatementPreviewScreen({
    super.key,
    required this.account,
    required this.parsedStatement,
    required this.fileName,
    required this.fileType,
  });

  @override
  State<ImportStatementPreviewScreen> createState() => _ImportStatementPreviewScreenState();
}

class _ImportStatementPreviewScreenState extends State<ImportStatementPreviewScreen> {
  final BankStatementService _bankStatementService = BankStatementService();
  bool _isImporting = false;

  void _importStatement() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final result = await _bankStatementService.importStatement(
        user.uid,
        widget.account,
        widget.parsedStatement,
        widget.fileName,
        widget.fileType,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Statement Imported'),
            content: Text(
              'Transactions scanned: ${widget.parsedStatement.transactions.length}\n'
              'New transactions: ${result['newTransactions']}\n'
              'Duplicates skipped: ${result['duplicatesSkipped']}\n\n'
              'Balance updated to: ₹${widget.parsedStatement.closingBalance?.toStringAsFixed(2) ?? '0.00'}'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close preview
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statement Preview'),
      ),
      body: _isImporting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  color: AppColors.surfaceContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Bank', widget.parsedStatement.bankName ?? widget.account.bankName),
                      _buildInfoRow('Account', '••••${widget.parsedStatement.accountLast4 ?? widget.account.accountNumber.substring(widget.account.accountNumber.length > 4 ? widget.account.accountNumber.length - 4 : 0)}'),
                      _buildInfoRow('Period', '${widget.parsedStatement.statementStartDate != null ? dateFormatter.format(widget.parsedStatement.statementStartDate!) : 'Unknown'} - ${widget.parsedStatement.statementEndDate != null ? dateFormatter.format(widget.parsedStatement.statementEndDate!) : 'Unknown'}'),
                      if (widget.parsedStatement.openingBalance != null)
                        _buildInfoRow('Opening Balance', currencyFormatter.format(widget.parsedStatement.openingBalance)),
                      if (widget.parsedStatement.closingBalance != null)
                        _buildInfoRow('Closing Balance', currencyFormatter.format(widget.parsedStatement.closingBalance)),
                      _buildInfoRow('Transactions', widget.parsedStatement.transactions.length.toString()),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.parsedStatement.transactions.length > 100 ? 100 : widget.parsedStatement.transactions.length, // Limit sample size for perf
                    itemBuilder: (context, index) {
                      final t = widget.parsedStatement.transactions[index];
                      return ListTile(
                        title: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(dateFormatter.format(t.date)),
                        trailing: Text(
                          t.debit > 0 ? '-${currencyFormatter.format(t.debit)}' : '+${currencyFormatter.format(t.credit)}',
                          style: TextStyle(
                            color: t.debit > 0 ? AppColors.errorRed : AppColors.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _importStatement,
                          child: const Text('Import Statement'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
          Text(value, style: const TextStyle(color: AppColors.onSurface)),
        ],
      ),
    );
  }
}
