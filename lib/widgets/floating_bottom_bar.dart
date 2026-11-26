import 'package:flutter/material.dart';

class FloatingBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const FloatingBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(36),
        border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, isDark: isDark, key: const Key('nav_home')),
          _buildNavItem(1, Icons.receipt_long_outlined, isDark: isDark, key: const Key('nav_transactions')),
          _buildNavItem(2, Icons.pie_chart_outline_rounded, isDark: isDark, key: const Key('nav_analytics')),
          _buildNavItem(3, Icons.savings_outlined, isDark: isDark, key: const Key('nav_budgets')),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, {bool isDark = false, Key? key}) {
    final isSelected = selectedIndex == index;

    if (isSelected) {
      final activeColor = isDark ? const Color(0xFF165945) : const Color(0xFF0A3026);
      return Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      );
    }

    return InkWell(
      key: key,
      onTap: () => onItemSelected(index),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          size: 24,
        ),
      ),
    );
  }
}
