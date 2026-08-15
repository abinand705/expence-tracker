import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mock_sms_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class MyAccountsScreen extends StatelessWidget {
  const MyAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockSmsService(),
      builder: (context, _) {
        final accounts = MockSmsService().linkedAccounts;
        final totalNetWorth = accounts.fold(0.0, (sum, acc) => sum + acc.balance);
        final currencyFormatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
            title: Text('My Accounts', style: AppTypography.headlineMd),
            backgroundColor: AppColors.background,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNetWorthCard(context, currencyFormatter, totalNetWorth),
                const SizedBox(height: AppSpacing.md),
                _buildStatsCard(),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Linked Accounts',
                  style: AppTypography.headlineMd.copyWith(color: AppColors.primaryContainer),
                ),
                const SizedBox(height: AppSpacing.md),
                if (accounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('No accounts found from messages.', style: AppTypography.bodyLg),
                  )
                else
                  ...accounts.map((acc) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _buildLinkedAccountCard(
                          bankName: acc.bankName,
                          accountType: acc.accountType,
                          accountNumber: acc.accountNumber,
                          balance: currencyFormatter.format(acc.balance),
                          accentColor: acc.accentColor,
                          icon: Icons.account_balance,
                        ),
                      )).toList(),
                const SizedBox(height: AppSpacing.lg),
                _buildLinkAnotherBankButton(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetWorthCard(BuildContext context, NumberFormat formatter, double totalNetWorth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL NET WORTH',
            style: AppTypography.labelCaps.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatter.format(totalNetWorth),
            style: AppTypography.displayCurrency.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    MockSmsService().refreshAccounts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Balances updated from recent messages.')),
                    );
                  },
                  icon: const Icon(Icons.sync, color: AppColors.onPrimary, size: 16),
                  label: Text('Refresh Balances', style: AppTypography.labelCaps.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddAccountModal(context),
                  icon: const Icon(Icons.add, color: AppColors.onSurfaceVariant, size: 16),
                  label: Text('Add Manual Account', style: AppTypography.labelCaps.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.surfaceContainerHigh),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up, color: AppColors.successGreen, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Change', style: AppTypography.labelMuted),
                  Text('+\$2,450.00', style: AppTypography.bodyLg.copyWith(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(color: AppColors.surfaceContainerHigh),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending Dues', style: AppTypography.labelMuted),
                  Text('\$345.50', style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAccountCard({
    required String bankName,
    required String accountType,
    required String accountNumber,
    required String balance,
    required Color accentColor,
    required IconData icon,
    bool isNegative = false,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.level1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 4)),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bankName, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryContainer)),
                    const SizedBox(height: 2),
                    Text(
                      '$accountType • $accountNumber',
                      style: AppTypography.labelMuted.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balance,
                    style: AppTypography.headlineMd.copyWith(
                      color: isNegative ? AppColors.errorRed : AppColors.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.labelMuted.copyWith(fontSize: 10)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkAnotherBankButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddAccountModal(context),
      child: CustomPaint(
        painter: DashedRectPainter(color: AppColors.outlineVariant, strokeWidth: 1, gap: 5),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          color: Colors.transparent, // Ensures the whole area is clickable
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Link another bank', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryContainer)),
              const SizedBox(height: 4),
              Text('Securely connect via Open Banking', style: AppTypography.labelMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAccountModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceBright,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Manual Account', style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Account No (Last 4 digits)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(),
                ),
                items: ['Savings', 'Current', 'Credit Card', 'Loan']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Bank Statement (Optional)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account added successfully.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Save Account'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({required this.color, required this.strokeWidth, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(12)));

    final Path dashedPath = Path();
    bool draw = true;
    double distance = 0;
    
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final double nextDistance = distance + gap;
        if (draw) {
          dashedPath.addPath(
            metric.extractPath(distance, nextDistance),
            Offset.zero,
          );
        }
        distance = nextDistance;
        draw = !draw;
      }
      distance = 0;
    }
    
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
