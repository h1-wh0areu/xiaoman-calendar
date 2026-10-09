import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({this.baseUrl = 'http://localhost:3000/v1'});

  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> login(String phone, {String code = '000000'}) async {
    await post('/auth/sms/send', {'phone': phone});
    final data = await post('/auth/sms/verify', {'phone': phone, 'code': code});
    if (data['ok'] == true) {
      token = data['accessToken'] as String?;
      return true;
    }
    return false;
  }
}
