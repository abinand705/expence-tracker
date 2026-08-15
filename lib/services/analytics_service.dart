import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/trend_data.dart';

class AnalyticsService {
  double calculateTotalExpenses(List<Transaction> transactions, {int? month, int? year}) {
    return transactions.where((t) {
      if (t.type != TransactionType.expense) return false;
      if (month != null && t.date.month != month) return false;
      if (year != null && t.date.year != year) return false;
      return true;
    }).fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> calculateCategoryTotals(List<Transaction> transactions, {int? month, int? year}) {
    Map<String, double> totals = {};
    for (var t in transactions) {
      if (t.type != TransactionType.expense) continue;
      if (month != null && t.date.month != month) continue;
      if (year != null && t.date.year != year) continue;

      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<TrendData> calculateTrendData(
    List<Transaction> transactions,
    TrendPeriod period,
    DateTime referenceDate,
    DateTimeRange? customRange,
  ) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();

    switch (period) {
      case TrendPeriod.day:
        return _calculateDayTrend(expenses, referenceDate);
      case TrendPeriod.week:
        return _calculateWeekTrend(expenses, referenceDate);
      case TrendPeriod.month:
        return _calculateMonthTrend(expenses, referenceDate);
      case TrendPeriod.year:
        return _calculateYearTrend(expenses, referenceDate);
      case TrendPeriod.custom:
        return _calculateCustomTrend(expenses, customRange);
    }
  }

  List<TrendData> _calculateDayTrend(List<Transaction> expenses, DateTime referenceDate) {
    // 6 buckets: 12 AM, 4 AM, 8 AM, 12 PM, 4 PM, 8 PM
    List<double> amounts = List.filled(6, 0.0);
    final labels = ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'];

    for (var t in expenses) {
      if (_isSameDay(t.date, referenceDate)) {
        int bucket = t.date.hour ~/ 4;
        if (bucket >= 0 && bucket < 6) {
          amounts[bucket] += t.amount;
        }
      }
    }

    return List.generate(6, (i) => TrendData(label: labels[i], amount: amounts[i]));
  }

  List<TrendData> _calculateWeekTrend(List<Transaction> expenses, DateTime referenceDate) {
    // Monday to Sunday of the week containing referenceDate
    // weekday is 1 (Mon) to 7 (Sun)
    final int weekday = referenceDate.weekday;
    final startOfWeek = DateTime(referenceDate.year, referenceDate.month, referenceDate.day).subtract(Duration(days: weekday - 1));

    List<double> amounts = List.filled(7, 0.0);
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (var t in expenses) {
      // Check if t.date is within startOfWeek and startOfWeek + 7 days
      final dateOnly = DateTime(t.date.year, t.date.month, t.date.day);
      final daysDiff = dateOnly.difference(startOfWeek).inDays;
      
      if (daysDiff >= 0 && daysDiff < 7) {
        amounts[daysDiff] += t.amount;
      }
    }

    return List.generate(7, (i) => TrendData(label: labels[i], amount: amounts[i]));
  }

  List<TrendData> _calculateMonthTrend(List<Transaction> expenses, DateTime referenceDate) {
    final int year = referenceDate.year;
    final int month = referenceDate.month;
    
    // Calculate number of weeks. We can simply group by 7-day intervals from the 1st
    // or group by the actual week of the month.
    // For simplicity and standard UI, let's group by days 1-7 (W1), 8-14 (W2), 15-21 (W3), 22-28 (W4), 29+ (W5)
    List<double> amounts = List.filled(5, 0.0);
    final labels = ['W1', 'W2', 'W3', 'W4', 'W5'];

    for (var t in expenses) {
      if (t.date.year == year && t.date.month == month) {
        int weekIdx = (t.date.day - 1) ~/ 7;
        if (weekIdx > 4) weekIdx = 4;
        amounts[weekIdx] += t.amount;
      }
    }

    return List.generate(5, (i) => TrendData(label: labels[i], amount: amounts[i]));
  }

  List<TrendData> _calculateYearTrend(List<Transaction> expenses, DateTime referenceDate) {
    final int year = referenceDate.year;
    List<double> amounts = List.filled(12, 0.0);
    final labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    for (var t in expenses) {
      if (t.date.year == year) {
        amounts[t.date.month - 1] += t.amount;
      }
    }

    return List.generate(12, (i) => TrendData(label: labels[i], amount: amounts[i]));
  }

  List<TrendData> _calculateCustomTrend(List<Transaction> expenses, DateTimeRange? customRange) {
    if (customRange == null) return [];
    
    final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
    final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
    
    final filtered = expenses.where((t) => t.date.isAfter(start.subtract(const Duration(seconds: 1))) && t.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
    
    final int durationDays = end.difference(start).inDays + 1;
    
    if (durationDays <= 31) {
      // Daily buckets
      List<TrendData> data = [];
      for (int i = 0; i < durationDays; i++) {
        final d = start.add(Duration(days: i));
        double sum = 0;
        for (var t in filtered) {
          if (_isSameDay(t.date, d)) sum += t.amount;
        }
        data.add(TrendData(label: '${d.day}/${d.month}', amount: sum));
      }
      return data;
    } else {
      // Monthly buckets
      List<TrendData> data = [];
      int currentMonth = start.month;
      int currentYear = start.year;
      
      while (currentYear < end.year || (currentYear == end.year && currentMonth <= end.month)) {
        double sum = 0;
        for (var t in filtered) {
          if (t.date.year == currentYear && t.date.month == currentMonth) {
            sum += t.amount;
          }
        }
        data.add(TrendData(label: '$currentMonth/$currentYear', amount: sum));
        
        currentMonth++;
        if (currentMonth > 12) {
          currentMonth = 1;
          currentYear++;
        }
      }
      return data;
    }
  }
}
