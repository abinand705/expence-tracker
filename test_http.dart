import 'package:http/http.dart' as http;
void main() async {
  try {
    await http.get(Uri.parse('https://invalid.domain.that.does.not.exist'));
  } catch (e) {
    print('Type: ${e.runtimeType}');
    print('String: ${e.toString()}');
  }
}
