import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CategoryIcon extends StatelessWidget {
  final String category;
  final double size;

  const CategoryIcon({super.key, required this.category, this.size = 48.0});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;
    IconData iconData;

    switch (category.toLowerCase()) {
      case 'food':
        bgColor = AppColors.pastelPink;
        iconColor = AppColors.onPastelPink;
        iconData = Icons.restaurant;
        break;
      case 'shopping':
        bgColor = AppColors.pastelPurple;
        iconColor = AppColors.onPastelPurple;
        iconData = Icons.shopping_bag;
        break;
      case 'bills':
      case 'electricity bill':
        bgColor = AppColors.pastelBlue;
        iconColor = AppColors.onPastelBlue;
        iconData = Icons.receipt;
        break;
      case 'income':
      case 'salary':
        bgColor = const Color(0x262A9D4A);
        iconColor = AppColors.successGreen;
        iconData = Icons.account_balance_wallet;
        break;
      default:
        bgColor = AppColors.surfaceContainerHigh;
        iconColor = AppColors.onSurfaceVariant;
        iconData = Icons.category;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: size * 0.5),
    );
  }
}
