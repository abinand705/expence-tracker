import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../models/transaction.dart';
import '../../services/analytics_service.dart';

class SpendCategoriesCard extends StatefulWidget {
  final List<Transaction> transactions;
  final AnalyticsService analyticsService;
  final DateTimeRange? expenseCycleRange;

  const SpendCategoriesCard({
    super.key,
    required this.transactions,
    required this.analyticsService,
    this.expenseCycleRange,
  });

  @override
  State<SpendCategoriesCard> createState() => _SpendCategoriesCardState();
}

class _SpendCategoriesCardState extends State<SpendCategoriesCard> {
  late Map<String, double> _totals;

  @override
  void initState() {
    super.initState();
    _calculateTotals();
  }

  @override
  void didUpdateWidget(covariant SpendCategoriesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transactions != oldWidget.transactions) {
      _calculateTotals();
    }
  }

  void _calculateTotals() {
    final now = DateTime.now();
    _totals = widget.expenseCycleRange != null
      ? widget.analyticsService.calculateCategoryTotals(
          widget.transactions,
          range: widget.expenseCycleRange,
        )
      : widget.analyticsService.calculateCategoryTotals(
          widget.transactions,
          month: now.month,
          year: now.year,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    double food = _totals['Food'] ?? 0;
    double shopping = _totals['Shopping'] ?? 0;
    double bills = _totals['Bills'] ?? 0;
    double others = _totals['Others'] ?? 0;

    double total = food + shopping + bills + others;
    final displayTotal = total;
    if (total == 0) total = 1; // prevent divide by zero

    final pFood = food / total;
    final pShop = shopping / total;
    final pBills = bills / total;
    final pOthers = others / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spend Categories',
            style: AppTypography.headlineMd.copyWith(color: cs.primaryContainer),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: DonutChartPainter(
                    foodPct: pFood,
                    shopPct: pShop,
                    billsPct: pBills,
                    othersPct: pOthers
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: AppTypography.labelMuted.copyWith(fontSize: 10, color: cs.onSurfaceVariant),
                        ),
                        Text(
                          displayTotal >= 1000 ? '${(displayTotal/1000).toStringAsFixed(1)}k' : displayTotal.toStringAsFixed(0),
                          style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
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
                    if (pFood > 0) ...[
                      _buildLegendItem(context, 'Food', '${(pFood * 100).toStringAsFixed(0)}%', const Color(0xFFC2185B)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (pShop > 0) ...[
                      _buildLegendItem(context, 'Shopping', '${(pShop * 100).toStringAsFixed(0)}%', const Color(0xFF7B1FA2)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (pBills > 0) ...[
                      _buildLegendItem(context, 'Bills', '${(pBills * 100).toStringAsFixed(0)}%', const Color(0xFF1976D2)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (pOthers > 0) ...[
                      _buildLegendItem(context, 'Others', '${(pOthers * 100).toStringAsFixed(0)}%', const Color(0xFFF57C00)),
                    ],
                    if (displayTotal == 0)
                      Text('No data this month', style: AppTypography.labelMuted.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String title, String percentage, Color color) {
    final cs = Theme.of(context).colorScheme;
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
              style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        Text(
          percentage,
          style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}


class DonutChartPainter extends CustomPainter {
  final double foodPct;
  final double shopPct;
  final double billsPct;
  final double othersPct;

  DonutChartPainter({
    required this.foodPct,
    required this.shopPct,
    required this.billsPct,
    required this.othersPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    
    final paintPink = Paint()..color = const Color(0xFFC2185B)..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    final paintPurple = Paint()..color = const Color(0xFF7B1FA2)..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    final paintBlue = Paint()..color = const Color(0xFF1976D2)..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    final paintOthers = Paint()..color = const Color(0xFFF57C00)..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;

    double startAngle = -pi / 2;

    if (foodPct > 0) {
      double sweep = 2 * pi * foodPct;
      canvas.drawArc(rect, startAngle, sweep, false, paintPink);
      startAngle += sweep;
    }
    
    if (shopPct > 0) {
      double sweep = 2 * pi * shopPct;
      canvas.drawArc(rect, startAngle, sweep, false, paintPurple);
      startAngle += sweep;
    }
    
    if (billsPct > 0) {
      double sweep = 2 * pi * billsPct;
      canvas.drawArc(rect, startAngle, sweep, false, paintBlue);
      startAngle += sweep;
    }
    
    if (othersPct > 0) {
      double sweep = 2 * pi * othersPct;
      canvas.drawArc(rect, startAngle, sweep, false, paintOthers);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
