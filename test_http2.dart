import 'package:http/http.dart' as http;
void main() async {
  try {
    final res = await http.get(Uri.parse('https://moneytrack-demo.web.app/latest.json'));
    print('Status: ${res.statusCode}');
    print('Body: ${res.body}');
  } catch (e) {
    print('Type: ${e.runtimeType}');
    print('String: ${e.toString()}');
  }
}
