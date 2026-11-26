import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String name;
  final String subcategory; // 'expense' or 'income'
  final String icon; // Icon identifier (e.g. 'restaurant_outlined' or codepoint)
  final String colour; // Hex colour string (e.g. '#FFF2E8')
  final String userId; // 'all' for predefined, or specific user UID
  final bool isPredefined;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.subcategory,
    required this.icon,
    required this.colour,
    required this.userId,
    this.isPredefined = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'category/expense_name': name,
      'category_name': name,
      'subcategory': subcategory,
      'icon': icon,
      'colour': colour,
      'user_Id': userId,
      'is_predefined': isPredefined,
    };
  }

  factory CategoryItem.fromMap(String id, Map<String, dynamic> map) {
    final name = (map['category/expense_name'] ??
            map['category_name'] ??
            map['name'] ??
            'General')
        .toString();
    final subcategory =
        (map['subcategory'] ?? map['type'] ?? 'expense').toString();
    final icon = (map['icon'] ?? 'more_horiz').toString();
    final colour = (map['colour'] ?? map['color'] ?? '#FFF2E8').toString();
    final userId = (map['user_Id'] ?? map['userId'] ?? 'all').toString();
    final isPredefined = map['is_predefined'] == true || userId == 'all';

    return CategoryItem(
      id: id,
      name: name,
      subcategory: subcategory,
      icon: icon,
      colour: colour,
      userId: userId,
      isPredefined: isPredefined,
    );
  }

  static const Map<String, IconData> namedIcons = {
    'restaurant_outlined': Icons.restaurant_outlined,
    'shopping_cart_outlined': Icons.shopping_cart_outlined,
    'directions_car_outlined': Icons.directions_car_outlined,
    'shopping_bag_outlined': Icons.shopping_bag_outlined,
    'receipt_outlined': Icons.receipt_outlined,
    'movie_creation_outlined': Icons.movie_creation_outlined,
    'medical_services_outlined': Icons.medical_services_outlined,
    'school_outlined': Icons.school_outlined,
    'flight_outlined': Icons.flight_outlined,
    'payments_outlined': Icons.payments_outlined,
    'business_center_outlined': Icons.business_center_outlined,
    'trending_up_outlined': Icons.trending_up_outlined,
    'card_giftcard_outlined': Icons.card_giftcard_outlined,
    'savings_outlined': Icons.savings_outlined,
    'home_outlined': Icons.home_outlined,
    'fitness_center_outlined': Icons.fitness_center_outlined,
    'pets_outlined': Icons.pets_outlined,
    'more_horiz': Icons.more_horiz,
  };

  static IconData iconFromString(String iconStr) {
    if (namedIcons.containsKey(iconStr)) {
      return namedIcons[iconStr]!;
    }
    for (final entry in namedIcons.entries) {
      if (entry.value.codePoint.toString() == iconStr) {
        return entry.value;
      }
    }
    return Icons.category_outlined;
  }

  static String stringFromIcon(IconData icon) {
    for (final entry in namedIcons.entries) {
      if (entry.value.codePoint == icon.codePoint) {
        return entry.key;
      }
    }
    return 'more_horiz';
  }

  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static Color hexToColor(String hexStr) {
    var hex = hexStr.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    final intVal = int.tryParse(hex, radix: 16);
    if (intVal != null) {
      return Color(intVal);
    }
    return const Color(0xFFF5F5F5);
  }

  static List<CategoryItem> get predefinedCategories => const [
        // Predefined Expense Categories
        CategoryItem(
          id: 'predefined_food_dining',
          name: 'Food & Dining',
          subcategory: 'expense',
          icon: 'restaurant_outlined',
          colour: '#FFF2E8',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_groceries',
          name: 'Groceries',
          subcategory: 'expense',
          icon: 'shopping_cart_outlined',
          colour: '#E6FFFB',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_transportation',
          name: 'Transportation',
          subcategory: 'expense',
          icon: 'directions_car_outlined',
          colour: '#E6F7FF',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_shopping',
          name: 'Shopping',
          subcategory: 'expense',
          icon: 'shopping_bag_outlined',
          colour: '#FFF0F6',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_bills_utilities',
          name: 'Bills & Utilities',
          subcategory: 'expense',
          icon: 'receipt_outlined',
          colour: '#FEFFE6',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_entertainment',
          name: 'Entertainment',
          subcategory: 'expense',
          icon: 'movie_creation_outlined',
          colour: '#F9F0FF',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_healthcare',
          name: 'Healthcare',
          subcategory: 'expense',
          icon: 'medical_services_outlined',
          colour: '#FFF1F0',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_education',
          name: 'Education',
          subcategory: 'expense',
          icon: 'school_outlined',
          colour: '#E6FFFB',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_travel',
          name: 'Travel',
          subcategory: 'expense',
          icon: 'flight_outlined',
          colour: '#E6FFFA',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_other_expense',
          name: 'Other Expense',
          subcategory: 'expense',
          icon: 'more_horiz',
          colour: '#F5F5F5',
          userId: 'all',
          isPredefined: true,
        ),

        // Predefined Income Categories
        CategoryItem(
          id: 'predefined_salary',
          name: 'Salary',
          subcategory: 'income',
          icon: 'payments_outlined',
          colour: '#F6FFED',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_freelance_business',
          name: 'Freelance & Business',
          subcategory: 'income',
          icon: 'business_center_outlined',
          colour: '#F0F5FF',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_investments',
          name: 'Investments',
          subcategory: 'income',
          icon: 'trending_up_outlined',
          colour: '#F9F0FF',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_gifts_allowance',
          name: 'Gifts & Allowance',
          subcategory: 'income',
          icon: 'card_giftcard_outlined',
          colour: '#FFF0F6',
          userId: 'all',
          isPredefined: true,
        ),
        CategoryItem(
          id: 'predefined_other_income',
          name: 'Other Income',
          subcategory: 'income',
          icon: 'savings_outlined',
          colour: '#FFFBE6',
          userId: 'all',
          isPredefined: true,
        ),
      ];
}
