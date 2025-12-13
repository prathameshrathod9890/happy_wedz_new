import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PoliciesPage extends StatefulWidget {
  const PoliciesPage({super.key});

  @override
  State<PoliciesPage> createState() => _PoliciesPageState();
}

class _PoliciesPageState extends State<PoliciesPage> {
  final TextEditingController _cancellationController = TextEditingController();
  final TextEditingController _refundController = TextEditingController();
  final TextEditingController _paymentController = TextEditingController();
  final TextEditingController _tncController = TextEditingController();

  bool loading = true;
  bool saving = false;

  int? vendorId;
  int? serviceId;
  int? vendorSubcategoryId;
  String? token;

  @override
  void initState() {
    super.initState();
    print("🔔 PoliciesPage.initState()");
    _attachListeners();
    _loadCredentialsAndData();
  }

  void _attachListeners() {
    _cancellationController.addListener(_autosaveLocally);
    _refundController.addListener(_autosaveLocally);
    _paymentController.addListener(_autosaveLocally);
    _tncController.addListener(_autosaveLocally);
  }

  void _removeListeners() {
    _cancellationController.removeListener(_autosaveLocally);
    _refundController.removeListener(_autosaveLocally);
    _paymentController.removeListener(_autosaveLocally);
    _tncController.removeListener(_autosaveLocally);
  }

  @override
  void dispose() {
    _removeListeners();
    _cancellationController.dispose();
    _refundController.dispose();
    _paymentController.dispose();
    _tncController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentialsAndData() async {
    setState(() => loading = true);
    print("📥 Loading SharedPreferences credentials & local data...");
    final prefs = await SharedPreferences.getInstance();

    vendorId = prefs.getInt('vendorId');
    token = prefs.getString('token');
    serviceId = prefs.getInt('serviceId');
    vendorSubcategoryId = prefs.getInt('vendor_subcategory_id');

    print("🔑 Loaded: vendorId=$vendorId, serviceId=$serviceId, vendor_subcategory_id=$vendorSubcategoryId, token=${token != null ? 'present' : 'null'}");

    // Load locally saved copy first (so UI is instant)
    final local = prefs.getString('policiesData');
    if (local != null) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(local);
        print("📦 Found local policiesData: $parsed");
        _setFieldsFromMap(parsed);
      } catch (e) {
        print("⚠️ Failed to parse local policiesData: $e");
      }
    } else {
      print("📭 No local policiesData found.");
    }

    // If vendorId and token present, fetch server data (this may update serviceId & attributes)
    if (vendorId != null && token != null) {
      await _fetchVendorServiceAndPopulate();
    } else {
      print("⚠ Skipping server fetch (vendorId or token missing).");
    }

