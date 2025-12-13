import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LeadDetailScreen extends StatefulWidget {
  final dynamic lead;
  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  bool _isLoading = false;
  List<dynamic> quotationHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchQuotationHistory();
  }

  /// ================= FETCH QUOTATION HISTORY =================
  Future<void> _fetchQuotationHistory() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('authToken');

      if (token == null) return;

      final userId = widget.lead['userId'] ?? widget.lead['user']?['id'];

      final url = Uri.parse(
        "https://happywedz.com/api/request-pricing/vendor/quotation-history?userId=$userId",
      );

      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          quotationHistory = data['quotations'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("❌ Quotation history error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }


  /// ================= SEND QUOTATION =================
  Future<void> _sendQuotation({
    required String leadId,
    required String price,
    required String validTill,
    required String services,
    required String message,
  }) async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('authToken');

      final url = Uri.parse(
        "https://happywedz.com/api/request-pricing/requests/$leadId/quotation",
      );

      final body = jsonEncode({
        "price": int.tryParse(price) ?? 0,
        "validTill": validTill,
        "servicesIncluded":
        services.split(',').map((e) => e.trim()).toList(),
        "message": message,
      });

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        _fetchQuotationHistory(); // 🔥 refresh history
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Quotation sent")),
        );
      }
    } catch (e) {
      debugPrint("❌ Send quotation error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quotations", style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF00509D),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _historyInfo(),
              const SizedBox(height: 12),
              ...quotationHistory.map(_quotationCard).toList(),
              const SizedBox(height: 20),
              _sendButton(),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  /// ================= HISTORY INFO =================
  Widget _historyInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF7FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "You have sent ${quotationHistory.length} quotation(s) to this user.",
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  /// ================= QUOTATION CARD =================
  Widget _quotationCard(dynamic q) {
    final quote = q['quote'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PRICE",
            style: _labelStyle(),
          ),
          Text(
            "₹${quote['price']}",
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Text("SERVICES", style: _labelStyle()),
          Text(
            (quote['servicesIncluded'] as List).join(", "),
          ),
          const SizedBox(height: 10),

          Text("MESSAGE", style: _labelStyle()),
          Text(quote['message']),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "VALID UNTIL ${quote['validTill']}",
              style: const TextStyle(color: Colors.grey),
            ),
          )
        ],
      ),
    );
  }

  /// ================= SEND BUTTON =================
  Widget _sendButton() {
    return ElevatedButton(
      onPressed: () => _showQuotationDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00509D),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        "Send New Quotation",
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  /// ================= DATE PICKER =================
  Future<void> _pickDate(
      BuildContext context,
      TextEditingController controller,
      ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // past date disable
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final formattedDate =
          "${pickedDate.day.toString().padLeft(2, '0')}-"
          "${pickedDate.month.toString().padLeft(2, '0')}-"
          "${pickedDate.year}";
      controller.text = formattedDate;
    }
  }


  void _showQuotationDialog(BuildContext context) {
    final priceCtrl = TextEditingController();
    final servicesCtrl = TextEditingController();
    final validTillCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Send Quotation"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _tf("Price", priceCtrl),
              _tf("Services (comma separated)", servicesCtrl),

              /// ✅ DATE PICKER FIELD
              TextField(
                controller: validTillCtrl,
                readOnly: true,
                onTap: () => _pickDate(context, validTillCtrl),
                decoration: InputDecoration(
                  hintText: "Valid Till",
                  suffixIcon: const Icon(Icons.calendar_month),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              _tf("Message", messageCtrl, max: 4),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (validTillCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select valid date")),
                );
                return;
              }

              _sendQuotation(
                leadId: widget.lead['id'].toString(),
                price: priceCtrl.text,
                services: servicesCtrl.text,
                validTill: validTillCtrl.text,
                message: messageCtrl.text,
              );
            },
            child: const Text("Send"),
          )
        ],
      ),
    );
  }


  Widget _tf(String hint, TextEditingController c, {int max = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: max,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  TextStyle _labelStyle() =>
      const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600);
}



