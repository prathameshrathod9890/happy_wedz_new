import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController _offerTitleController = TextEditingController();
  TextEditingController _codeController = TextEditingController();
  TextEditingController _valueController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();

  bool _isActive = false;
  bool _termsAccepted = false;
  DateTime? _startDate;
  DateTime? _endDate;

  int? vendorId;
  int? serviceId;
  int? vendorSubcategoryId;
  String? token;

  bool loading = false;
  bool saving = false;

  List<Map<String, dynamic>> existingPromotions = [];
  int? editIndex; // <-- Track which promotion is being edited

  @override
  void initState() {
    super.initState();
    _loadCredentialsAndData();
  }

  Future<void> _loadCredentialsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId');
    token = prefs.getString('token');
    serviceId = prefs.getInt('serviceId');
    vendorSubcategoryId = prefs.getInt('vendor_subcategory_id');

    if (serviceId != null && token != null) {
      await _fetchExistingPromotions();
    }
  }

  Future<void> _fetchExistingPromotions() async {
    setState(() => loading = true);

    try {
      final response = await http.get(
        Uri.parse("https://happywedz.com/api/vendor-services/$serviceId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final attributes = data['attributes'] ?? {};
        final deals = attributes['deals'] ?? [];

        setState(() {
          existingPromotions = List<Map<String, dynamic>>.from(deals);
        });
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _savePromotion() async {
    if (vendorId == null || serviceId == null || vendorSubcategoryId == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete Basic Info first.")),
      );
      return;
    }

    setState(() => saving = true);

    Map<String, dynamic> promotionData = {
      "title": _offerTitleController.text.trim(),
      "code": _codeController.text.trim(),
      "value": int.tryParse(_valueController.text.trim()),
      "description": _descriptionController.text.trim(),
      "active": _isActive,
      "startDate": _startDate?.toIso8601String(),
      "endDate": _endDate?.toIso8601String(),
    };

    if (editIndex == null) {
      existingPromotions.add(promotionData);
    } else {
      existingPromotions[editIndex!] = promotionData;
      editIndex = null;
    }

    final requestBody = {
      "vendor_id": vendorId,
      "vendor_subcategory_id": vendorSubcategoryId,
      "attributes": {
        "deals": existingPromotions,
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
          SnackBar(content: Text("Promotion saved successfully.")),
        );
      }
    } catch (_) {}

    setState(() => saving = false);
    _resetForm();
  }

  void _resetForm() {
    setState(() {
      _offerTitleController.clear();
      _codeController.clear();
      _valueController.clear();
      _descriptionController.clear();
      _isActive = false;
      _startDate = null;
      _endDate = null;
      _termsAccepted = false;
      editIndex = null;
    });
  }

  _pickDate({required bool isStart}) async {
    DateTime initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Promotion Details", style: TextStyle(
          color: Colors.white
        ),),
        backgroundColor: const Color(0xFF0072BB),
        //foregroundColor: Colors.white,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [

            // EXISTING CARDS LIST
            if (existingPromotions.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Existing Offers",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 10),

              ...existingPromotions.asMap().entries.map((entry) {
                int index = entry.key;
                var promo = entry.value;

                return Card(
                  elevation: 3,
                  child: ListTile(
                    title: Text(promo["title"] ?? ""),
                    subtitle: Text("Code: ${promo["code"] ?? ''}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            setState(() {
                              editIndex = index;
                              _offerTitleController.text = promo["title"] ?? "";
                              _codeController.text = promo["code"] ?? "";
                              _valueController.text = promo["value"]?.toString() ?? "";
                              _descriptionController.text = promo["description"] ?? "";
                              _isActive = promo["active"] ?? false;
                              _startDate = promo["startDate"] != null ? DateTime.parse(promo["startDate"]) : null;
                              _endDate = promo["endDate"] != null ? DateTime.parse(promo["endDate"]) : null;
                              _termsAccepted = true;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              existingPromotions.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              SizedBox(height: 20),
            ],

            TextFormField(
              controller: _offerTitleController,
              decoration: InputDecoration(labelText: "Offer Title", border: OutlineInputBorder()),
            ),
            SizedBox(height: 15),

            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(labelText: "Promo Code", border: OutlineInputBorder()),
            ),
            SizedBox(height: 15),

            Row(children: [
              Switch(
                value: _isActive,
                onChanged: (val) {
                  setState(() => _isActive = val);
                },
              ),
              Text(_isActive ? "Active" : "Inactive"),
            ]),
            SizedBox(height: 15),

            TextFormField(
              controller: _valueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Discount Value",
                border: OutlineInputBorder(),
                suffixText: "%",
              ),
            ),
            SizedBox(height: 15),

            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Start Date",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(isStart: true),
                ),
              ),
              controller: TextEditingController(
                text: _startDate != null ? DateFormat("dd-MM-yyyy").format(_startDate!) : "",
              ),
            ),
            SizedBox(height: 15),

            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "End Date",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(isStart: false),
                ),
              ),
              controller: TextEditingController(
                text: _endDate != null ? DateFormat("dd-MM-yyyy").format(_endDate!) : "",
              ),
            ),
            SizedBox(height: 15),

            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(labelText: "Description", border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),

            CheckboxListTile(
              value: _termsAccepted,
              onChanged: (val) {
                setState(() => _termsAccepted = val ?? false);
              },
              title: Text("I confirm this offer and its terms"),
            ),

            SizedBox(height: 20),

            // RESET BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetForm,
                child: Text("Reset Form"),
              ),
            ),
            SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _savePromotion,
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00509D)),
                child: saving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(editIndex == null ? "Save Promotion" : "Update Promotion"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
