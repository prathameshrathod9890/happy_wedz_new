import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../chat_screen/chat_screenn.dart';

class LeadDetailScreen extends StatefulWidget {
  final dynamic lead;
  final String? conversationId;
  const LeadDetailScreen({super.key, required this.lead, required this.conversationId});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen>
    with SingleTickerProviderStateMixin {
  late String currentStatus;
  late AnimationController _controller;
  late Animation<double> fadeAnim;
  bool _isLoading = false;
  List<dynamic> quotationHistory = [];

  @override

  @override
  void initState() {
    super.initState();
    currentStatus = widget.lead['status'] ?? 'Pending';

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // 🔥 IMPORTANT
    _fetchQuotationHistory();
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  /// ✅ PATCH API to update status
  Future<void> _updateStatus(String newStatus) async {
    try {
      setState(() => _isLoading = true);

      // ✅ Load auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('authToken');

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No auth token found. Please log in.")),
        );
        return;
      }

      // ✅ Use correct ID — adjust if your API returns nested data
      // final leadId = widget.lead['_id'] ?? widget.lead['id'] ?? widget.lead['requestId'];
      final leadId = widget.lead['id'].toString();

      if (leadId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lead ID missing.")),
        );
        return;
      }

      final url = Uri.parse("https://happywedz.com/api/inbox/request/$leadId/status");
      print("🟢 PATCH -> $url");

      final body = jsonEncode({"newStatus": newStatus.toLowerCase()});
      print("📦 Body: $body");

      final response = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: body,
      );

      print("🟣 Response ${response.statusCode}: ${response.body}");

