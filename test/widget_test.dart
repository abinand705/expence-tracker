import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyTrackApp());
    expect(find.text('TOTAL BALANCE'), findsOneWidget);
  });
}
