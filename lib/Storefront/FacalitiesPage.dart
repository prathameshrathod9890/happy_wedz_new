import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FacilitiesPage extends StatefulWidget {
  const FacilitiesPage({super.key});

  @override
  State<FacilitiesPage> createState() => _FacilitiesPageState();
}

class _FacilitiesPageState extends State<FacilitiesPage> {
  TextEditingController roomsController = TextEditingController();
  TextEditingController parkingController = TextEditingController();
  TextEditingController cateringController = TextEditingController();
  TextEditingController decorController = TextEditingController();
  TextEditingController offeringsController = TextEditingController();
  TextEditingController deliveryController = TextEditingController();
  TextEditingController travelController = TextEditingController();
  TextEditingController happyWedzSinceController = TextEditingController();
  TextEditingController areaController = TextEditingController();

  String? indoorOutdoor;
  String? alcoholPolicy;

  bool loading = false;
  bool saving = false;

  int? vendorId;
  int? serviceId;
  int? vendorSubcategoryId;
  String? token;

  final allowedIndoorOutdoor = ["Indoor", "Outdoor", "Both"];
  final allowedAlcohol = ["allowed", "not_allowed", "own_alcohol"];

  @override
  void initState() {
    super.initState();
    _loadCredentialsAndData();

    // Autosave fields on change
    roomsController.addListener(_autosaveLocally);
    parkingController.addListener(_autosaveLocally);
    cateringController.addListener(_autosaveLocally);
    decorController.addListener(_autosaveLocally);
    offeringsController.addListener(_autosaveLocally);
    deliveryController.addListener(_autosaveLocally);
    travelController.addListener(_autosaveLocally);
    happyWedzSinceController.addListener(_autosaveLocally);
    areaController.addListener(_autosaveLocally);
  }

  @override
  void dispose() {
    roomsController.dispose();
    parkingController.dispose();
    cateringController.dispose();
    decorController.dispose();
    offeringsController.dispose();
    deliveryController.dispose();
    travelController.dispose();
    happyWedzSinceController.dispose();
    areaController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentialsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId');
    serviceId = prefs.getInt('serviceId');
    vendorSubcategoryId = prefs.getInt('vendor_subcategory_id');
    token = prefs.getString('token');

    // Load locally saved facilities first
    if (vendorId != null) {
      final savedJson = prefs.getString('facilitiesData_$vendorId');
      if (savedJson != null) {
        final Map<String, dynamic> data = jsonDecode(savedJson);
        _setFieldsFromMap(data);
      }
    }

    // Fetch latest from API and merge
    if (serviceId != null && token != null) {
      await _fetchExistingDataFromAPI();
    }

    setState(() {});
  }

  void _setFieldsFromMap(Map<String, dynamic> data) {
    roomsController.text = data['rooms']?.toString() ?? '';
    parkingController.text = data['parking'] ?? '';
    cateringController.text = data['catering_policy'] ?? '';
    decorController.text = data['decor_policy'] ?? '';
    offeringsController.text = data['offerings'] ?? '';
    deliveryController.text = data['delivery_time'] ?? '';
    travelController.text = data['travel_info'] ?? '';
    happyWedzSinceController.text = data['happywedz_since'] ?? '';
    areaController.text = data['area'] ?? '';
    indoorOutdoor = allowedIndoorOutdoor.contains(data['indoor_outdoor']) ? data['indoor_outdoor'] : null;
    alcoholPolicy = allowedAlcohol.contains(data['alcohol_policy']) ? data['alcohol_policy'] : null;
  }

