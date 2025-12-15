import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_services/api_service_vendor.dart';

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  final TextEditingController _startingPriceController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final VendorServiceApi _vendorApi = VendorServiceApi();


  bool loading = true;
  bool saving = false;

  int? vendorId;
  int? serviceId;
  int? vendorSubcategoryId;
  String? token;


  @override
  void initState() {
    super.initState();
    _loadCredentialsAndData();
  }

  /// Load local cached data and fetch from API
  Future<void> _loadCredentialsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId');
    token = prefs.getString('token');
    serviceId = prefs.getInt('serviceId');
    vendorSubcategoryId = prefs.getInt('vendor_subcategory_id');

    // Load local cache first
    final local = prefs.getString('pricingData');
    if (local != null) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(local);
        _startingPriceController.text = parsed['startingPrice'] ?? '';
        _minPriceController.text = parsed['minPrice'] ?? '';
        _maxPriceController.text = parsed['maxPrice'] ?? '';
      } catch (_) {}
    }

    // Fetch latest data from API
    if (vendorId != null && token != null) {
      await _fetchPricingFromApi();
    }

    setState(() => loading = false);
  }

  /// Fetch pricing from API
  Future<void> _fetchPricingFromApi() async {
    try {
      final data = await _vendorApi.getByVendorId(
        vendorId: vendorId!,
        token: token!,
      );

      if (data == null) return;

      serviceId = data['id'];
      vendorSubcategoryId ??= data['vendor_subcategory_id'];

      final attrs = Map<String, dynamic>.from(data['attributes'] ?? {});

      final startingPrice = attrs['starting_price']?.toString() ?? '';
      final priceRange = attrs['PriceRange']?.toString() ?? '';

      String minPrice = '';
      String maxPrice = '';
      if (priceRange.contains('-')) {
        final parts = priceRange.split('-');
        minPrice = parts[0].trim();
        maxPrice = parts[1].trim();
      }

      setState(() {
        _startingPriceController.text = startingPrice;
        _minPriceController.text = minPrice;
        _maxPriceController.text = maxPrice;
      });

      await _saveLocally();
    } catch (e) {
      debugPrint("❌ Fetch pricing error: $e");
    }
  }


  /// Save locally in SharedPreferences
  Future<void> _saveLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      "startingPrice": _startingPriceController.text,
      "minPrice": _minPriceController.text,
      "maxPrice": _maxPriceController.text,
    };
    await prefs.setString('pricingData', jsonEncode(data));
  }

  /// Save to server via PUT
  Future<void> _saveToServer() async {
    if (vendorId == null || token == null || serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vendor info missing.")),
      );
      return;
    }

    setState(() => saving = true);

    // 🔥 Fetch latest attributes first (SAFETY)
    final latest = await _vendorApi.getByServiceId(
      serviceId: serviceId!,
      token: token!,
    );

    Map<String, dynamic> attributes =
    Map<String, dynamic>.from(latest?['attributes'] ?? {});

    // ✅ Update ONLY pricing-related fields
    attributes.addAll({
      "starting_price": int.tryParse(_startingPriceController.text) ?? 0,
      "PriceRange":
      "${_minPriceController.text} - ${_maxPriceController.text}",
    });

    final body = {
      "vendor_id": vendorId,
      "vendor_subcategory_id": vendorSubcategoryId,
      "attributes": attributes,
    };

    await _saveLocally();

    final success = await _vendorApi.updateService(
      serviceId: serviceId!,
      token: token!,
      body: body,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pricing saved successfully.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save pricing.")),
      );
    }

    setState(() => saving = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0072BB),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Pricing & Packages"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pricing & Packages",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Add your starting price & package price range",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            const Text("Starting Price", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _startingPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "5000",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Price Range", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "2000",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text("-", style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "40000",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00509D),
                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: saving ? null : _saveToServer,
                child: saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text("Save Pricing Details", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
