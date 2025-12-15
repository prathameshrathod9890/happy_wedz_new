import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_services/api_service_vendor.dart';

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
  final VendorServiceApi _vendorApi = VendorServiceApi();


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
    try {
      final data = await _vendorApi.getByVendorId(
        vendorId: vendorId!,
        token: token!,
      );

      if (data == null) return;

      // save serviceId
      serviceId = data["id"];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("serviceId", serviceId!);

      final attributes = Map<String, dynamic>.from(data["attributes"] ?? {});
      _setFieldsFromMap({"attributes": attributes});
      await _saveLocallyFromControllers();
    } catch (e) {
      debugPrint("❌ fetch policies error: $e");
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
    if (vendorId == null || token == null || serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete Basic Info first.")),
      );
      return;
    }

    setState(() => saving = true);

    // 🔥 Fetch latest attributes first
    final latest = await _vendorApi.getByServiceId(
      serviceId: serviceId!,
      token: token!,
    );

    Map<String, dynamic> attributes =
    Map<String, dynamic>.from(latest?["attributes"] ?? {});

    // ✅ Update ONLY policy-related keys
    attributes.addAll({
      "cancellation_policy": _cancellationController.text.trim(),
      "refund_policy": _refundController.text.trim(),
      "payment_terms": _paymentController.text.trim(),
      "tnc": _tncController.text.trim(),
    });

    final body = {
      "vendor_id": vendorId,
      "vendor_subcategory_id": vendorSubcategoryId,
      "attributes": attributes,
    };

    final success = await _vendorApi.updateService(
      serviceId: serviceId!,
      token: token!,
      body: body,
    );

    if (success) {
      await _saveLocallyFromControllers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Policies saved successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save policies")),
      );
    }

    setState(() => saving = false);
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
