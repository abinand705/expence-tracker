import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:math';
import '../services/mock_sms_service.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/transaction_card.dart';
import '../widgets/app_drawer.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAllClicked;

  const DashboardScreen({
    super.key,
    this.onSeeAllClicked,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedTrendFilter = 'Month';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockSmsService(),
      builder: (context, _) {
        final allTransactions = MockSmsService().parsedTransactions;
        final transactions = allTransactions.take(3).toList();
        final currencyFormatter = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

        final now = DateTime.now();
        final hour = now.hour;
        String greeting = 'Good evening, Abhinand';
        if (hour < 12) greeting = 'Good morning, Abhinand';
        else if (hour < 17) greeting = 'Good afternoon, Abhinand';
        
        final accounts = MockSmsService().linkedAccounts;
        final totalBalance = accounts.fold(0.0, (sum, acc) => sum + acc.balance);

        final currentMonth = now.month;
        final currentYear = now.year;
        final currentMonthSpend = allTransactions
            .where((t) => t.date.month == currentMonth && t.date.year == currentYear && t.type == TransactionType.expense)
            .fold(0.0, (sum, t) => sum + t.amount);
            
        final lastMonth = currentMonth == 1 ? 12 : currentMonth - 1;
        final lastMonthYear = currentMonth == 1 ? currentYear - 1 : currentYear;
        final lastMonthSpend = allTransactions
            .where((t) => t.date.month == lastMonth && t.date.year == lastMonthYear && t.type == TransactionType.expense)
            .fold(0.0, (sum, t) => sum + t.amount);
            
        final spendChange = lastMonthSpend == 0 ? 0.0 : ((currentMonthSpend - lastMonthSpend) / lastMonthSpend) * 100;
        
        final monthlyTarget = MockSmsService().monthlyTargetAmount;

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
      body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: AppTypography.headlineMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTotalBalanceCard(currencyFormatter, totalBalance),
                    const SizedBox(height: AppSpacing.md),
                    _buildStatsRow(context, currencyFormatter, currentMonthSpend, spendChange, monthlyTarget),
                    const SizedBox(height: AppSpacing.md),
                    _buildSpendingTrendsCard(allTransactions),
                    const SizedBox(height: AppSpacing.md),
                    _buildSpendCategoriesCard(allTransactions, currencyFormatter),
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
                        GestureDetector(
                          onTap: widget.onSeeAllClicked,
                          child: Text(
                            'SEE ALL',
                            style: AppTypography.labelCaps.copyWith(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
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
      );
    });
  }

  Widget _buildTotalBalanceCard(NumberFormat formatter, double totalBalance) {
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
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primaryContainer),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatter.format(totalBalance),
            style: AppTypography.displayCurrency,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, NumberFormat formatter, double currentSpend, double spendChange, double target) {
    final bool isSpendUp = spendChange > 0;
    final bool isWithinTarget = currentSpend <= target;
    final double targetRemaining = target - currentSpend;
    
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
                  formatter.format(currentSpend),
                  style: AppTypography.headlineMd.copyWith(
                    color: isWithinTarget ? AppColors.onSurface : AppColors.errorRed, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(isSpendUp ? Icons.trending_up : Icons.trending_down, 
                      color: isSpendUp ? AppColors.errorRed : AppColors.successGreen, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${spendChange.abs().toStringAsFixed(1)}% vs last month',
                      style: AppTypography.labelMuted.copyWith(
                        color: isSpendUp ? AppColors.errorRed : AppColors.successGreen, 
                        fontSize: 10
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: GestureDetector(
            onDoubleTap: () => _showTargetModal(context, target),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: isWithinTarget ? AppColors.primary : AppColors.errorRed,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.level1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWithinTarget ? 'Target Remaining' : 'Over Target',
                    style: AppTypography.bodyMd.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    formatter.format(targetRemaining.abs()),
                    style: AppTypography.headlineMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(isWithinTarget ? Icons.check_circle_outline : Icons.warning_amber_rounded, 
                        color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        isWithinTarget ? 'On track' : 'Exceeded',
                        style: AppTypography.labelMuted.copyWith(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTargetModal(BuildContext context, double currentTarget) {
    final controller = TextEditingController(text: currentTarget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceBright,
          title: Text('Set Monthly Target', style: AppTypography.headlineMd),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: AppTypography.bodyLg),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  MockSmsService().setMonthlyTargetAmount(val);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpendingTrendsCard(List<Transaction> transactions) {
    final filters = ['Day', 'Week', 'Month', 'Year', 'Custom'];
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
                final isSelected = _selectedTrendFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () async {
                      if (filter == 'Custom') {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
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
                            _selectedTrendFilter = filter;
                          });
                        }
                      } else {
                        setState(() {
                          _selectedTrendFilter = filter;
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
                        filter,
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
              painter: TrendChartPainter(filter: _selectedTrendFilter, transactions: transactions),
              size: const Size(double.infinity, 150),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendCategoriesCard(List<Transaction> allTransactions, NumberFormat formatter) {
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;
    
    double food = 0, shopping = 0, bills = 0, others = 0;
    for (var t in allTransactions) {
      if (t.type != TransactionType.expense || t.date.month != currentMonth || t.date.year != currentYear) continue;
      if (t.category == 'Food') food += t.amount;
      else if (t.category == 'Shopping') shopping += t.amount;
      else if (t.category == 'Bills') bills += t.amount;
      else others += t.amount;
    }
    
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
                          style: AppTypography.labelMuted.copyWith(fontSize: 10),
                        ),
                        Text(
                          displayTotal >= 1000 ? '${(displayTotal/1000).toStringAsFixed(1)}k' : displayTotal.toStringAsFixed(0),
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
                    if (pFood > 0) ...[
                      _buildLegendItem('Food', '${(pFood * 100).toStringAsFixed(0)}%', const Color(0xFFC2185B)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (pShop > 0) ...[
                      _buildLegendItem('Shopping', '${(pShop * 100).toStringAsFixed(0)}%', const Color(0xFF7B1FA2)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (pBills > 0) ...[
                      _buildLegendItem('Bills', '${(pBills * 100).toStringAsFixed(0)}%', const Color(0xFF1976D2)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (pOthers > 0) ...[
                      _buildLegendItem('Others', '${(pOthers * 100).toStringAsFixed(0)}%', const Color(0xFFF57C00)),
                    ],
                    if (displayTotal == 0)
                      Text('No data this month', style: AppTypography.labelMuted),
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

    // Others - Orange
    final paintOthers = Paint()
      ..color = const Color(0xFFF57C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

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

class TrendChartPainter extends CustomPainter {
  final String filter;
  final List<Transaction> transactions;
  
  TrendChartPainter({required this.filter, required this.transactions});

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = AppColors.surfaceContainerHigh
      ..strokeWidth = 1;
    final textStyle = AppTypography.labelMuted.copyWith(fontSize: 10, color: AppColors.outline);

    final yLabels = ['15k', '10k', '5k'];
    for (int i = 0; i < 3; i++) {
      final y = size.height * (i / 3) + 20;
      canvas.drawLine(Offset(30, y), Offset(size.width, y), paintGrid);
      
      final textSpan = TextSpan(text: yLabels[i], style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    List<double> data = [0, 0, 0, 0, 0, 0, 0];
    
    // Real mapping logic based on filter
    final now = DateTime.now();
    if (filter == 'Day' || filter == 'Week' || filter == 'Month' || filter == 'Year' || filter == 'Custom') {
      // Just map the recent 7 days or weeks or months. For simplicity in this functional plan,
      // we'll sum expenses grouped by recent 7 buckets
      List<double> buckets = List.filled(7, 0.0);
      
      for (var t in transactions) {
        if (t.type != TransactionType.expense) continue;
        
        int daysDiff = now.difference(t.date).inDays;
        
        if (filter == 'Week') {
          if (daysDiff < 7) {
            buckets[6 - daysDiff] += t.amount;
          }
        } else if (filter == 'Month') {
          if (daysDiff < 30) {
            int bucketIdx = 6 - (daysDiff ~/ 5);
            if (bucketIdx >= 0 && bucketIdx < 7) {
              buckets[bucketIdx] += t.amount;
            }
          }
        } else if (filter == 'Year') {
          if (daysDiff < 365) {
            int bucketIdx = 6 - (daysDiff ~/ 52);
            if (bucketIdx >= 0 && bucketIdx < 7) {
              buckets[bucketIdx] += t.amount;
            }
          }
        } else {
          // Default day / custom fallback
          if (daysDiff < 7) {
            buckets[6 - daysDiff] += t.amount;
          }
        }
      }
      
      double maxVal = buckets.fold(0.0, (m, v) => v > m ? v : m);
      if (maxVal == 0) maxVal = 1; // avoid divide by zero
      
      data = buckets.map((v) => v / maxVal).toList();
    }

    final path = Path();
    final paintLine = Paint()
      ..color = AppColors.primaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final startX = 30.0;
    final stepX = (size.width - startX) / (data.length - 1);
    
    double mapY(double value) {
      return size.height - (value * size.height) + 10;
    }

    path.moveTo(startX, mapY(data[0]));
    
    for (int i = 0; i < data.length - 1; i++) {
      final p0 = Offset(startX + i * stepX, mapY(data[i]));
      final p1 = Offset(startX + (i + 1) * stepX, mapY(data[i + 1]));
      
      final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
      
      path.cubicTo(
        controlPointX, p0.dy,
        controlPointX, p1.dy,
        p1.dx, p1.dy,
      );
    }
    
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant TrendChartPainter oldDelegate) {
    return oldDelegate.filter != filter;
  }
}
