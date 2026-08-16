import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/widgets/transaction_card.dart';
import 'package:expense_tracker/models/transaction.dart';

void main() {
  testWidgets('TransactionCard displays transaction details correctly', (WidgetTester tester) async {
    final transaction = Transaction(
      id: 'txn1',
      amount: 150.0,
      type: TransactionType.expense,
      merchant: 'Test Merchant',
      category: 'Food',
      date: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionCard(transaction: transaction),
      ),
    ));

    expect(find.text('Test Merchant'), findsOneWidget);
    expect(find.textContaining('Food'), findsOneWidget);
    expect(find.textContaining('150'), findsOneWidget);
  });
}
