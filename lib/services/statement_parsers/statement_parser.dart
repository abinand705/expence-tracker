import 'dart:io';
import '../../models/bank_statement.dart';

abstract class StatementParser {
  Future<ParsedBankStatement> parse(File file);
}