  Future<void> _fetchExistingDataFromAPI() async {
    setState(() => loading = true);
    try {
      final response = await http.get(
        Uri.parse("https://happywedz.com/api/vendor-services/$serviceId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Map<String, dynamic> attributes = Map<String, dynamic>.from(data['attributes'] ?? {});

        // Merge: Only overwrite fields if they are empty locally
        final merged = {
          "rooms": roomsController.text.isEmpty ? attributes['rooms'] : int.tryParse(roomsController.text),
          "parking": parkingController.text.isEmpty ? attributes['parking'] : parkingController.text,
          "catering_policy": cateringController.text.isEmpty ? attributes['catering_policy'] : cateringController.text,
          "decor_policy": decorController.text.isEmpty ? attributes['decor_policy'] : decorController.text,
          "offerings": offeringsController.text.isEmpty ? attributes['offerings'] : offeringsController.text,
          "delivery_time": deliveryController.text.isEmpty ? attributes['delivery_time'] : deliveryController.text,
          "travel_info": travelController.text.isEmpty ? attributes['travel_info'] : travelController.text,
          "happywedz_since": happyWedzSinceController.text.isEmpty ? attributes['happywedz_since'] : happyWedzSinceController.text,
          "area": areaController.text.isEmpty ? attributes['area'] : areaController.text,
          "indoor_outdoor": indoorOutdoor ?? attributes['indoor_outdoor'],
          "alcohol_policy": alcoholPolicy ?? attributes['alcohol_policy'],
        };

        _setFieldsFromMap(merged);
        await _autosaveLocally(); // persist merged data
      }
    } catch (e) {
      print("Error fetching facilities from API: $e");
    }
    setState(() => loading = false);
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _autosaveLocally() async {
    if (vendorId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {
      "rooms": int.tryParse(roomsController.text),
      "parking": parkingController.text,
      "catering_policy": cateringController.text,
      "decor_policy": decorController.text,
      "offerings": offeringsController.text,
      "delivery_time": deliveryController.text,
      "travel_info": travelController.text,
      "happywedz_since": happyWedzSinceController.text,
      "area": areaController.text,
      "indoor_outdoor": indoorOutdoor,
      "alcohol_policy": alcoholPolicy,
    };
    await prefs.setString('facilitiesData_$vendorId', jsonEncode(data));
  }

  Future<void> _saveData() async {
    if (vendorId == null || serviceId == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete Basic Info first.")),
      );
      return;
    }

    setState(() => saving = true);

    final requestBody = {
      "vendor_id": vendorId,
      if (vendorSubcategoryId != null) "vendor_subcategory_id": vendorSubcategoryId,
      "attributes": {
        "rooms": int.tryParse(roomsController.text),
        "parking": parkingController.text,
        "catering_policy": cateringController.text,
        "decor_policy": decorController.text,
        "offerings": offeringsController.text,
        "delivery_time": deliveryController.text,
        "travel_info": travelController.text,
        "happywedz_since": happyWedzSinceController.text,
        "area": areaController.text,
        "indoor_outdoor": indoorOutdoor,
        "alcohol_policy": alcoholPolicy,
      }
    };

    try {
      final response = await http.put(
        Uri.parse("https://happywedz.com/api/vendor-services/$serviceId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Facilities details saved successfully.")),
        );
        await _autosaveLocally(); // save after API success
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["error"] ?? "Failed to save")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving facilities details")),
      );
    }

    setState(() => saving = false);
  }

  Widget _buildTextField(String title, TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: controller, maxLines: maxLines, decoration: _inputDecoration(hint)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDropdown({
    required String title,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    Map<String, String>? labels,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          decoration: _inputDecoration("Choose"),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(labels?[e] ?? e))).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF2F2F2),
      appBar: AppBar(
        title: const Text("Facilities & Features", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Facilities & Features", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),

              _buildTextField("Number of Rooms", roomsController, "Enter number of rooms"),
              _buildTextField("Car Parking", parkingController, "There is sufficient parking available"),

              _buildDropdown(
                title: "Indoor/Outdoor",
                value: indoorOutdoor,
                items: allowedIndoorOutdoor,
                onChanged: (v) => setState(() {
                  indoorOutdoor = v;
                  _autosaveLocally();
                }),
              ),

              _buildDropdown(
                title: "Alcohol Policy",
                value: alcoholPolicy,
                items: allowedAlcohol,
                labels: const {
                  "allowed": "Allowed",
                  "not_allowed": "Not Allowed",
                  "own_alcohol": "Own Alcohol"
                },
                onChanged: (v) => setState(() {
                  alcoholPolicy = v;
                  _autosaveLocally();
                }),
              ),

              _buildTextField("Catering Policy", cateringController, "Inhouse catering only"),
              _buildTextField("Decor Policy", decorController, "Outside Decorators Permitted"),
              _buildTextField("Offerings (comma-separated)", offeringsController, "Photographer, DJ, Catering, etc."),
              _buildTextField("Delivery Time", deliveryController, "e.g. 2–3 weeks"),
              _buildTextField("Travel Info", travelController, "e.g. Travel within city, All over India"),
              _buildTextField("HappyWedz Since", happyWedzSinceController, "since 6 years"),
              _buildTextField("Area / Capacity Details", areaController, "Lawn 800 Seating | 1000 Floating", maxLines: 3),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00509D),
                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Facilities Details", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
