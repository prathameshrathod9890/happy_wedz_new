import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'Login.dart';
import 'HomeScreen.dart';

class VendorType {
  final int id;
  final String name;

  VendorType({required this.id, required this.name});

  factory VendorType.fromJson(Map<String, dynamic> json) {
    return VendorType(
      id: json['id'],
      name: json['name'],
    );
  }
}

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _passwordC = TextEditingController();

  bool _agreeTerms = false;
  bool _isPasswordHidden = true;
  bool _isSubmitting = false;

  List<VendorType> _vendorTypes = [];
  VendorType? _selectedVendorType;
  bool _isLoadingVendorTypes = true;

  String? _selectedCountry;
  String? _selectedCity;
  List<String> _countries = [];
  Map<String, List<String>> _countryCities = {};
  bool _isLoadingCountries = true;

  @override
  void initState() {
    super.initState();
    _fetchVendorTypes();
    _fetchCountries();
  }

  // ---------------- Fetch Vendor Types ----------------
  Future<void> _fetchVendorTypes() async {
    try {
      final response =
      await http.get(Uri.parse('https://happywedz.com/api/vendor-types'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _vendorTypes = data.map((e) => VendorType.fromJson(e)).toList();
          _isLoadingVendorTypes = false;
        });
      } else {
        throw Exception('Failed to load vendor types');
      }
    } catch (e) {
      setState(() => _isLoadingVendorTypes = false);
      print("Error loading vendor types: $e");
    }
  }

  // ---------------- Fetch Countries & Cities ----------------
    Future<void> _fetchCountries() async {
      setState(() => _isLoadingCountries = true);
      try {
        final response = await http
            .get(Uri.parse('https://countriesnow.space/api/v0.1/countries'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List countriesData = data['data'];
          Map<String, List<String>> countryCitiesMap = {};
          List<String> countryList = [];
          for (var country in countriesData) {
            countryList.add(country['country']);
            countryCitiesMap[country['country']] =
            List<String>.from(country['cities']);
          }
          setState(() {
            _countries = countryList;
            _countryCities = countryCitiesMap;
            _isLoadingCountries = false;
          });
        } else {
          throw Exception('Failed to fetch countries');
        }
      } catch (e) {
        print("Error fetching countries: $e");
        setState(() => _isLoadingCountries = false);
      }
    }

  // ---------------- Country / City Selection ----------------
  Future<void> _selectCountry() async {
    if (_isLoadingCountries) return;
    final selected = await showSearch<String>(
      context: context,
      delegate: _SearchDelegate(_countries, title: "Select Country"),
    );

    if (selected != null) {
      setState(() {
        _selectedCountry = selected;
        _selectedCity = null;
      });
    }
  }

  Future<void> _selectCity() async {
    if (_selectedCountry == null) return;
    final cities = _countryCities[_selectedCountry!] ?? [];
    final selected = await showSearch<String>(
      context: context,
      delegate: _SearchDelegate(cities, title: "Select City"),
    );
    if (selected != null) {
      setState(() {
        _selectedCity = selected;
      });
    }
  }

  // ---------------- Registration ----------------
  Future<void> _registerVendor() async {
    if (!_agreeTerms) {
      _showSnack("Please agree to the Terms & Conditions");
      return;
    }

    setState(() => _isSubmitting = true);

    final url = Uri.parse('https://happywedz.com/api/vendor/register');

    print("📢 Vendor Type Selected: ${_selectedVendorType?.name ?? 'No vendor type selected'}");


    final body = {
      "businessName": _businessNameC.text.trim(),
      "country": _selectedCountry ?? "",
      "city": _selectedCity ?? "",
      "phone": _phoneC.text.trim(),
      "email": _emailC.text.trim(),
      "password": _passwordC.text.trim(),
      "vendor_type_id": _selectedVendorType?.id.toString() ?? "",
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      print("🔸 Register Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data["success"] == true ||
            data["status"] == "success" ||
            data["message"]?.toString().toLowerCase().contains("success") == true) {

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('vendorId', data['vendor']['id']);
          await prefs.setString('authToken', data['token']);
          await prefs.setString('vendorType', 'photographers'); // optional
          // Save login info
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('token', data['token'] ?? "");
          await prefs.setString('businessName', _businessNameC.text.trim());
          await prefs.setString('email', _emailC.text.trim());
          await prefs.setString('profileImage', data['profile_image'] ?? "");

          // Save vendorTypeName
          if (_selectedVendorType != null) {
            await prefs.setString('vendorTypeName', _selectedVendorType!.name.trim().toLowerCase());
          }

          // Save vendorId from response
          if (data["vendor"] != null) {
            final vendor = data["vendor"];
            await prefs.setInt('vendorId', vendor['id']);
            await prefs.setInt('vendorTypeId', vendor['vendor_type_id']);
            print("✅ Saved vendorId: ${vendor['id']}");
          }

          _showSnack("Registration successful!");

          // Check if there are pending FAQ answers
          if (prefs.containsKey('pendingFaqAnswers')) {
            final pending = prefs.getString('pendingFaqAnswers');
            if (pending != null) {
              _sendPendingFaqAnswers(jsonDecode(pending), prefs.getString('token') ?? "", prefs.getInt('vendorId') ?? 0);
            }
          }


          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()
              ),
                  (route) => false,
            );
          });

        }
        // else {
        //   _showSnack(data["message"] ?? "Registration failed, please try again");
        // }
      }  else {
        _showSnack("User already exists with this email or phone number.");
      }
    } catch (e) {
      print("❌ Register error: $e");
      _showSnack("An error occurred. Please try again.");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendPendingFaqAnswers(List<dynamic> answers, String token, int vendorId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = {
        "vendorId": vendorId,
        "vendorTypeId": prefs.getInt('vendorTypeId') ?? 1,
        "answers": answers,
      };

      final response = await http.post(
        Uri.parse("https://happywedz.com/api/faq-answers/save"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        prefs.remove('pendingFaqAnswers');
        print("✅ Pending FAQ answers submitted successfully");
      } else {
        print("❌ Failed to submit pending FAQ answers: ${response.body}");
      }
    } catch (e) {
      print("⚠️ Error sending pending FAQ answers: $e");
    }
  }
  Future<void> submitFaqAnswer(Map<String, dynamic> answerData) async {
    final prefs = await SharedPreferences.getInstance();

    final vendorId = prefs.getInt('vendorId');
    final token = prefs.getString('authToken');

    if (vendorId == null || token == null) {
      _showSnack("Vendor ID or token missing. Please log in again.");
      return;
    }

    final url = Uri.parse('https://happywedz.com/api/vendor/submit-faq'); // replace with your actual endpoint

    final body = {
      "vendor_id": vendorId,
      ...answerData, // include your FAQ answer data here
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // if your API expects Bearer token
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        _showSnack(data["message"] ?? "FAQ submitted successfully!");
      } else {
        final data = json.decode(response.body);
        _showSnack("Submission failed: ${data['message'] ?? response.statusCode}");
      }
    } catch (e) {
      print("❌ FAQ submission error: $e");
      _showSnack("An error occurred. Please try again.");
    }
  }


  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------- Validators ----------------
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return "Please enter Phone Number";
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return "Phone number must be exactly 10 digits";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Please enter Email";
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return "Please enter a valid Email";
    }
    return null;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00509D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Image.asset("assets/images/logoo.png", height: 80),
              const SizedBox(height: 8),
              const Text(
                "Join as a Vendor",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
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
                          _businessNameC,
                          "Business Name",
                          Icons.store,
                        ),
                        const SizedBox(height: 12),
                        _buildVendorTypeDropdown(),
                        const SizedBox(height: 12),
                        _buildCountryCityFields(),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _emailC,
                          "Email",
                          Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _phoneC,
                          "Phone Number",
                          Icons.phone,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _passwordC,
                          "Password",
                          Icons.lock,
                          obscureText: _isPasswordHidden,
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordHidden
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _isPasswordHidden = !_isPasswordHidden;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: _agreeTerms,
                              onChanged: (val) =>
                                  setState(() => _agreeTerms = val!),
                            ),
                            Expanded(
                              child: Text(
                                "I agree to the Terms & Conditions",
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
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
                              // onPressed: _isSubmitting
                              //     ? null
                              //     : () {
                              //   if (_formKey.currentState!.validate() &&
                              //       _agreeTerms) {
                              //     _registerVendor();
                              //   }
                              // }
                              onPressed: _isSubmitting
                                  ? null
                                  : () {
                                if (!_agreeTerms) {
                                  _showSnack("please accept terms and conditions");
                                  return;
                                }

                                if (_formKey.currentState!.validate()) {
                                  _registerVendor();
                                }
                              },

                              child: _isSubmitting
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : const Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
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
                    MaterialPageRoute(builder: (context) => const Login()),
                  );
                },
                child: const Text(
                  "Already have an account? Log in",
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

  // ---------------- Helpers ----------------
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
      validator: validator ??
              (value) {
            if (value == null || value.isEmpty) return "Please enter $hint";
            return null;
          },
    );
  }

  Widget _buildVendorTypeDropdown() {
    if (_isLoadingVendorTypes) return const CircularProgressIndicator();

    return DropdownButtonFormField<VendorType>(
      isExpanded: true,
      value: _selectedVendorType,
      decoration: _dropdownDecoration(),
      hint: const Text("Select Business Category"),
      items: _vendorTypes
          .map((vendor) =>
          DropdownMenuItem(value: vendor, child: Text(vendor.name)))
          .toList(),
      onChanged: (val) => setState(() => _selectedVendorType = val),
      validator: (val) =>
      val == null ? "Please select Business Category" : null,
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildCountryCityFields() {
    return Column(
      children: [
        TextFormField(
          readOnly: true,
          controller: TextEditingController(text: _selectedCountry),
          decoration: InputDecoration(
            hintText: "Select Country",
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.public),
          ),
          onTap: _selectCountry,
          validator: (val) =>
          val == null || val.isEmpty ? "Please select country" : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          readOnly: true,
          controller: TextEditingController(text: _selectedCity),
          decoration: InputDecoration(
            hintText: "Select City",
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.location_city),
          ),
          onTap: _selectCity,
          validator: (val) =>
          val == null || val.isEmpty ? "Please select city" : null,
        ),
      ],
    );
  }
}

// ---------------- Search Delegate ----------------
class _SearchDelegate extends SearchDelegate<String> {
  final List<String> items;
  final String title;

  _SearchDelegate(this.items, {required this.title})
      : super(searchFieldLabel: title);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results =
    items.where((e) => e.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(results[i]),
        onTap: () => close(context, results[i]),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions =
    items.where((e) => e.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(suggestions[i]),
        onTap: () => close(context, suggestions[i]),
      ),
    );
  }
}
