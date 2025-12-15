import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../api_services/api_service_vendor.dart';

class MenusPage extends StatefulWidget {
  const MenusPage({super.key});

  @override
  _MenusPageState createState() => _MenusPageState();
}

class _MenusPageState extends State<MenusPage> {
  final TextEditingController vegPriceController = TextEditingController();
  final TextEditingController nonVegPriceController = TextEditingController();
  final VendorServiceApi _vendorApi = VendorServiceApi();

  bool isLoading = true;
  bool isSaving = false;

  int? vendorId;
  String? token;
  int? serviceId;

  @override
  void initState() {
    super.initState();
    _loadData();

    vegPriceController.addListener(_autosaveLocally);
    nonVegPriceController.addListener(_autosaveLocally);
  }

  @override
  void dispose() {
    vegPriceController.dispose();
    nonVegPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt("vendorId");
    token = prefs.getString("token");
    serviceId = prefs.getInt("serviceId");

    // Load saved data from local
    if (vendorId != null) {
      final savedJson = prefs.getString("menuData_$vendorId");
      if (savedJson != null) {
        final Map<String, dynamic> data = jsonDecode(savedJson);
        vegPriceController.text = data["veg_price"]?.toString() ?? "";
        nonVegPriceController.text = data["non_veg_price"]?.toString() ?? "";
      }
    }

    // Load from API
    if (serviceId != null && token != null) {
      await fetchMenuData();
    }

    setState(() => isLoading = false);
  }

  Future<void> fetchMenuData() async {
    try {
      final data = await _vendorApi.getByServiceId(
        serviceId: serviceId!,
        token: token!,
      );

      if (data == null) return;

      final attributes = Map<String, dynamic>.from(data["attributes"] ?? {});

      if (vegPriceController.text.isEmpty) {
        vegPriceController.text =
            attributes["veg_price"]?.toString() ?? "";
      }

      if (nonVegPriceController.text.isEmpty) {
        nonVegPriceController.text =
            attributes["non_veg_price"]?.toString() ?? "";
      }

      await _autosaveLocally();
    } catch (e) {
      debugPrint("❌ fetch menu error: $e");
    }
  }


  Future<void> _autosaveLocally() async {
    if (vendorId == null) return;
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> data = {
      "veg_price": vegPriceController.text.trim(),
      "non_veg_price": nonVegPriceController.text.trim(),
    };

    await prefs.setString("menuData_$vendorId", jsonEncode(data));
  }

  Future<void> saveMenus() async {
    if (vendorId == null || token == null || serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing vendor or service info")),
      );
      return;
    }

    setState(() => isSaving = true);

    // 🔥 Fetch latest attributes first (SAFETY)
    final latest = await _vendorApi.getByServiceId(
      serviceId: serviceId!,
      token: token!,
    );

    Map<String, dynamic> attributes =
    Map<String, dynamic>.from(latest?["attributes"] ?? {});

    // ✅ Update ONLY menu-related fields
    attributes.addAll({
      "veg_price": vegPriceController.text.trim(),
      "non_veg_price": nonVegPriceController.text.trim(),
    });

    final body = {
      "vendor_id": vendorId,
      "attributes": attributes,
    };

    final success = await _vendorApi.updateService(
      serviceId: serviceId!,
      token: token!,
      body: body,
    );

    if (success) {
      await _autosaveLocally();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Menus saved successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save menus")),
      );
    }

    setState(() => isSaving = false);
  }


  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        title: const Text("Menus", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Menus (for Caterers)",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Veg Price Per Plate",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    keyboardType: TextInputType.number,
                    controller: vegPriceController,
                    decoration: _inputDecoration(
                        "Enter veg price per plate"),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    "Non-Veg Price Per Plate",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    keyboardType: TextInputType.number,
                    controller: nonVegPriceController,
                    decoration: _inputDecoration(
                        "Enter non-veg price per plate"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveMenus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00509D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(
                  color: Colors.white,
                )
                    : const Text(
                  "Save Menus",
                  style:
                  TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
