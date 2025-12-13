import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SocialNetworkPage extends StatefulWidget {
  const SocialNetworkPage({super.key});

  @override
  State<SocialNetworkPage> createState() => _SocialNetworkPageState();
}

class _SocialNetworkPageState extends State<SocialNetworkPage> {
  TextEditingController facebookController = TextEditingController();
  TextEditingController instagramController = TextEditingController();
  bool loading = false;
  bool saving = false;

  int? vendorId;
  String? token;

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  Future<void> _loadVendorData() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId');
    token = prefs.getString('token');

    print("🔑 Loaded vendorId: $vendorId, token: $token");

    // Load links from SharedPreferences first
    final fbLink = prefs.getString('facebook_link');
    final instaLink = prefs.getString('instagram_link');

    if (fbLink != null) facebookController.text = fbLink;
    if (instaLink != null) instagramController.text = instaLink;

    print("📦 Loaded links from SharedPreferences: FB=$fbLink, IG=$instaLink");

    // If links not in SharedPreferences, fetch from API
    if ((fbLink == null || instaLink == null) && vendorId != null && token != null) {
      await _fetchLinksFromAPI();
    }
  }

  Future<void> _fetchLinksFromAPI() async {
    setState(() => loading = true);
    try {
      final response = await http.get(
        Uri.parse("https://happywedz.com/api/vendor/$vendorId"),
        headers: {"Authorization": "Bearer $token"},
      );

      print("📩 Fetch API response: ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        facebookController.text = data['facebook_link'] ?? '';
        instagramController.text = data['instagram_link'] ?? '';

        // Save fetched links locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('facebook_link', facebookController.text);
        await prefs.setString('instagram_link', instagramController.text);

        print("✅ Loaded links from API and saved locally.");
      } else {
        print("❌ Failed to fetch vendor links.");
      }
    } catch (e) {
      print("❌ Error fetching vendor links: $e");
    }
    setState(() => loading = false);
  }

  Future<void> saveLinks() async {
    if (vendorId == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vendor ID or token missing")),
      );
      return;
    }

    setState(() => saving = true);

    final requestBody = {
      "facebook_link": facebookController.text.trim(),
      "instagram_link": instagramController.text.trim(),
    };

    try {
      final response = await http.put(
        Uri.parse("https://happywedz.com/api/vendor/$vendorId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(requestBody),
      );

      print("📩 PUT response: ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Save locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('facebook_link', facebookController.text.trim());
        await prefs.setString('instagram_link', instagramController.text.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Links saved successfully")),
        );
        print("✅ Links saved locally and on server.");
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["error"] ?? "Failed to save links")),
        );
        print("❌ Failed to save links: ${data["error"]}");
      }
    } catch (e) {
      print("❌ Error saving links: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving links")),
      );
    }

    setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF2F2F2),
      appBar: AppBar(
        title: const Text(
          "Professional Links",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor:  const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add Your Professional Links",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            // FACEBOOK
            const Text(
              "Facebook",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.facebook, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: facebookController,
                    decoration: InputDecoration(
                      hintText: "https://www.facebook.com/username",
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // INSTAGRAM
            const Text(
              "Instagram",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00509D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: instagramController,
                    decoration: InputDecoration(
                      hintText: "https://www.instagram.com/username",
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // SAVE BUTTON
            ElevatedButton(
              onPressed: saving ? null : saveLinks,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00509D),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                "Save Links",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
