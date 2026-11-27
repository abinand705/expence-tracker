import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_track/main.dart';

void main() {
  testWidgets(
      'MoneyTrack verifies all tabs, settings, and Budgets & Categories without + buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyTrackApp());
    await tester.pumpAndSettle();

    // 1. Verify Home Tab (Initial)
    expect(find.text('MoneyTrack'), findsOneWidget);

    // Verify dynamic greeting based on time of day
    final hour = DateTime.now().hour;
    final expectedGreeting = (hour >= 5 && hour < 12)
        ? 'Good morning'
        : (hour >= 12 && hour < 17)
            ? 'Good afternoon'
            : (hour >= 17 && hour < 21)
                ? 'Good evening'
                : 'Good night';
    expect(find.text(expectedGreeting), findsOneWidget);
    expect(find.text('TOTAL BALANCE'), findsOneWidget);
    expect(find.text('CASH FLOW (THIS MONTH)'), findsOneWidget);

    // Verify 100% offline badge is removed
    expect(find.text('100% Offline'), findsNothing);

    // Verify app icon is NOT shown on homepage
    expect(find.byType(Image), findsNothing);

    // Verify + Expense, + Income, Transfer buttons are removed from homepage
    expect(find.text('+ Expense'), findsNothing);
    expect(find.text('+ Income'), findsNothing);
    expect(find.text('Transfer'), findsNothing);

    // Verify 3-line menu bar exists at top-left
    expect(find.byIcon(Icons.menu), findsWidgets);

    // 2. Open sidebar (Drawer) via top-left 3-line bar
    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    // Drawer header has app icon
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Export Data (CSV / JSON)'), findsOneWidget);
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Tap "Settings" in the drawer
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Verify Settings Screen Items
    expect(find.text('Currency Symbol'), findsOneWidget);
    expect(find.text('Selected: ₹'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Light Mode'), findsOneWidget);
    expect(find.text('Shake to Add (In-App)'), findsOneWidget);
    expect(find.text('Shake Anywhere (Outside App)'), findsOneWidget);

    // Test switching Theme Mode to Dark
    await tester.tap(find.text('Theme Mode'));
    await tester.pumpAndSettle();
    expect(find.text('Select Theme Mode'), findsOneWidget);
    await tester.tap(find.text('Dark Mode'));
    await tester.pumpAndSettle();

    // Verify theme changed to dark mode
    expect(find.text('Dark Mode'), findsOneWidget);
    final BuildContext settingsContext = tester.element(find.text('Settings'));
    expect(Theme.of(settingsContext).brightness, Brightness.dark);

    // Verify FAB is not present on Settings
    expect(find.byType(FloatingActionButton), findsNothing);

    // Go back from Settings to Main App
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Verify Home screen is in dark mode
    final BuildContext homeContext = tester.element(find.text('MoneyTrack'));
    expect(Theme.of(homeContext).brightness, Brightness.dark);
    final Scaffold scaffold = tester.widget(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF0F172A));

    // Verify FAB is present on Home screen
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // 3. Switch to Transactions Tab (Index 1)
    await tester.tap(find.byKey(const Key('nav_transactions')));
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Search note, category, or account...'), findsOneWidget);
    expect(find.text('All Types'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfers'), findsOneWidget);
    expect(find.text('No transactions found'), findsOneWidget);

    // 4. Switch to Analytics Tab (Index 2)
    await tester.tap(find.byKey(const Key('nav_analytics')));
    await tester.pumpAndSettle();

    expect(find.text('Analyse & Visualise'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('No spending data for this period'), findsOneWidget);

    // CRITICAL: Verify the + button is removed on Analyse & Visualise page
    expect(find.byType(FloatingActionButton), findsNothing);

    // 5. Switch to Budgets & Categories Tab (Index 3)
    await tester.tap(find.byKey(const Key('nav_budgets')));
    await tester.pumpAndSettle();

    expect(find.text('Budgets & Categories'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);

    // CRITICAL: Verify the + button at bottom and top-right are removed on Budgets & Categories page
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);

    // Switch to Categories inner tab
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();

    expect(find.text('Expense Categories'), findsOneWidget);
    expect(find.text('Income Categories'), findsOneWidget);
    expect(find.text('Food & Dining'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);

    // Tap a category chip to verify Edit / Delete options appear
    await tester.tap(find.text('Food & Dining'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Category'), findsOneWidget);
    expect(find.text('Delete Category'), findsOneWidget);

    // Close actions sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 6. Test Transaction Addition & Delete Confirmation Permission Dialog
    await tester.tap(find.byKey(const Key('nav_transactions')));
    await tester.pumpAndSettle();

    // Tap Add Transaction button in empty state
    await tester.tap(find.text('Add Transaction'));
    await tester.pumpAndSettle();

    // Fill amount and save
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '150');
    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();

    expect(find.text('General'), findsOneWidget);
    expect(find.text('- ₹ 150.00'), findsOneWidget);

    // Tap delete button to verify permission dialog appears
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Transaction?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap Cancel -> transaction is kept
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('General'), findsOneWidget);

    // Tap delete again and confirm
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No transactions found'), findsOneWidget);

    // 7. Test Login & Register Page via Drawer
    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    expect(find.text('Sign In / Register'), findsWidgets);
    await tester.tap(find.text('Sign In / Register').first);
    await tester.pumpAndSettle();

    // Verify Auth Screen components
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Register'), findsOneWidget);

    // Switch to Register tab
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);

    // Fill registration form
    await tester.enterText(find.widgetWithText(TextField, 'e.g. John Doe'), 'Test User');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. john@example.com'), 'test@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'At least 6 characters'), 'password123');
    await tester.enterText(find.widgetWithText(TextField, 'Re-enter your password'), 'password123');

    // Scroll if needed and submit registration
    await tester.ensureVisible(find.text('Create Free Account'));
    await tester.tap(find.text('Create Free Account'));
    await tester.pumpAndSettle();

    // Verify logged in: open drawer and check user profile
    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('Sign Out'), findsWidgets);

    // 8. Verify clicking username or app icon does NOT sign out or open AuthScreen
    await tester.tap(find.text('Test User'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsNothing);
    expect(find.text('Test User'), findsOneWidget);

    // 9. Verify clicking Sign Out asks for permission (confirmation dialog)
    await tester.drag(find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign Out?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to sign out of MoneyTrack?'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Cancel -> remains logged in
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Test User'), findsOneWidget);

    // Tap Sign Out again and confirm
    await tester.drag(find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
    await tester.pumpAndSettle();

    // Verify signed out: login page is shown directly, NOT the homepage
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('TOTAL BALANCE'), findsNothing);
    expect(find.text('CASH FLOW (THIS MONTH)'), findsNothing);
    expect(find.text('Test User'), findsNothing);
  });
}
