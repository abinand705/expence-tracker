import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/auth_controller.dart';
import '../models/category_item.dart';
import '../models/transaction_item.dart';
import '../services/firestore_service.dart';

class BudgetLimit {
  final String category;
  final double limit;

  BudgetLimit({required this.category, required this.limit});
}

class CategoryBadgeData {
  String id;
  String name;
  IconData icon;
  Color bgColor;
  Color borderColor;
  Color textColor;
  bool isPredefined;
  String userId;

  CategoryBadgeData({
    required this.id,
    required this.name,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    this.isPredefined = false,
    this.userId = 'all',
  });
}

class CategoryColorTheme {
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;

  const CategoryColorTheme({
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
  });
}

const List<CategoryColorTheme> kCategoryColorThemes = [
  CategoryColorTheme(
    label: 'Amber',
    bgColor: Color(0xFFFFF2E8),
    borderColor: Color(0xFFFFD8BF),
    textColor: Color(0xFFD46B08),
  ),
  CategoryColorTheme(
    label: 'Mint',
    bgColor: Color(0xFFE6FFFB),
    borderColor: Color(0xFFB5F5EC),
    textColor: Color(0xFF08979C),
  ),
  CategoryColorTheme(
    label: 'Blue',
    bgColor: Color(0xFFE6F7FF),
    borderColor: Color(0xFFBAE7FF),
    textColor: Color(0xFF096DD9),
  ),
  CategoryColorTheme(
    label: 'Pink',
    bgColor: Color(0xFFFFF0F6),
    borderColor: Color(0xFFFFD6E7),
    textColor: Color(0xFFC41D7F),
  ),
  CategoryColorTheme(
    label: 'Yellow',
    bgColor: Color(0xFFFEFFE6),
    borderColor: Color(0xFFFFFFB8),
    textColor: Color(0xFFD48806),
  ),
  CategoryColorTheme(
    label: 'Purple',
    bgColor: Color(0xFFF9F0FF),
    borderColor: Color(0xFFEFDBFF),
    textColor: Color(0xFF531DAB),
  ),
  CategoryColorTheme(
    label: 'Red',
    bgColor: Color(0xFFFFF1F0),
    borderColor: Color(0xFFFFA39E),
    textColor: Color(0xFFCF1322),
  ),
  CategoryColorTheme(
    label: 'Green',
    bgColor: Color(0xFFF6FFED),
    borderColor: Color(0xFFB7EB8F),
    textColor: Color(0xFF389E0D),
  ),
  CategoryColorTheme(
    label: 'Cyan',
    bgColor: Color(0xFFE6FFFB),
    borderColor: Color(0xFF87E8DE),
    textColor: Color(0xFF006D75),
  ),
  CategoryColorTheme(
    label: 'Grey',
    bgColor: Color(0xFFF5F5F5),
    borderColor: Color(0xFFD9D9D9),
    textColor: Color(0xFF595959),
  ),
];

const List<IconData> kCategoryIcons = [
  Icons.restaurant_outlined,
  Icons.shopping_cart_outlined,
  Icons.directions_car_outlined,
  Icons.shopping_bag_outlined,
  Icons.receipt_outlined,
  Icons.movie_creation_outlined,
  Icons.medical_services_outlined,
  Icons.school_outlined,
  Icons.flight_outlined,
  Icons.payments_outlined,
  Icons.business_center_outlined,
  Icons.trending_up_outlined,
  Icons.card_giftcard_outlined,
  Icons.savings_outlined,
  Icons.home_outlined,
  Icons.fitness_center_outlined,
  Icons.pets_outlined,
  Icons.more_horiz,
];

class BudgetsScreen extends StatefulWidget {
  final List<TransactionItem> transactions;
  final VoidCallback? onOpenDrawer;
  final FirestoreService? firestoreService;
  final AuthController? authController;

  const BudgetsScreen({
    super.key,
    required this.transactions,
    this.onOpenDrawer,
    this.firestoreService,
    this.authController,
  });

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<BudgetLimit> _budgets = [];
  late final FirestoreService _firestoreService;
  StreamSubscription<List<CategoryItem>>? _categoriesSub;

