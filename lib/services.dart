// import 'dart:convert';
// import 'package:http/http.dart' as http;
//
// /// Singleton class to manage vendor service data
// class VendorServiceManager {
//   static final VendorServiceManager _instance = VendorServiceManager._internal();
//   factory VendorServiceManager() => _instance;
//   VendorServiceManager._internal();
//
//   Map<String, dynamic>? vendorData;
//   int? serviceId;
//
//   /// Fetch vendor-service from API by vendor ID
//   Future<void> fetchVendorService(int vendorId, String token) async {
//     print("=====================================");
//     print("📡 FETCHING VENDOR-SERVICE FOR VENDOR ID: $vendorId");
//     print("=====================================");
//
//     try {
//       final response = await http.get(
//         Uri.parse("https://happywedz.com/api/vendor-services/vendor/$vendorId"),
//         headers: {"Authorization": "Bearer $token"},
//       );
//
//       print("📩 GET Response Status: ${response.statusCode}");
//       print("📩 GET Response Body: ${response.body}");
//
//       if (response.statusCode == 200) {
//         final List data = jsonDecode(response.body);
//         if (data.isNotEmpty) {
//           vendorData = Map<String, dynamic>.from(data[0]);
//           serviceId = vendorData!["id"];
//           print("✅ Vendor service data saved locally. Service ID: $serviceId");
//         } else {
//           print("⚠️ GET returned empty list for vendor-service");
//         }
//       } else {
//         print("❌ Failed to fetch vendor-service: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("❌ Exception fetching vendor-service: $e");
//     }
//   }
//
//   /// Get a specific attribute from vendorData safely
//   dynamic getAttribute(String key) {
//     if (vendorData != null && vendorData!["attributes"] != null) {
//       return vendorData!["attributes"][key];
//     }
//     return null;
//   }
//
//   /// Get vendor contact details safely
//   Map<String, dynamic> getContact() {
//     if (vendorData != null &&
//         vendorData!["attributes"] != null &&
//         vendorData!["attributes"]["contact"] != null) {
//       return Map<String, dynamic>.from(vendorData!["attributes"]["contact"]);
//     }
//
//     final attributes = vendorData?["attributes"];
//     if (attributes != null) {
//       return {
//         "name": attributes["name"] ?? "",
//         "email": attributes["email"] ?? "",
//         "phone": attributes["phone"] ?? "",
//         "altPhone": attributes["altPhone"] ?? "",
//         "whatsapp": attributes["whatsapp"] ?? "",
//       };
//     }
//
//     return {};
//   }
//
//   /// Update local vendorData after PUT/POST
//   void updateVendorData(Map<String, dynamic> newData) {
//     if (vendorData != null && newData["attributes"] != null) {
//       final currentAttributes = Map<String, dynamic>.from(vendorData!["attributes"] ?? {});
//       final newAttributes = Map<String, dynamic>.from(newData["attributes"]);
//       vendorData!["attributes"] = {...currentAttributes, ...newAttributes};
//     }
//
//     if (newData["id"] != null) {
//       serviceId = newData["id"];
//     }
//
//     print("🔄 Vendor service data updated locally.");
//     printVendorData();
//   }
//
//   /// Save contact details via PUT API
//   Future<http.Response> saveContact({required String url, required String token, required Map<String, dynamic> body}) async {
//     print("📤 SAVING CONTACT DETAILS via VendorServiceManager PUT");
//     print("URL: $url");
//     print("Body: $body");
//
//     try {
//       final response = await http.put(
//         Uri.parse(url),
//         headers: {
//           "Content-Type": "application/json",
//           "Authorization": "Bearer $token"
//         },
//         body: jsonEncode(body),
//       );
//
//       print("📩 PUT Response: ${response.statusCode} | ${response.body}");
//       return response;
//     } catch (e) {
//       print("❌ Error saving contact details: $e");
//       rethrow;
//     }
//   }
//
//   int? getSubcategoryId() => vendorData?["vendor_subcategory_id"];
//
//   void printVendorData() {
//     print("=====================================");
//     print("📌 CURRENT VENDOR DATA:");
//     print(jsonEncode(vendorData));
//     print("=====================================");
//   }
// }
