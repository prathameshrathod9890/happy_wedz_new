import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Fetch FAQ answers
Future<List<Map<String, dynamic>>> fetchFaqAnswers(int vendorId) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken') ?? "";

  final response = await http.get(
    Uri.parse("https://happywedz.com/api/faq-answers/$vendorId"),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json"
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['answers']);
  } else {
    throw Exception("Failed to fetch FAQ answers");
  }
}

// Save FAQ answers
Future<bool> saveFaqAnswers({
  required int vendorId,
  required int vendorTypeId,
  required List<Map<String, dynamic>> answers,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('authToken') ?? "";

  final body = {
    "vendorId": vendorId,
    "vendorTypeId": vendorTypeId,
    "answers": answers,
  };

  final response = await http.post(
    Uri.parse("https://happywedz.com/api/faq-answers/save"),
    headers: {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json"
    },
    body: jsonEncode(body),
  );

  return response.statusCode == 200;
}