      if (response.statusCode == 200) {
        setState(() => currentStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Status updated to $newStatus")),
        );

        Navigator.pop(context, true); // ✅ trigger refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to update status (${response.statusCode})"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("🔥 Exception while updating status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchQuotationHistory() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('authToken');
      if (token == null) return;

      final userId = widget.lead['userId'] ?? widget.lead['user']?['id'];
      print("🟢 Fetching quotation history for userId: $userId");


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

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No auth token found. Please log in.")),
        );
        return;
      }

      final url = Uri.parse("https://happywedz.com/api/request-pricing/requests/$leadId/quotation");

      final servicesList = services
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final body = jsonEncode({
        "price": int.tryParse(price) ?? 0,
        "validTill": validTill,
        "servicesIncluded": servicesList,
        "message": message,
      });

      print("📤 Sending POST request to: $url");
      print("📦 Request body: $body");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: body,
      );

      print("📥 Response status: ${response.statusCode}");
      print("📥 Raw response body: ${response.body}");


      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchQuotationHistory(); // 🔥 ensure fresh data

        Navigator.of(context).pop(); // close send dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Quotation sent successfully!")),
        );

        _showQuotationHistoryDialog(context);
      }

      else {
        print("❌ Error from API (${response.statusCode}): ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to send quotation"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stack) {
      print("⚠️ Exception while sending quotation: $e");
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Something went wrong. Please try again. $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    print("✅ FULL LEAD DATA => ${widget.lead}");
    final name = "${lead['firstName'] ?? ''} ${lead['lastName'] ?? ''}".trim();
    final email = lead['email'] ?? 'N/A';
    final phone = lead['phone'] ?? lead['phoneNumber'] ?? 'N/A';
    final eventDate = lead['eventDate'] ?? 'N/A';
    final receivedDate = lead['createdAt'] ?? 'N/A';
    final message = lead['message'] ?? 'No message';

    Color statusColor = _getStatusColor(currentStatus);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Lead Details'),
        centerTitle: true,
        backgroundColor: const  Color(0xFF00509D),
        foregroundColor: Colors.white,


      ),

      body: Stack(
        children: [
          FadeTransition(
            opacity: fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Hero(
                    tag: lead['id'].toString(),
                    child: _buildProfileCard(name),
                  ),
                  const SizedBox(height: 20),
                  _buildAnimatedBox("Email", email),
                  _buildAnimatedBox("Phone", phone),
                  _buildAnimatedBox("Event Date", eventDate),
                  _buildAnimatedBox("Received", receivedDate),
                  const SizedBox(height: 20),
                  _buildStatus(currentStatus, statusColor),
                  const SizedBox(height: 20),
                  _buildMessageCard(message),
                  const SizedBox(height: 25),
                  _buildStatusButtons(),
                  const SizedBox(height: 40),
                  _actionButtons(name, lead),

                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4682B4), // Steel Azure
                ),
              ),
            ),

        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {

      case 'booked':
        return const Color(0xFF003F88); // Deep Steel Blue (Primary)

      case 'pending':
        return const Color(0xFF4A90E2); // Medium Sky Blue

      case 'declined':
        return const Color(0xFF89C2D9); // Light Desaturated Blue

      default:
        return const Color(0xFFBFD7ED); // Very light blue
    }
  }


  Widget _buildProfileCard(String name) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const  Color(0xFF4682B4), // ← UPDATED CARD COLOR
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white, // ← text unchanged
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }


  Widget _buildAnimatedBox(String title, String value) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(fadeAnim),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 3),
              color: Colors.black12,
            )
          ],
        ),
        child: Row(
          children: [
            Text(
              "$title: ",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(String status, Color color) {
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildMessageCard(String message) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message,
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildStatusButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statusButton("Pending", const Color(0xFF4A90E2)),   // Medium Blue
        _statusButton("Booked", const Color(0xFF003F88)),    // Dark Steel Blue
        _statusButton("Declined", const Color(0xFF89C2D9)),  // Light Blue
      ],
    );
  }


  Widget _statusButton(String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: ElevatedButton(
            onPressed: () => _updateStatus(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.15),
              foregroundColor: color,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }



  Widget _actionButtons(String name, dynamic lead) {
    final leadId = lead['id'].toString(); // <-- FIXED
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            // onPressed: () => _showQuotationDialog(context),
            onPressed: () async {
              await _fetchQuotationHistory();
              _showQuotationHistoryDialog(context);
            },

            icon: const Icon(Icons.reply),
            label: const Text("Reply to Enquiry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4682B4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: ElevatedButton.icon(

            onPressed: () {
              print("🟢 Chat open with conversationId: ${widget.conversationId}");
              print("🟢 Lead ID: $leadId");

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    receiverName: name,
                    receiverId: lead['id'].toString(),
                    conversationId: widget.conversationId!,
                  ),
                ),
              );
            },

            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text("Chat Now"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4682B4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }


  void _showQuotationDialog(BuildContext context) {
    final TextEditingController priceCtrl = TextEditingController();
    final TextEditingController servicesCtrl = TextEditingController();
    final TextEditingController validTillCtrl = TextEditingController();
    final TextEditingController messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Centered Title
                  Center(
                    child: Column(
                      children: const [
                        Text(
                          "Quotations",
                          style: TextStyle(
                            fontSize: 22,
                            color: Color(0xFF00509D), // title color
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text("Fill up details",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Price
                  const Text("Price"),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "0",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Services
                  const Text("Services"),
                  const SizedBox(height: 6),
                  TextField(
                    controller: servicesCtrl,
                    decoration: InputDecoration(
                      hintText: "e.g., Photography, Videography, Album",
                      helperText:
                      "Enter service details. This is sent as a list to the API.",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Valid Till Date
                  const Text("Valid Till Date"),
                  const SizedBox(height: 6),
                  TextField(
                    controller: validTillCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: "dd-mm-yyyy",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            validTillCtrl.text =
                            "${pickedDate.day}-${pickedDate.month}-${pickedDate.year}";
                          }
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Message
                  const Text("Message"),
                  const SizedBox(height: 6),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: "Your Message",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Final Send button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // final leadId = widget.lead['_id']?.toString() ??
                        //     widget.lead['id']?.toString();
                        final leadId = widget.lead['id'].toString();

                        if (leadId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Lead ID missing.")),
                          );
                          return;
                        }

                        if (priceCtrl.text.isEmpty ||
                            validTillCtrl.text.isEmpty ||
                            servicesCtrl.text.isEmpty ||
                            messageCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please fill all fields.")),
                          );
                          return;
                        }

                        _sendQuotation(
                          leadId: leadId,
                          price: priceCtrl.text,
                          validTill: validTillCtrl.text,
                          services: servicesCtrl.text,
                          message: messageCtrl.text,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00509D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:  Text(
                        "Send",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,  // <-- White text
                        ),
                      ),

                    ),
                  ),

                ],
              ),
            ),
          ),
        );
      },
    );
  }


  void _showQuotationHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    /// 🔹 HEADER
                    const Center(
                      child: Text(
                        "Previous Quotations",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00509D),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    /// 🔹 INFO BOX (SAME AS OLD)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDF7FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "You have sent ${quotationHistory.length} quotation(s) to this user.",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// 🔹 QUOTATION CARDS (OLD UI)
                    if (quotationHistory.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: Center(
                          child: Text(
                            "No quotations sent yet.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...quotationHistory.map((q) {
                        final quote = q['quote'];

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// PRICE
                              const Text(
                                "PRICE",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "₹${quote['price']}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 10),

                              /// SERVICES
                              const Text(
                                "SERVICES",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                (quote['servicesIncluded'] as List).join(", "),
                              ),

                              const SizedBox(height: 10),

                              /// MESSAGE
                              const Text(
                                "MESSAGE",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(quote['message'] ?? ''),

                              const SizedBox(height: 10),

                              /// VALID DATE
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "VALID UNTIL ${quote['validTill']}",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 20),

                    /// 🔹 SEND NEW QUOTATION BUTTON
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showQuotationDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00509D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Send New Quotation",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              /// ❌ CLOSE ICON
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

