import 'lib/utils/expense_parser.dart';

void main() {
  final msg3 = "Rs 500 will be debited tomorrow";
  final result = ExpenseParser.parsePendingDue(msg3, DateTime.now());
  print("Result: $result");
  if (result != null) {
    print("Amount: ${result.amount}, Due: ${result.dueDate}");
  }
}
