import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PreferredVendorsPage extends StatefulWidget {
  const PreferredVendorsPage({super.key});

  @override
  State<PreferredVendorsPage> createState() => _PreferredVendorsPageState();
}

class _PreferredVendorsPageState extends State<PreferredVendorsPage> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> suggestions = [];
  List<Map<String, dynamic>> selectedVendors = [];
  bool loading = false;
  bool loadingVendorData = true;
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

  /// Load saved credentials and vendors
  Future<void> _loadCredentialsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId');
    serviceId = prefs.getInt('serviceId');
    vendorSubcategoryId = prefs.getInt('vendor_subcategory_id');
    token = prefs.getString('token');

    // Load saved vendors for this vendorId
    if (vendorId != null) {
      final key = 'preferredVendors_$vendorId';
      final savedVendorsJson = prefs.getStringList(key) ?? [];
      selectedVendors = savedVendorsJson
          .map((v) => jsonDecode(v) as Map<String, dynamic>)
          .toList();
    }

    // Fetch API vendors and merge
    if (vendorId != null && serviceId != null && token != null) {
      await fetchExistingPreferredVendors();
    }

    setState(() => loadingVendorData = false);
  }

  /// Fetch existing preferred vendors from API
  Future<void> fetchExistingPreferredVendors() async {
    try {
      final response = await http.get(
        Uri.parse("https://happywedz.com/api/vendor-services/vendor/$vendorId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final apiVendors = data[0]['attributes']?['preferred_vendors'] ?? [];
          final List<Map<String, dynamic>> apiVendorList = apiVendors
              .map<Map<String, dynamic>>((v) => {
            'id': v['id'],
            'name': v['name'] ?? '',
            'location': v['city'] ?? '',
            'rating': v['rating'] ?? '0',
          })
              .toList();

          // Merge saved local vendors
          for (var v in selectedVendors) {
            if (!apiVendorList.any((apiV) => apiV['id'] == v['id'])) {
              apiVendorList.add(v);
            }
          }

          setState(() {
            selectedVendors = apiVendorList;
          });
        }
      }
    } catch (e) {
      print("Error fetching vendors: $e");
    }
  }

  /// Search vendors API
  void searchVendors(String query) async {
    if (query.isEmpty) {
      setState(() => suggestions = []);
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http.get(
        Uri.parse("https://happywedz.com/api/vendor-services?search=$query"),
        headers: token != null ? {"Authorization": "Bearer $token"} : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final vendors = data['data'] as List<dynamic>? ?? [];
        setState(() {
          suggestions = vendors.map<Map<String, dynamic>>((vendor) {
            final attr = vendor['attributes'] ?? {};
            return {
              'id': vendor['id'],
              'name': attr['vendor_name'] ?? '',
              'location': attr['city'] ?? '',
              'rating': attr['rating'] ?? '0',
            };
          }).toList();
        });
      } else {
        setState(() => suggestions = []);
      }
    } catch (e) {
      setState(() => suggestions = []);
      print("Error searching vendors: $e");
    }

    setState(() => loading = false);
  }

  /// Add vendor to selected list
  void addVendor(Map<String, dynamic> vendor) async {
    if (!selectedVendors.any((v) => v['id'] == vendor['id'])) {
      setState(() {
        selectedVendors.add(vendor);
        suggestions = [];
        searchController.clear();
      });
      await _saveVendorsLocally();
    }
  }

  /// Remove vendor from selected list
  void removeVendor(Map<String, dynamic> vendor) async {
    setState(() {
      selectedVendors.removeWhere((v) => v['id'] == vendor['id']);
    });
    await _saveVendorsLocally();
  }

  /// Save selected vendors locally
  Future<void> _saveVendorsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    if (vendorId != null) {
      final key = 'preferredVendors_$vendorId';
      final vendorJsonList =
      selectedVendors.map((v) => jsonEncode(v)).toList();
      await prefs.setStringList(key, vendorJsonList);
    }
  }

  /// Save selected vendors to API
  Future<void> savePreferredVendors() async {
    if (vendorId == null || serviceId == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot save: Missing vendor or service info.")),
      );
      return;
    }

    setState(() => saving = true);

    final List<int> vendorIds = selectedVendors.map<int>((v) => v['id'] as int).toList();

    final Map<String, dynamic> requestBody = {
      "vendor_id": vendorId,
      "attributes": {"preferred_vendors": vendorIds},
    };

    // Include vendorSubcategoryId only if it exists
    if (vendorSubcategoryId != null) {
      requestBody["vendor_subcategory_id"] = vendorSubcategoryId;
    }

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
        // Save locally
        final prefs = await SharedPreferences.getInstance();
        final key = 'preferredVendors_$vendorId';
        final vendorJsonList = selectedVendors.map((v) => jsonEncode(v)).toList();
        await prefs.setStringList(key, vendorJsonList);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Preferred vendors saved successfully.")),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["error"] ?? "Failed to save")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving preferred vendors")),
      );
    }

    setState(() => saving = false);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF2F2F2),
      appBar: AppBar(
        title: const Text("Preferred Vendors",
            style: TextStyle(color: Colors.white)),
        backgroundColor:  const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loadingVendorData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Preferred Vendors",
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchController,
                    onChanged: searchVendors,
                    decoration: InputDecoration(
                      hintText: "Search vendors...",
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: saving ? null : savePreferredVendors,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00509D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Save Preferred Vendors",
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 10),
                  if (loading) const LinearProgressIndicator(),
                  ...suggestions.map((vendor) => ListTile(
                    title: Text(vendor['name'] ?? ''),
                    subtitle: Text(vendor['location'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text((vendor['rating'] ?? 0).toString()),
                      ],
                    ),
                    onTap: () => addVendor(vendor),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (selectedVendors.isNotEmpty)
              const Text("Selected Vendors",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...selectedVendors.map((vendor) => Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendor['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(vendor['location'] ?? ''),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text((vendor['rating'] ?? 0).toString()),
                          ],
                        )
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => removeVendor(vendor),
                      icon: const Icon(Icons.close, color: Colors.red))
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }
}