  final List<CategoryBadgeData> _expenseCategories = [];
  final List<CategoryBadgeData> _incomeCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _loadPredefinedCategories();
    _subscribeToCategories();
    widget.authController?.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    _subscribeToCategories();
  }

  void _loadPredefinedCategories() {
    _expenseCategories.clear();
    _incomeCategories.clear();
    for (final item in CategoryItem.predefinedCategories) {
      final badge = _itemToBadge(item);
      if (item.subcategory == 'expense') {
        _expenseCategories.add(badge);
      } else {
        _incomeCategories.add(badge);
      }
    }
  }

  void _subscribeToCategories() {
    _categoriesSub?.cancel();
    final userId = widget.authController?.userId ?? 'guest_user';
    _categoriesSub = _firestoreService.streamCategories(userId).listen((items) {
      if (!mounted) return;
      setState(() {
        _expenseCategories.clear();
        _incomeCategories.clear();
        for (final item in items) {
          final badge = _itemToBadge(item);
          if (item.subcategory == 'expense') {
            _expenseCategories.add(badge);
          } else {
            _incomeCategories.add(badge);
          }
        }
      });
    });
  }

  CategoryBadgeData _itemToBadge(CategoryItem item) {
    final bgColor = CategoryItem.hexToColor(item.colour);
    CategoryColorTheme? matchedTheme;
    for (final theme in kCategoryColorThemes) {
      if (theme.bgColor.toARGB32() == bgColor.toARGB32()) {
        matchedTheme = theme;
        break;
      }
    }

    final borderColor =
        matchedTheme?.borderColor ?? bgColor.withValues(alpha: 0.8);
    final textColor = matchedTheme?.textColor ?? const Color(0xFF1E293B);

    return CategoryBadgeData(
      id: item.id,
      name: item.name,
      icon: CategoryItem.iconFromString(item.icon),
      bgColor: bgColor,
      borderColor: borderColor,
      textColor: textColor,
      isPredefined: item.isPredefined,
      userId: item.userId,
    );
  }

  @override
  void dispose() {
    widget.authController?.removeListener(_onAuthChanged);
    _categoriesSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _openSetBudgetDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final actionButtonColor = isDark ? const Color(0xFF165945) : const Color(0xFF0A3026);
    String selectedCat = _expenseCategories.isNotEmpty ? _expenseCategories.first.name : 'General';
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set Category Budget',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCat,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: textColor, fontSize: 15),
                iconEnabledColor: textColor,
                items: _expenseCategories
                    .map((cat) =>
                        DropdownMenuItem(value: cat.name, child: Text(cat.name, style: TextStyle(color: textColor))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => selectedCat = val);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Monthly Limit',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text.trim());
                  if (amount != null && amount > 0) {
                    setState(() {
                      _budgets.removeWhere((b) => b.category == selectedCat);
                      _budgets.add(BudgetLimit(category: selectedCat, limit: amount));
                    });
                    Navigator.of(ctx).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionButtonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Set Budget',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Allow Adding or Editing a Category
  void _showAddOrEditCategoryDialog({
    required bool isExpense,
    int? existingIndex,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final actionButtonColor = isDark ? const Color(0xFF165945) : const Color(0xFF0A3026);

    final isEditing = existingIndex != null;
    final targetList = isExpense ? _expenseCategories : _incomeCategories;
    final currentItem = isEditing ? targetList[existingIndex] : null;

    final nameController = TextEditingController(text: currentItem?.name ?? '');
    IconData selectedIcon = currentItem?.icon ?? (isExpense ? Icons.restaurant_outlined : Icons.payments_outlined);
    CategoryColorTheme selectedTheme = kCategoryColorThemes.firstWhere(
      (theme) => theme.textColor == (currentItem?.textColor ?? (isExpense ? const Color(0xFFD46B08) : const Color(0xFF389E0D))),
      orElse: () => kCategoryColorThemes.first,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Category' : (isExpense ? 'Add Expense Category' : 'Add Income Category'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Name Input
              TextField(
                controller: nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  hintText: 'e.g. Gym & Fitness',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Icon Selector
              Text(
                'Select Icon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kCategoryIcons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final icon = kCategoryIcons[index];
                    final isSelected = selectedIcon == icon;
                    return InkWell(
                      onTap: () => setModalState(() => selectedIcon = icon),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected ? actionButtonColor : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Color Theme Selector
              Text(
                'Select Color',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kCategoryColorThemes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final theme = kCategoryColorThemes[index];
                    final isSelected = selectedTheme.label == theme.label;
                    return InkWell(
                      onTap: () => setModalState(() => selectedTheme = theme),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026)) : theme.borderColor,
                            width: isSelected ? 2.5 : 1.2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, size: 18, color: theme.textColor)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final categoryId = isEditing
                      ? targetList[existingIndex].id
                      : 'cat_${DateTime.now().millisecondsSinceEpoch}';
                  final userId = widget.authController?.userId ?? 'guest_user';

                  final newBadge = CategoryBadgeData(
                    id: categoryId,
                    name: name,
                    icon: selectedIcon,
                    bgColor: selectedTheme.bgColor,
                    borderColor: selectedTheme.borderColor,
                    textColor: selectedTheme.textColor,
                    isPredefined: false,
                    userId: userId,
                  );

                  setState(() {
                    if (isEditing) {
                      targetList[existingIndex] = newBadge;
                    } else {
                      targetList.add(newBadge);
                    }
                  });

                  // Persist to Firestore categories collection
                  final categoryItem = CategoryItem(
                    id: categoryId,
                    name: name,
                    subcategory: isExpense ? 'expense' : 'income',
                    icon: CategoryItem.stringFromIcon(selectedIcon),
                    colour: CategoryItem.colorToHex(selectedTheme.bgColor),
                    userId: userId,
                    isPredefined: false,
                  );
                  _firestoreService.saveCategory(categoryItem);

                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Updated category: $name'
                            : 'Added new category: $name',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionButtonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Add Category',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tapping a category chip shows Edit / Delete actions
  void _showCategoryActionsSheet(CategoryBadgeData badge, bool isExpense, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  _buildCategoryChip(badge, isDark),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026)),
              title: Text('Edit Category', style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddOrEditCategoryDialog(
                  isExpense: isExpense,
                  existingIndex: index,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              title: const Text(
                'Delete Category',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteCategory(isExpense, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(bool isExpense, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final list = isExpense ? _expenseCategories : _incomeCategories;
    final item = list[index];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Category?', style: TextStyle(color: textColor)),
        content: Text(
          'Are you sure you want to remove "${item.name}"?',
          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final item = list[index];
              setState(() {
                list.removeAt(index);
              });
              _firestoreService.deleteCategory(
                item.id,
                isExpense ? 'expense' : 'income',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${item.name}"'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar without '+' button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: textColor, size: 24),
                    onPressed: widget.onOpenDrawer,
                    tooltip: 'Open menu',
                  ),
                  Text(
                    'Budgets & Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  // No + button on top right, 48px space balances the menu icon
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Budgets'),
                  Tab(text: 'Categories'),
                ],
              ),
            ),

            // Tab Bar Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Budgets
                  _buildBudgetsTab(isDark, textColor),

                  // Tab 2: Categories
                  _buildCategoriesTab(isDark, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsTab(bool isDark, Color textColor) {
    if (_budgets.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.savings_outlined,
                size: 60,
                color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
              ),
              const SizedBox(height: 18),
              Text(
                'No Budgets Set',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set a spending limit for categories to manage\nyour monthly budget.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _openSetBudgetDialog,
                icon: Icon(Icons.add, size: 18, color: textColor),
                label: Text(
                  'Set New Budget',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  side: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat('#,##0.00', 'en_IN');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      itemCount: _budgets.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _budgets.length) {
          return Center(
            child: TextButton.icon(
              onPressed: _openSetBudgetDialog,
              icon: Icon(Icons.add, color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026)),
              label: Text(
                'Add Another Budget',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                ),
              ),
            ),
          );
        }

        final budget = _budgets[index];
        final spent = widget.transactions
            .where((t) =>
                t.type == TransactionType.expense &&
                t.category == budget.category)
            .fold<double>(0.0, (sum, t) => sum + t.amount);
        final ratio = (spent / budget.limit).clamp(0.0, 1.0);
        final isExceeded = spent > budget.limit;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    budget.category,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      setState(() => _budgets.removeAt(index));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: ₹ ${currencyFormat.format(spent)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isExceeded
                          ? const Color(0xFFDC2626)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  Text(
                    'Limit: ₹ ${currencyFormat.format(budget.limit)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isExceeded
                        ? const Color(0xFFDC2626)
                        : (isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab(bool isDark, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expense Categories Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expense Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              InkWell(
                onTap: () => _showAddOrEditCategoryDialog(isExpense: true),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '+ Add Custom',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_expenseCategories.length, (i) {
              final badge = _expenseCategories[i];
              return InkWell(
                onTap: () => _showCategoryActionsSheet(badge, true, i),
                borderRadius: BorderRadius.circular(14),
                child: _buildCategoryChip(badge, isDark),
              );
            }),
          ),
          const SizedBox(height: 32),

          // Income Categories Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Income Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              InkWell(
                onTap: () => _showAddOrEditCategoryDialog(isExpense: false),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '+ Add Custom',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF0A3026),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_incomeCategories.length, (i) {
              final badge = _incomeCategories[i];
              return InkWell(
                onTap: () => _showCategoryActionsSheet(badge, false, i),
                borderRadius: BorderRadius.circular(14),
                child: _buildCategoryChip(badge, isDark),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(CategoryBadgeData badge, [bool isDark = false]) {
    final bg = isDark ? badge.bgColor.withValues(alpha: 0.15) : badge.bgColor;
    final border = isDark ? badge.borderColor.withValues(alpha: 0.35) : badge.borderColor;
    final text = isDark ? Color.lerp(badge.textColor, Colors.white, 0.35)! : badge.textColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badge.icon,
            size: 16,
            color: text,
          ),
          const SizedBox(width: 8),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
