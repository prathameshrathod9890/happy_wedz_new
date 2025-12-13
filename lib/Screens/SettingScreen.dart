import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Color(0xFF00509D),
        foregroundColor: Colors.white,

        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildSectionTitle("Account"),
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: "Change Password",
            onTap: () => _showChangePasswordDialog(context),
          ),
          const SizedBox(height: 24),
          _buildSignOutButton(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ✅ Change Password API
  Future<void> _updatePassword(
      BuildContext context,
      String oldPass,
      String newPass,
      String confirmPass,
      ) async {
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match")),
      );
      return;
    }

    final url = Uri.parse("https://happywedz.com/api/vendor/change-password");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("authToken") ?? "";
    final vendorId = prefs.getInt("vendorId");

    print("📤 Sending Request:");
    print("vendorId: $vendorId");
    print("oldPassword: $oldPass");
    print("newPassword: $newPass");
    print("token: $token");

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
        },
        body: {
          "vendorId": vendorId.toString(),
          "oldPassword": oldPass,
          "newPassword": newPass,
        },
      );

      print("📥 Response Status: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      final jsonResponse = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(jsonResponse["message"] ?? "Response received")),
      );
    } catch (e) {
      print("❌ ERROR: $e");
    }
  }

  // ✅ Change Password Dialog
  void _showChangePasswordDialog(BuildContext context) {
    final oldPassC = TextEditingController();
    final newPassC = TextEditingController();
    final confirmPassC = TextEditingController();

    bool hideOld = true;
    bool hideNew = true;
    bool hideConfirm = true;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Change Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPassC,
                    obscureText: hideOld,
                    decoration: InputDecoration(
                      hintText: "Current Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideOld ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            hideOld = !hideOld;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassC,
                    obscureText: hideNew,
                    decoration: InputDecoration(
                      hintText: "New Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            hideNew = !hideNew;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassC,
                    obscureText: hideConfirm,
                    decoration: InputDecoration(
                      hintText: "Confirm New Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                          hideConfirm ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            hideConfirm = !hideConfirm;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updatePassword(
                      context,
                      oldPassC.text.trim(),
                      newPassC.text.trim(),
                      confirmPassC.text.trim(),
                    );
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // ───────────────────────── UI PARTS ─────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00509D)),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text(
          "Sign Out",
          style: TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00509D),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () {
          // Confirm Dialog
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Sign Out"),
              content: const Text("Are you sure you want to sign out?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Sign Out",
                    style: TextStyle(color: Colors.pinkAccent[200]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
