import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skybridge02/Services/app_config.dart';

class ApiService {
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not authenticated");
    }

    final token = await user.getIdToken();

    final apiBase = getFunctionsBase();
    final base = endpoint.startsWith('/api/')
        ? apiBase.replaceFirst(RegExp(r'/api/?$'), '')
        : apiBase;

    final response = await http
        .post(
          Uri.parse("$base$endpoint"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("API Error ${response.statusCode}: $decoded");
    }

    return decoded;
  }

  static Future<dynamic> get(String endpoint) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not authenticated");
    }

    final token = await user.getIdToken();

    final apiBase = getFunctionsBase();
    final base = endpoint.startsWith('/api/')
        ? apiBase.replaceFirst(RegExp(r'/api/?$'), '')
        : apiBase;

    final response = await http.get(
      Uri.parse("$base$endpoint"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    ).timeout(const Duration(seconds: 12));

    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("API Error ${response.statusCode}: $decoded");
    }

    return decoded;
  }
}
