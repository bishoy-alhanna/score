import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Test backend connectivity
  print('Testing backend connection...');

  try {
    final response = await http.post(
      Uri.parse('http://score.al-hanna.com/api/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
      body: json.encode({
        'username': 'bfawzy',
        'password': 'bfawzybfawzy',
        'organization_name': 'youth26',
      }),
    );

    print('Response Status: ${response.statusCode}');
    print('Response Headers: ${response.headers}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Login successful! Token: ${data['access_token']}');
    } else {
      print('Login failed with status: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
    print('This might be a CORS issue or network connectivity problem');
  }
}
