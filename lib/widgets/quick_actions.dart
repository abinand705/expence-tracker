import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onExpenseTap;
  final VoidCallback onIncomeTap;
  final VoidCallback onTransferTap;

  const QuickActions({
    super.key,
    required this.onExpenseTap,
    required this.onIncomeTap,
    required this.onTransferTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // + Expense
        Expanded(
          child: _buildActionButton(
            label: '+ Expense',
            textColor: const Color(0xFFDC2626),
            borderColor: const Color(0xFFFECACA),
            onTap: onExpenseTap,
          ),
        ),
        const SizedBox(width: 12),
        // + Income
        Expanded(
          child: _buildActionButton(
            label: '+ Income',
            textColor: const Color(0xFF16A34A),
            borderColor: const Color(0xFFBBF7D0),
            onTap: onIncomeTap,
          ),
        ),
        const SizedBox(width: 12),
        // Transfer
        Expanded(
          child: _buildActionButton(
            label: 'Transfer',
            textColor: const Color(0xFF1D4ED8),
            borderColor: const Color(0xFFBFDBFE),
            onTap: onTransferTap,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
