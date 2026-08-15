enum TrendPeriod { day, week, month, year, custom }

class TrendData {
  final String label;
  final double amount;

  const TrendData({
    required this.label,
    required this.amount,
  });
}
