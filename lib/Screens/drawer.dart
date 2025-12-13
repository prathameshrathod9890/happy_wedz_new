import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../Storefront/StoreFront.dart';
import 'Login.dart';

class BusinessDrawer extends StatefulWidget {
  const BusinessDrawer({Key? key}) : super(key: key);

  @override
  State<BusinessDrawer> createState() => _BusinessDrawerState();
}

class _BusinessDrawerState extends State<BusinessDrawer> {
  String userName = "";
  String userEmail = "";
  String coverImage = "";

  bool _isLoading = true;

  int leadCount = 0;
  int viewsCount = 0;
  int? vendorId;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVendorId();
  }

Future<void> _loadVendorId() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    vendorId = prefs.getInt("vendorId");
  });
}
  Future<void> _contactSupport() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String fromEmail = prefs.getString('email') ?? "";

    final Uri emailUri = Uri(
      scheme: "mailto",
      path: "pranjal.anantkamal@gmail.com",
      query: "subject=Support Request"
          "&body=Hello,\n\nMy registered email is: $fromEmail\n\nWrite your query here...",
    );

    try {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("❌ Email launch error: $e");
    }
  }

  /// ✅ Load user data
  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      userName = prefs.getString('businessName') ?? "Vendor Name";
      userEmail = prefs.getString('email') ?? "vendor@example.com";
      coverImage = prefs.getString('coverImage') ?? "";
      leadCount = prefs.getInt('lead_count') ?? 0;
      viewsCount = prefs.getInt('views_count') ?? 0;
      _isLoading = false;
    });
  }

  /// ✅ Pick Image
  Future<void> _pickCoverImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coverImage', pickedFile.path);

    setState(() {
      coverImage = pickedFile.path;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Cover image updated")),
    );
  }

  /// ✅ Remove Image
  Future<void> _removeCoverImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('coverImage');

    setState(() {
      coverImage = "";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Cover image removed")),
    );
  }

  /// ✅ Show Edit Options
  void _showEditOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.blue),
              title: const Text("Change Photo"),
              onTap: () {
                Navigator.pop(context);
                _pickCoverImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Remove Photo"),
              onTap: () {
                Navigator.pop(context);
                _removeCoverImage();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Drawer(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // onTap: _showEditOptions,
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.pink[100],
                  image: coverImage.isNotEmpty
                      ? DecorationImage(
                    image: coverImage.startsWith('http')
                        ? NetworkImage(coverImage)
                        : FileImage(File(coverImage))
                    as ImageProvider,
                    fit: BoxFit.cover,
                  )
                      : null,
                ),

                child: Container(
                  color: coverImage.isEmpty
                      ? const Color(0xFFE0F7FA)
                      : Colors.transparent,
                  padding: const EdgeInsets.only(
                    left: 16,
                    bottom: 16,
                    top: 40,
                    right: 16,
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                userEmail,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.black,
                                  size: 20,
                                ), onPressed: () { _showEditOptions(); },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Positioned(
              //   top: 12,
              //   right: 12,
              //   child: Container(
              //     decoration: BoxDecoration(
              //       color: Colors.black.withOpacity(0.6),
              //       shape: BoxShape.circle,
              //     ),
              //     child: IconButton(
              //       icon: const Icon(
              //         Icons.edit,
              //         color: Colors.white,
              //         size: 20,
              //       ),
              //       onPressed: _showEditOptions,
              //     ),
              //   ),
              // ),
            ],
          ),



          /// Stats
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceAround,
          //     children: [
          //       _statItem("Leads", "$leadCount"),
          //       _statItem("Reviews", "45"),
          //       _statItem("Views", "$viewsCount"),
          //     ],
          //   ),
          // ),

          /// MENU ITEMS
          Expanded(

            child: Container(
              color: Colors.white,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // _drawerItem(
                  //   context,
                  //   Icons.info_outline,
                  //   "Public Info",
                  //   const Placeholder(),
                  //   iconColor: const Color(0xFF4682B4),
                  // ),

                  ListTile(
                    leading: const Icon(Icons.storefront_outlined,
                        color: Color(0xFF4682B4)),
                    title: const Text("Storefront"),
                    onTap: () {
                      Navigator.pop(context);

                      if (vendorId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                              Text("Vendor ID not found. Please login again.")),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Storefront(vendorId: vendorId!),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.reviews,
                        color: Color(0xFF4682B4)),
                    title: const Text("Get Client Review to You"),
                    onTap: () async {
                      await Share.share(
                        "Hey! Please share your review about my work 😊",
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.support_agent,
                        color: Color(0xFF4682B4)),
                    title: const Text("Contact Support"),
                    onTap: () async {
                      Navigator.pop(context);
                      _contactSupport();
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.star_rate,
                        color: Color(0xFF4682B4)),
                    title: const Text("Rate on Playstore"),
                    onTap: () => _showRateDialog(context),
                  ),
                ],
              ),
            ),
          ),

          const Divider(
            color: Colors.grey,
          ),

          /// Logout
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.logout,  color: Color(0xFF4682B4)),
              title: const Text('Logout'),
              onTap: () async {
                SharedPreferences prefs =
                await SharedPreferences.getInstance();
                await prefs.clear();

                // Navigator.pushNamedAndRemoveUntil(
                //     context, "/login", (route) => false);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Login(), // Login Page
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Stat Item
  static Widget _statItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(title, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  /// Drawer Item
  Widget _drawerItem(
      BuildContext context,
      IconData icon,
      String title,
      Widget page, {
        Color iconColor = Colors.blue,
      }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ).then((_) => _loadUserData());
      },
    );
  }

  /// Rate Sheet
  void _showRateDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const SizedBox(
        height: 200,
        child: Center(child: Text("Rate bottom sheet")),
      ),
    );
  }
}

