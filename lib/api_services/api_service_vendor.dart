import 'dart:convert';
import 'package:http/http.dart' as http;

class VendorServiceApi {
  final String baseUrl = "https://happywedz.com/api";

  /// GET vendor service by vendorId
  Future<Map<String, dynamic>?> getByVendorId({
    required int vendorId,
    required String token,
  }) async {
    final res = await http.get(
      Uri.parse("$baseUrl/vendor-services/vendor/$vendorId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body);
      return list.isNotEmpty ? list[0] : null;
    }
    return null;
  }

  /// GET vendor service by serviceId
  Future<Map<String, dynamic>?> getByServiceId({
    required int serviceId,
    required String token,
  }) async {
    final res = await http.get(
      Uri.parse("$baseUrl/vendor-services/$serviceId"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return null;
  }

  /// CREATE service
  Future<bool> createService({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/vendor-services"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  /// UPDATE service (IMPORTANT)
  Future<bool> updateService({
    required int serviceId,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.put(
      Uri.parse("$baseUrl/vendor-services/$serviceId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }
}
