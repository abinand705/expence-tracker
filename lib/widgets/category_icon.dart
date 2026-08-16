import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../repositories/category_repository.dart';
import '../models/category.dart';

class CategoryIcon extends StatelessWidget {
  final String category;
  final double size;

  const CategoryIcon({super.key, required this.category, this.size = 48.0});

  Stream<List<Category>> _safeWatchCategories() {
    try {
      return CategoryRepository().watchCategories();
    } catch (e) {
      return Stream.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Category>>(
      stream: _safeWatchCategories(),
      builder: (context, snapshot) {
        Color bgColor;
        Color iconColor;
        IconData iconData;

        // Default fallbacks
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

        // Override with dynamic category if found
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          try {
            final dynamicCategory = snapshot.data!.firstWhere(
                (c) => c.name.toLowerCase() == category.toLowerCase());
            bgColor = Color(dynamicCategory.colorValue).withValues(alpha: 0.2);
            iconColor = Color(dynamicCategory.colorValue);
            // ignore: non_const_argument_for_const_parameter
            iconData = IconData(dynamicCategory.iconCodePoint, fontFamily: 'MaterialIcons');
          } catch (_) {
            // Not found in dynamic categories, fallback used
          }
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
      },
    );
  }
}
