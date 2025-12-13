import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusinessDetailsPage extends StatefulWidget {
  @override
  _BusinessDetailsPageState createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  TextEditingController businessName = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController phone = TextEditingController();
  TextEditingController city = TextEditingController();
  TextEditingController stateCtrl = TextEditingController();
  TextEditingController zip = TextEditingController();
  TextEditingController website = TextEditingController();
  TextEditingController yearsInBusi = TextEditingController();
  TextEditingController firstName = TextEditingController();
  TextEditingController lastName = TextEditingController();

  TextEditingController currentPassword = TextEditingController();
  TextEditingController newPassword = TextEditingController();
  TextEditingController confirmPassword = TextEditingController();

  String? profileImageUrl;
  bool showPasswordSection = false;
  File? profileImage;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final vendorId = prefs.getInt("vendorId");

    if (vendorId == null) return;

    final url = Uri.parse("https://happywedz.com/api/vendor/$vendorId");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          businessName.text = data["businessName"] ?? "";
          email.text = data["email"] ?? "";
          phone.text = data["phone"] ?? "";
          city.text = data["city"] ?? "";
          stateCtrl.text = data["state"] ?? "";
          zip.text = data["zip"] ?? "";
          website.text = data["website"] ?? "";
          yearsInBusi.text = data["years_in_business"]?.toString() ?? "";
          firstName.text = data["firstName"] ?? "";
          lastName.text = data["lastName"] ?? "";
          profileImageUrl = data["profileImage"];
        });
      }
    } catch (e) {
      print("❌ Error loading data: $e");
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final vendorId = prefs.getInt("vendorId");
    if (vendorId == null) return;

    final url = Uri.parse("https://happywedz.com/api/vendor/$vendorId");

    final body = {
      "businessName": businessName.text.trim(),
      "city": city.text.trim(),
      "email": email.text.trim(),
      "facebook_link": "",
      "firstName": firstName.text.trim(),
      "lastName": lastName.text.trim(),
      "instagram_link": "",
      "phone": phone.text.trim(),
      "state": stateCtrl.text.trim(),
      "vendor_type_id": 2,
      "website": website.text.trim(),
      "years_in_business": int.tryParse(yearsInBusi.text.trim()) ?? 0,
      "zip": zip.text.trim(),
      "profileImage": profileImageUrl,
    };

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Profile Updated")));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Update failed")));
      }
    } catch (e) {
      print("❌ Error: $e");
    }
  }

  pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      final url = await uploadImage(file);
      if (url != null) {
        setState(() {
          profileImageUrl = url;
          profileImage = null;
        });
      }
    }
  }

  Future<String?> uploadImage(File img) async {
    final prefs = await SharedPreferences.getInstance();
    final vendorId = prefs.getInt("vendorId");

    var request = http.MultipartRequest(
        "POST",
        Uri.parse("https://happywedz.com/api/vendor/uploadProfile"));

    request.fields["vendorId"] = vendorId.toString();
    request.files.add(await http.MultipartFile.fromPath("image", img.path));

    final response = await request.send();
    final res = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      final data = json.decode(res.body);
      return data["imageUrl"];
    }
    return null;
  }

  Future<void> changePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final vendorId = prefs.getInt("vendorId");

    if (vendorId == null) return;

    final url = Uri.parse("https://happywedz.com/api/vendor/change-password");

    final body = {
      "vendorId": vendorId,
      "oldPassword": currentPassword.text,
      "newPassword": newPassword.text,
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Password Updated Successfully")),
        );
        currentPassword.clear();
        newPassword.clear();
        confirmPassword.clear();
        setState(() => showPasswordSection = false);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Password update failed")));
      }
    } catch (e) {
      print("❌ ERROR: $e");
    }
  }

  Widget field(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (profileImage != null) {
      imageProvider = FileImage(profileImage!);
    } else if (profileImageUrl != null) {
      imageProvider = NetworkImage(profileImageUrl!);
    }

    return Scaffold(
      backgroundColor: Color(0xffF2F2F2),
      appBar: AppBar(
        title: Text("Business Details", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? Icon(Icons.person, size: 45)
                          : null,
                    ),
                    SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00509D),// button background
                        foregroundColor: Colors.white,      // button text color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Choose File"),
                    )

                  ],
                ),
                SizedBox(height: 20),

                field("Business Name", businessName),
                field("Email", email),
                field("Mobile Number", phone),
                field("City", city),
                field("State", stateCtrl),
                field("Zip", zip),
                field("Website", website),
                field("Years in Business", yearsInBusi),
                field("First Name", firstName),
                field("Last Name", lastName),

                SizedBox(height: 10),

                GestureDetector(
                  onTap: () =>
                      setState(() => showPasswordSection = !showPasswordSection),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text("Change Password",
                                style: TextStyle(fontWeight: FontWeight.w600))),
                        Icon(
                          showPasswordSection
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        )
                      ],
                    ),
                  ),
                ),

                if (showPasswordSection) ...[
                  SizedBox(height: 10),
                  field("Current Password", currentPassword),
                  field("New Password", newPassword),
                  field("Confirm Password", confirmPassword),

                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00509D),
                        foregroundColor: Colors.white,



                      ),
                      child: Text("Update Password"),
                    ),
                  ),
                ],

                SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saveData,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Color(0xFF00509D),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Save Business Details",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
