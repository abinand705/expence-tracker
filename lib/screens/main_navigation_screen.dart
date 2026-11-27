import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/transaction_item.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/app_drawer.dart';
import '../widgets/floating_bottom_bar.dart';
import 'analytics_screen.dart';
import 'auth_screen.dart';
import 'budgets_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final ThemeController? themeController;
  final AuthController? authController;
  final FirestoreService? firestoreService;

  const MainNavigationScreen({
    super.key,
    this.themeController,
    this.authController,
    this.firestoreService,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  final List<TransactionItem> _transactions = [];

  late final FirestoreService _firestoreService;
  StreamSubscription<List<TransactionItem>>? _transactionsSub;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _subscribeToUserTransactions();
    widget.authController?.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final currentUserId = widget.authController?.userId ?? 'guest_user';
    if (currentUserId != _lastUserId) {
      _subscribeToUserTransactions();
    }
  }

  void _subscribeToUserTransactions() {
    _transactionsSub?.cancel();
    final userId = widget.authController?.userId ?? 'guest_user';
    _lastUserId = userId;

    _transactionsSub = _firestoreService.streamTransactions(userId).listen((items) {
      if (!mounted) return;
      setState(() {
        _transactions.clear();
        _transactions.addAll(items);
      });
    });
  }

  @override
  void dispose() {
    widget.authController?.removeListener(_onAuthChanged);
    _transactionsSub?.cancel();
    super.dispose();
  }

  void _openAddTransactionSheet(TransactionType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddTransactionSheet(
        initialType: type,
        firestoreService: _firestoreService,
        authController: widget.authController,
        onAdd: (transaction) async {
          setState(() {
            _transactions.removeWhere((t) => t.id == transaction.id);
            _transactions.insert(0, transaction);
          });
          final userId = widget.authController?.userId ?? 'guest_user';
          try {
            await _firestoreService.saveTransaction(userId, transaction);
          } catch (e) {
            debugPrint('Error saving transaction: $e');
          }
        },
      ),
    );
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((t) => t.id == id);
    });
    final userId = widget.authController?.userId ?? 'guest_user';
    _firestoreService.deleteTransaction(userId, id);
  }

  void _openAuth() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          authController: widget.authController ?? AuthController(),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          themeController: widget.themeController,
          authController: widget.authController,
          onOpenAuth: _openAuth,
          onClearAllData: () {
            setState(() {
              _transactions.clear();
            });
            final userId = widget.authController?.userId ?? 'guest_user';
            _firestoreService.clearAllTransactions(userId);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      HomeScreen(
        transactions: _transactions,
        onAddTransaction: _openAddTransactionSheet,
        onSeeAll: () => setState(() => _currentIndex = 1),
        onDeleteTransaction: _deleteTransaction,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      TransactionsScreen(
        transactions: _transactions,
        onAddTransaction: () =>
            _openAddTransactionSheet(TransactionType.expense),
        onDeleteTransaction: _deleteTransaction,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      AnalyticsScreen(
        transactions: _transactions,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      BudgetsScreen(
        transactions: _transactions,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        firestoreService: _firestoreService,
        authController: widget.authController,
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: AppDrawer(
        selectedIndex: _currentIndex,
        authController: widget.authController,
        onSelectTab: (index) {
          setState(() => _currentIndex = index);
        },
        onOpenSettings: _openSettings,
        onOpenAuth: _openAuth,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Active Tab Content
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),

            // Persistent Floating Action Button (+) (Only on Home [0] and Transactions [1])
            if (_currentIndex == 0 || _currentIndex == 1)
              Positioned(
                right: 20,
                bottom: 96,
                child: FloatingActionButton(
                onPressed: () =>
                    _openAddTransactionSheet(TransactionType.expense),
                backgroundColor: isDark ? const Color(0xFF165945) : const Color(0xFF0A3026),
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            // Persistent Floating Bottom Navigation Bar (4 items, Settings removed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingBottomBar(
                selectedIndex: _currentIndex,
                onItemSelected: (index) {
                  setState(() => _currentIndex = index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
