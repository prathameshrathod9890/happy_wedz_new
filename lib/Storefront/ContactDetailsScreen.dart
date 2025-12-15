import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_services/api_service_vendor.dart';


class ContactDetailsPage extends StatefulWidget {
  final int? vendorId;
  final int? vendorSubcategoryId;

  const ContactDetailsPage({
    Key? key,
    this.vendorId,
    this.vendorSubcategoryId,
  }) : super(key: key);

  @override
  _ContactDetailsPageState createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController primaryPhoneController = TextEditingController();
  final TextEditingController alternativePhoneController = TextEditingController();
  final TextEditingController whatsappController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  String? token;
  int? vendorId;
  int? vendorSubcategoryId;
  int? serviceId;
  final VendorServiceApi _vendorApi = VendorServiceApi();

  Map<String, dynamic> currentAttributes = {}; // <-- store existing attributes

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    await _saveConstructorValues();
    await _loadCredentials();
  }

  Future<void> _saveConstructorValues() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.vendorId != null) {
      await prefs.setInt("vendorId", widget.vendorId!);
    }

    if (widget.vendorSubcategoryId != null) {
      await prefs.setInt("vendor_subcategory_id", widget.vendorSubcategoryId!);
    }

    print("✔ Constructor values saved");
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString("token");
    vendorId = prefs.getInt("vendorId");
    vendorSubcategoryId = prefs.getInt("vendor_subcategory_id");
    serviceId = prefs.getInt("serviceId");

    print("🔐 Token: $token");
    print("🆔 VendorId: $vendorId");
    print("🏷 SubcategoryId: $vendorSubcategoryId");
    print("📌 ServiceId: $serviceId");

    if (token == null || serviceId == null) {
      print("⚠ ERROR: Token or ServiceId missing. Contact details cannot be loaded.");
      setState(() => isLoading = false);
      return;
    }

    await fetchContactDetails();
    setState(() => isLoading = false);
  }

  // Future<void> fetchContactDetails() async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse("https://happywedz.com/api/vendor-services/$serviceId"),
  //       headers: {"Authorization": "Bearer $token"},
  //     );
  //
  //     print("📩 GET Response: ${response.statusCode} | ${response.body}");
  //
  //     if (response.statusCode == 200) {
  //       final parsed = jsonDecode(response.body);
  //       currentAttributes = Map<String, dynamic>.from(parsed["attributes"] ?? {});
  //
  //       final contact = currentAttributes["contact"] ?? {};
  //
  //       contactPersonController.text = contact["name"] ?? currentAttributes["name"] ?? "";
  //       primaryPhoneController.text = contact["phone"] ?? "";
  //       alternativePhoneController.text = contact["altPhone"] ?? "";
  //       whatsappController.text = contact["whatsapp"] ?? "";
  //
  //       print("✅ Contact details loaded successfully");
  //     } else {
  //       print("❌ Failed to load contact details");
  //     }
  //   } catch (e) {
  //     print("❌ Error fetching contact details: $e");
  //   }
  // }
  Future<void> fetchContactDetails() async {
    try {
      final data = await _vendorApi.getByServiceId(
        serviceId: serviceId!,
        token: token!,
      );

      if (data == null) return;

      currentAttributes = Map<String, dynamic>.from(data["attributes"] ?? {});

      final contact = currentAttributes["contact"] ?? {};

      contactPersonController.text =
          contact["name"] ?? currentAttributes["name"] ?? "";

      primaryPhoneController.text = contact["phone"] ?? "";
      alternativePhoneController.text = contact["altPhone"] ?? "";
      whatsappController.text = contact["whatsapp"] ?? "";
    } catch (e) {
      debugPrint("❌ fetchContactDetails error: $e");
    }
  }

  // Future<void> saveContactDetails() async {
  //   if (token == null || serviceId == null) {
  //     ScaffoldMessenger.of(context)
  //         .showSnackBar(SnackBar(content: Text("Missing Token or Service ID")));
  //     return;
  //   }
  //
  //   setState(() => isSaving = true);
  //
  //   // Merge updated contact info into current attributes
  //   currentAttributes["contact"] = {
  //     "name": contactPersonController.text.trim(),
  //     "phone": primaryPhoneController.text.trim(),
  //     "altPhone": alternativePhoneController.text.trim(),
  //     "whatsapp": whatsappController.text.trim(),
  //   };
  //
  //   final requestBody = {
  //     "vendor_id": vendorId,
  //     "vendor_subcategory_id": vendorSubcategoryId,
  //     "attributes": currentAttributes,
  //   };
  //
  //   print("📤 Saving contact details with body: $requestBody");
  //
  //   try {
  //     final response = await http.put(
  //       Uri.parse("https://happywedz.com/api/vendor-services/$serviceId"),
  //       headers: {
  //         "Content-Type": "application/json",
  //         "Authorization": "Bearer $token",
  //       },
  //       body: jsonEncode(requestBody),
  //     );
  //
  //     print("📩 PUT Response: ${response.statusCode} | ${response.body}");
  //
  //     if (response.statusCode == 200) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(SnackBar(content: Text("Contact updated successfully")));
  //       print("✅ Contact details saved successfully");
  //     } else {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
  //       print("❌ Failed to save contact details");
  //     }
  //   } catch (e) {
  //     print("❌ Error saving contact details: $e");
  //   }
  //
  //   setState(() => isSaving = false);
  // }

  Future<void> saveContactDetails() async {
    if (token == null || serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing Token or Service ID")),
      );
      return;
    }

    setState(() => isSaving = true);

    // 🔥 Fetch latest attributes again (safety)
    final latest = await _vendorApi.getByServiceId(
      serviceId: serviceId!,
      token: token!,
    );

    currentAttributes =
    Map<String, dynamic>.from(latest?["attributes"] ?? currentAttributes);

    // ✅ update ONLY contact section
    currentAttributes["contact"] = {
      "name": contactPersonController.text.trim(),
      "phone": primaryPhoneController.text.trim(),
      "altPhone": alternativePhoneController.text.trim(),
      "whatsapp": whatsappController.text.trim(),
    };

    final body = {
      "vendor_id": vendorId,
      "vendor_subcategory_id": vendorSubcategoryId,
      "attributes": currentAttributes,
    };

    final success = await _vendorApi.updateService(
      serviceId: serviceId!,
      token: token!,
      body: body,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact updated successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save contact details")),
      );
    }

    setState(() => isSaving = false);
  }


  Widget field(String label, TextEditingController controller,
      {bool required = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (required ? " *" : ""), style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Contact Details", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      backgroundColor: Color(0xffF2F2F2),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field("Contact Person", contactPersonController, required: true),
              field("Primary Phone", primaryPhoneController, required: true, keyboardType: TextInputType.phone),
              field("Alternative Phone", alternativePhoneController, keyboardType: TextInputType.phone),
              field("WhatsApp Number", whatsappController, keyboardType: TextInputType.phone),

              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveContactDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00509D),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text("Save Contact Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
