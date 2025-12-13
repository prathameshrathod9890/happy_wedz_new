import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'SignUp.dart';
import 'HomeScreen.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isPasswordHidden = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkIfLoggedIn();
  }

  // ---------------- Load saved email/password ----------------
  void _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailC.text = prefs.getString('email') ?? '';
      _passwordC.text = prefs.getString('savedPassword') ?? '';
      _rememberMe = _emailC.text.isNotEmpty && _passwordC.text.isNotEmpty;
    });
  }

  // ---------------- Check if user is already logged in ----------------
  void _checkIfLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      });
    }
  }

  // ---------------- Login API ----------------
  Future<void> _loginVendor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final url = Uri.parse('https://happywedz.com/api/vendor/login');
    final body = {
      "email": _emailC.text.trim(),
      "password": _passwordC.text.trim(),
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      final data = json.decode(response.body);
      print("🔸 Login Response: ${response.body}");

      if (response.statusCode == 200 &&
          (data["message"]?.toLowerCase().contains("success") ?? false)) {
        final prefs = await SharedPreferences.getInstance();
        final vendorData = data['vendor'] ?? data['data'] ?? {};

        // 🟢 Debug Prints
        print("📢 Vendor ID: ${vendorData['id']}");
        print("📢 Vendor Type ID: ${vendorData['vendor_type_id']}");
        print("📢 Business Name: ${vendorData['businessName']}");
        print("📢 Profile Completed: ${vendorData['profile_completed']}");

        // ✅ Save all vendor details (same keys as SignUp)
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('authToken', data['token'] ?? "");
        await prefs.setString('token', data['token'] ?? "");
        await prefs.setInt('vendorId', vendorData['id']);
        await prefs.setInt('vendorTypeId', vendorData['vendor_type_id']);
        await prefs.setString('businessName', vendorData['businessName'] ?? "");
        await prefs.setString('email', vendorData['email'] ?? "");
        await prefs.setString('phone', vendorData['phone'] ?? "");
        await prefs.setString('profileImage', vendorData['profileImage'] ?? "");
        await prefs.setBool(
          'profileCompleted',
          vendorData['profile_completed'] ?? false,
        );

        // ✅ Get Vendor Type Name from API (so florist stays florist)
        try {
          final typeRes = await http.get(
            Uri.parse(
              'https://happywedz.com/api/vendor-types/${vendorData['vendor_type_id']}',
            ),
          );
          if (typeRes.statusCode == 200) {
            final typeData = json.decode(typeRes.body);
            await prefs.setString(
              'vendorTypeName',
              typeData['name'].toString(),
            );
            print("🌸 Vendor Type Name: ${typeData['name']}");
          } else {
            print("⚠️ Could not fetch vendor type name, saving ID only");
          }
        } catch (e) {
          print("❌ Vendor type fetch failed: $e");
        }

        // ✅ Navigate properly
        _showSnack(data["message"] ?? "Login successful");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _showSnack(data["message"] ?? "Login failed");
      }
    } catch (e) {
      print("❌ Login error: $e");
      _showSnack("An error occurred. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Please enter Email";
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return "Please enter a valid Email";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00509D),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Image.asset("assets/images/logoo.png", height: 80),
              const SizedBox(height: 8),
              const Text(
                "Vendor Login",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          _emailC,
                          "Email",
                          Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _passwordC,
                          "Password",
                          Icons.lock,
                          obscureText: _isPasswordHidden,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordHidden
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordHidden = !_isPasswordHidden;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (val) =>
                                  setState(() => _rememberMe = val!),
                            ),
                            const Text("Remember me"),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00509D),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _loginVendor,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white, // added white color
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUp()),
                  );
                },
                child: const Text(
                  "Don't have an account? Sign Up",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) return "Please enter $hint";
            return null;
          },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        suffixIcon: suffixIcon,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
