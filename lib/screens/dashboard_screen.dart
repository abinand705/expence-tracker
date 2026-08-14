import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/dummy_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/transaction_card.dart';
import '../widgets/app_drawer.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = DummyData.getTransactions();
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
        title: const SizedBox.shrink(),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning, Abhinand',
                      style: AppTypography.headlineMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTotalBalanceCard(currencyFormatter),
                    const SizedBox(height: AppSpacing.md),
                    _buildStatsRow(),
                    const SizedBox(height: AppSpacing.md),
                    _buildSpendCategoriesCard(),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: AppTypography.headlineMd.copyWith(
                            color: AppColors.primaryContainer,
                          ),
                        ),
                        Text(
                          'SEE ALL',
                          style: AppTypography.labelCaps.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return TransactionCard(transaction: transactions[index]);
                  },
                  childCount: transactions.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBalanceCard(NumberFormat formatter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL BALANCE',
                style: AppTypography.labelCaps.copyWith(color: AppColors.onSurfaceVariant),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primaryContainer),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatter.format(45250.00),
            style: AppTypography.displayCurrency,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.level1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Spend',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '₹ 12,400',
                  style: AppTypography.headlineMd.copyWith(color: AppColors.errorRed, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: AppColors.errorRed, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '14% vs last month',
                      style: AppTypography.labelMuted.copyWith(color: AppColors.errorRed, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.level1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Saved',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.inversePrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '₹ 8,000',
                  style: AppTypography.headlineMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'On track',
                      style: AppTypography.labelMuted.copyWith(color: AppColors.successGreen, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpendCategoriesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spend Categories',
            style: AppTypography.headlineMd.copyWith(color: AppColors.primaryContainer),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: DonutChartPainter(),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: AppTypography.labelMuted.copyWith(fontSize: 10),
                        ),
                        Text(
                          '12.4k',
                          style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  children: [
                    _buildLegendItem('Food', '40%', const Color(0xFFC2185B)),
                    const SizedBox(height: AppSpacing.sm),
                    _buildLegendItem('Shopping', '35%', const Color(0xFF7B1FA2)),
                    const SizedBox(height: AppSpacing.sm),
                    _buildLegendItem('Bills', '25%', const Color(0xFF1976D2)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, String percentage, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        Text(
          percentage,
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    
    // Food (40%) - Pink
    final paintPink = Paint()
      ..color = const Color(0xFFC2185B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Shopping (35%) - Purple
    final paintPurple = Paint()
      ..color = const Color(0xFF7B1FA2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Bills (25%) - Blue
    final paintBlue = Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background circle (optional, but good for gaps)
    // The design looks like it doesn't have gaps but relies on overlapping or perfectly touching arcs.
    // StrokeCap.round creates rounded ends which means they overlap slightly if drawn sequentially.
    
    // We draw them in order: Pink (0 to 40%), Purple (40% to 75%), Blue (75% to 100%)
    // Start angle: -90 degrees (top)
    double startAngle = -pi / 2;

    // Draw Pink (40%)
    double sweepPink = 2 * pi * 0.40;
    canvas.drawArc(rect, startAngle, sweepPink, false, paintPink);
    
    // Draw Purple (35%)
    startAngle += sweepPink;
    double sweepPurple = 2 * pi * 0.35;
    canvas.drawArc(rect, startAngle, sweepPurple, false, paintPurple);
    
    // Draw Blue (25%)
    startAngle += sweepPurple;
    double sweepBlue = 2 * pi * 0.25;
    canvas.drawArc(rect, startAngle, sweepBlue, false, paintBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