    setState(() => loading = false);
  }

  void _setFieldsFromMap(Map<String, dynamic> data) {
    // Accept either an 'attributes' map or direct keys map
    final attributes = data.containsKey('attributes') ? data['attributes'] as Map<String, dynamic> : data;
    print("🔧 _setFieldsFromMap attributes: $attributes");

    _cancellationController.text = attributes['cancellation_policy']?.toString() ?? '';
    _refundController.text = attributes['refund_policy']?.toString() ?? '';
    _paymentController.text = attributes['payment_terms']?.toString() ?? '';
    _tncController.text = attributes['tnc']?.toString() ?? '';
  }

  Future<void> _fetchVendorServiceAndPopulate() async {
    print("📡 Fetching vendor-services for vendorId=$vendorId");
    try {
      final response = await http.get(
        Uri.parse("https://happywedz.com/api/vendor-services/vendor/$vendorId"),
        headers: {
          if (token != null) "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("📩 fetchVendorService response: ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final service = list[0];
          // Extract service id (coerce to int)
          try {
            final rawId = service['id'];
            final intId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
            if (intId != null) {
              serviceId = intId;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('serviceId', serviceId!);
              print("💾 Stored/updated serviceId=$serviceId in SharedPreferences");
            } else {
              print("⚠ service.id missing or not int: $rawId");
            }
          } catch (e) {
            print("⚠ Error parsing service id: $e");
          }

          final attributes = service['attributes'] ?? {};
          if (attributes != null && (attributes is Map)) {
            print("📦 Service attributes: $attributes");
            _setFieldsFromMap({'attributes': attributes});
            // persist locally
            await _saveLocallyFromControllers();
          } else {
            print("ℹ️ No attributes present for service");
          }
        } else {
          print("ℹ️ vendor-services returned empty list");
        }
      } else {
        print("❌ fetch vendor-services failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetching vendor-service: $e");
    }
  }

  Future<void> _autosaveLocally() async {
    // Called on every change; keep lightweight and quick
    await _saveLocallyFromControllers();
  }

  Future<void> _saveLocallyFromControllers() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {
      "cancellation_policy": _cancellationController.text.trim(),
      "refund_policy": _refundController.text.trim(),
      "payment_terms": _paymentController.text.trim(),
      "tnc": _tncController.text.trim(),
    };
    await prefs.setString('policiesData', jsonEncode(data));
    print("💾 Autosaved policies locally: $data");
  }

  Future<void> _savePoliciesToServer() async {
    print("💾 Attempting to save policies to server...");

    if (vendorId == null || token == null) {
      print("❌ Missing vendorId or token; cannot save. vendorId=$vendorId token=${token != null}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login and complete Basic Info first.")),
      );
      return;
    }

    if (serviceId == null) {
      print("❌ serviceId is null. Basic Info root screen must be saved first (which creates serviceId).");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete Basic Info (root) to create serviceId first.")),
      );
      return;
    }

    setState(() => saving = true);

    final requestBody = {
      "vendor_id": vendorId,
      "vendor_subcategory_id": vendorSubcategoryId,
      "attributes": {
        "cancellation_policy": _cancellationController.text.trim(),
        "refund_policy": _refundController.text.trim(),
        "payment_terms": _paymentController.text.trim(),
        "tnc": _tncController.text.trim(),
      }
    };

    print("📦 PUT request body: $requestBody");

    try {
      final response = await http.put(
        Uri.parse("https://happywedz.com/api/vendor-services/$serviceId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(requestBody),
      );

      print("📩 Save response: ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // success -> update local copy as well
        await _saveLocallyFromControllers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Policies saved successfully.")));
        print("✅ Policies saved successfully on server.");
      } else {
        String msg = "Failed to save policies";
        try {
          final Map<String, dynamic> parsed = jsonDecode(response.body);
          msg = parsed['error'] ?? parsed['message'] ?? msg;
        } catch (e) {
          print("⚠ Failed to parse error body: $e");
        }
        print("❌ Save failed: $msg");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      print("❌ Error while saving policies: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error saving policies")));
    } finally {
      setState(() => saving = false);
    }
  }

  void _resetForm() async {
    print("♻️ Reset: clearing controllers and removing local storage");
    _cancellationController.clear();
    _refundController.clear();
    _paymentController.clear();
    _tncController.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('policiesData');
    print("🗑 Removed policiesData from SharedPreferences");
    setState(() {}); // refresh
  }

  Widget _field(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,3))],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI consistent with Basic Info screen
    return Scaffold(
      appBar: AppBar(
        title: const Text("Policies & Terms", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0072BB),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      backgroundColor: const Color(0xffF2F2F2),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Policies & Terms", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text("Fill in your cancellation, refund, payment policies and terms.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),

              _field("Cancellation Policy", _cancellationController, maxLines: 3),
              _field("Refund Policy", _refundController, maxLines: 3),
              _field("Payment Terms", _paymentController, maxLines: 1),
              _field("Terms & Conditions (TnC)", _tncController, maxLines: 4),

              const SizedBox(height: 10),

              Center(
                child: ElevatedButton(
                  onPressed: saving ? null : _savePoliciesToServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00509D),
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save Policies", style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: OutlinedButton(
                  onPressed: _resetForm,
                  child: const Text("Reset"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
