import '../models/category.dart';

class CategoryRepository {
  Future<List<Category>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Category(id: 'cat_food', name: 'Food', iconCodePoint: 0xe532, colorValue: 0xFFC2185B),
      Category(id: 'cat_shopping', name: 'Shopping', iconCodePoint: 0xe5fc, colorValue: 0xFF7B1FA2),
      Category(id: 'cat_bills', name: 'Bills', iconCodePoint: 0xe0b0, colorValue: 0xFF1976D2),
      Category(id: 'cat_others', name: 'Others', iconCodePoint: 0xe14ea, colorValue: 0xFFF57C00),
    ];
  }
}
