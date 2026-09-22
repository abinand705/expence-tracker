/// Utility class to ensure Flutter DropdownButtonFormField constraints are strictly met:
/// - Dropdown items must be deduplicated.
/// - The selected value must correspond to exactly 0 or 1 item in the dropdown.
class DropdownSafety {
  /// Resolves dropdown items and selected value safely.
  static ({List<String> items, String? safeValue}) resolve({
    required List<String> items,
    required String? currentValue,
    String? fallback,
  }) {
    // 1. Deduplicate items while preserving insertion order
    final uniqueItems = <String>[];
    final seen = <String>{};
    for (final item in items) {
      if (seen.add(item)) {
        uniqueItems.add(item);
      }
    }

    if (uniqueItems.isEmpty) {
      return (items: <String>[], safeValue: null);
    }

    if (currentValue == null) {
      final safeFallback = fallback != null && seen.contains(fallback) ? fallback : null;
      return (items: uniqueItems, safeValue: safeFallback);
    }

    // 2. Check matches
    final matchingItems = uniqueItems.where((item) => item == currentValue).toList();
    if (matchingItems.length == 1) {
      return (items: uniqueItems, safeValue: currentValue);
    }

    // 3. If no match or ambiguous, safely fallback
    if (fallback != null && seen.contains(fallback)) {
      return (items: uniqueItems, safeValue: fallback);
    }

    return (items: uniqueItems, safeValue: null);
  }

  /// Normalizes legacy or generated rule labels to standard rule types.
  /// E.g. "Kerala Gramin Bank Debit" -> "Debit"
  ///      "HDFC Credit" -> "Credit"
  static String normalizeRuleLabel(String rawLabel) {
    final trimmed = rawLabel.trim();
    if (trimmed.isEmpty) return 'Debit';
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('debit')) return 'Debit';
    if (lower.endsWith('credit')) return 'Credit';
    if (lower.contains('upi debit')) return 'UPI Debit';
    if (lower.contains('upi credit')) return 'UPI Credit';
    if (lower.contains('atm')) return 'ATM';
    return trimmed;
  }
}
