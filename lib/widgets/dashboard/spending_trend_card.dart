import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart' hide TextDirection;
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../models/transaction.dart';
import '../../models/trend_data.dart';
import '../../services/analytics_service.dart';

class SpendingTrendCard extends StatefulWidget {
  final List<Transaction> transactions;
  final AnalyticsService analyticsService;

  const SpendingTrendCard({
    super.key,
    required this.transactions,
    required this.analyticsService,
  });

  @override
  State<SpendingTrendCard> createState() => _SpendingTrendCardState();
}

class _SpendingTrendCardState extends State<SpendingTrendCard> {
  TrendPeriod _selectedTrendPeriod = TrendPeriod.month;
  DateTimeRange? _customDateRange;
  late List<TrendData> _trendData;

  @override
  void initState() {
    super.initState();
    _calculateTrendData();
  }

  @override
  void didUpdateWidget(covariant SpendingTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transactions != oldWidget.transactions) {
      _calculateTrendData();
    }
  }

  void _calculateTrendData() {
    _trendData = widget.analyticsService.calculateTrendData(
      widget.transactions, 
      _selectedTrendPeriod, 
      DateTime.now(), 
      _customDateRange,
    );
  }

  String _getFilterName(TrendPeriod period) {
    switch (period) {
      case TrendPeriod.day: return 'Day';
      case TrendPeriod.week: return 'Week';
      case TrendPeriod.month: return 'Month';
      case TrendPeriod.year: return 'Year';
      case TrendPeriod.custom: return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = TrendPeriod.values;

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
            'Spending Trends',
            style: AppTypography.headlineMd.copyWith(color: AppColors.primaryContainer),
          ),
          const SizedBox(height: AppSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = _selectedTrendPeriod == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () async {
                      if (filter == TrendPeriod.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDateRange: _customDateRange,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  onSurface: AppColors.onSurface,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _customDateRange = picked;
                            _selectedTrendPeriod = filter;
                            _calculateTrendData();
                          });
                        }
                      } else {
                        setState(() {
                          _selectedTrendPeriod = filter;
                          _calculateTrendData();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getFilterName(filter),
                        style: AppTypography.bodyMd.copyWith(
                          color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: TrendChartPainter(
                dataPoints: _trendData,
              ),
              size: const Size(double.infinity, 150),
            ),
          ),
        ],
      ),
    );
  }
}

class TrendChartPainter extends CustomPainter {
  final List<TrendData> dataPoints;
  
  TrendChartPainter({required this.dataPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paintGrid = Paint()
      ..color = AppColors.surfaceContainerHigh
      ..strokeWidth = 1;
    final textStyle = AppTypography.labelMuted.copyWith(fontSize: 10, color: AppColors.outline);

    // Calculate Max Y
    double maxVal = dataPoints.fold(0.0, (m, v) => v.amount > m ? v.amount : m);
    if (maxVal == 0) maxVal = 1000; // sensible default if all 0

    // Determine Y labels (max, 2/3, 1/3)
    final formatCurrency = NumberFormat.compactCurrency(symbol: '₹');
    final yLabels = [
      formatCurrency.format(maxVal),
      formatCurrency.format(maxVal * 0.66),
      formatCurrency.format(maxVal * 0.33),
    ];

    final startX = 35.0; // Extra room for Y-axis labels
    
    for (int i = 0; i < 3; i++) {
      final y = (size.height - 30) * (i / 3) + 20;
      canvas.drawLine(Offset(startX, y), Offset(size.width, y), paintGrid);
      
      final textSpan = TextSpan(text: yLabels[i], style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    final path = Path();
    final paintLine = Paint()
      ..color = AppColors.primaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final stepX = dataPoints.length > 1 ? (size.width - startX) / (dataPoints.length - 1) : 0.0;
    
    // Draw X labels
    for (int i = 0; i < dataPoints.length; i++) {
      // Don't clutter X labels if too many points
      if (dataPoints.length > 15 && i % (dataPoints.length ~/ 7) != 0 && i != dataPoints.length - 1) {
        continue;
      }
      final x = startX + i * stepX;
      final textSpan = TextSpan(text: dataPoints[i].label, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      // Ensure label doesn't overflow right edge
      double renderX = x - (textPainter.width / 2);
      if (renderX < startX) renderX = startX;
      if (renderX + textPainter.width > size.width) renderX = size.width - textPainter.width;
      
      textPainter.paint(canvas, Offset(renderX, size.height - 15));
    }

    // Normalize dataPoints
    final normalizedData = dataPoints.map((v) => v.amount / maxVal).toList();

    double mapY(double value) {
      return (size.height - 30) - (value * (size.height - 50));
    }

    if (normalizedData.isNotEmpty) {
      path.moveTo(startX, mapY(normalizedData[0]));
      
      for (int i = 0; i < normalizedData.length - 1; i++) {
        final p0 = Offset(startX + i * stepX, mapY(normalizedData[i]));
        final p1 = Offset(startX + (i + 1) * stepX, mapY(normalizedData[i + 1]));
        
        final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
        
        path.cubicTo(
          controlPointX, p0.dy,
          controlPointX, p1.dy,
          p1.dx, p1.dy,
        );
      }
      
      canvas.drawPath(path, paintLine);
    }
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    if (oldDelegate.dataPoints.length != dataPoints.length) return true;
    for (int i=0; i<dataPoints.length; i++) {
      if (oldDelegate.dataPoints[i].amount != dataPoints[i].amount || 
          oldDelegate.dataPoints[i].label != dataPoints[i].label) {
        return true;
      }
    }
    return false;
  }
}
