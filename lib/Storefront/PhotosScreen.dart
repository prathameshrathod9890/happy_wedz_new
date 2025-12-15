import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_services/api_service_vendor.dart';

class GalleryUploadPage extends StatefulWidget {
  @override
  State<GalleryUploadPage> createState() => _GalleryUploadPageState();
}

class _GalleryUploadPageState extends State<GalleryUploadPage> {
  List<File> selectedImages = [];
  List<String> savedBase64ImagesList = []; // Stored images
  final ImagePicker picker = ImagePicker();
  final VendorServiceApi _vendorApi = VendorServiceApi();


  int? vendorId;
  int? serviceId;
  String? token;
  bool loadingVendorData = true;
  bool uploading = false;


  Map<String, dynamic> currentAttributes = {}; // existing attributes

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId');
    serviceId = prefs.getInt('serviceId');
    token = prefs.getString('token');

    print("📌 Loaded => vendorId: $vendorId, serviceId: $serviceId, token: $token");

    // if (serviceId != null && token != null) {
    //   await fetchCurrentAttributes();
    // }

    if (vendorId != null) {
      savedBase64ImagesList = prefs.getStringList('images_$vendorId') ?? [];
      print("📌 Loaded ${savedBase64ImagesList.length} saved images");
    }

    setState(() => loadingVendorData = false);
  }

  // Future<void> fetchCurrentAttributes() async {
  //   print("📩 Fetching existing vendor-service attributes...");
  //   try {
  //     final response = await http.get(
  //       Uri.parse('https://happywedz.com/api/vendor-services/$serviceId'),
  //       headers: {"Authorization": "Bearer $token"},
  //     );
  //
  //     print("📬 GET Response: ${response.statusCode} | ${response.body}");
  //
  //     if (response.statusCode == 200) {
  //       final parsed = jsonDecode(response.body);
  //       currentAttributes = Map<String, dynamic>.from(parsed["attributes"] ?? {});
  //
  //       // If there are existing images in attributes, merge them
  //       if (currentAttributes.containsKey("media") &&
  //           currentAttributes["media"] is List) {
  //         savedBase64ImagesList = List<String>.from(currentAttributes["media"]);
  //       }
  //
  //       print("✅ Loaded current attributes & images: ${savedBase64ImagesList.length}");
  //     } else {
  //       print("❌ Failed to fetch existing attributes");
  //     }
  //   } catch (e) {
  //     print("❌ Error fetching current attributes: $e");
  //   }
  // }

  Future<void> pickImages() async {
    final List<XFile>? files = await picker.pickMultiImage(imageQuality: 80);

    if (files != null) {
      setState(() {
        selectedImages.addAll(files.map((e) => File(e.path)));
      });
      print("📌 Selected ${selectedImages.length} images");
    }
  }

  void removeImage(int index) {
    setState(() => selectedImages.removeAt(index));
  }


  Future<void> uploadGallery() async {
    if (vendorId == null || token == null || serviceId == null) return;

    if (selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select images")),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      // 🔥 STEP 1: Fetch LATEST attributes from server
      final latest = await _vendorApi.getByServiceId(
        serviceId: serviceId!,
        token: token!,
      );

      Map<String, dynamic> attributes =
      Map<String, dynamic>.from(latest?["attributes"] ?? {});

      // 🔥 STEP 2: Convert images to base64
      List<String> base64Images = [];

      for (var file in selectedImages) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        base64Images.add("data:image/jpeg;base64,$base64Str");
      }

      // 🔥 STEP 3: Merge with existing media
      List<String> existingMedia =
      List<String>.from(attributes["media"] ?? []);

      existingMedia.addAll(base64Images);
      attributes["media"] = existingMedia;

      // 🔥 STEP 4: PUT merged attributes
      final success = await _vendorApi.updateService(
        serviceId: serviceId!,
        token: token!,
        body: {
          "vendor_id": vendorId,
          "attributes": attributes,
        },
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList("images_$vendorId", existingMedia);

        setState(() {
          savedBase64ImagesList = existingMedia;
          selectedImages.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gallery saved successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save gallery")),
        );
      }
    } catch (e) {
      debugPrint("❌ Gallery upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error uploading gallery")),
      );
    }

    setState(() => uploading = false);
  }

  // void deleteSavedImage(int index) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   savedBase64ImagesList.removeAt(index);
  //   currentAttributes["media"] = savedBase64ImagesList;
  //   await prefs.setStringList("images_$vendorId", savedBase64ImagesList);
  //   setState(() {});
  //   print("🗑 Deleted saved image at index: $index");
  // }

  Future<void> deleteSavedImage(int index) async {
    if (vendorId == null || token == null || serviceId == null) return;

    final latest = await _vendorApi.getByServiceId(
      serviceId: serviceId!,
      token: token!,
    );

    Map<String, dynamic> attributes =
    Map<String, dynamic>.from(latest?["attributes"] ?? {});

    List<String> media = List<String>.from(attributes["media"] ?? []);
    media.removeAt(index);
    attributes["media"] = media;

    final success = await _vendorApi.updateService(
      serviceId: serviceId!,
      token: token!,
      body: {
        "vendor_id": vendorId,
        "attributes": attributes,
      },
    );

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList("images_$vendorId", media);

      setState(() => savedBase64ImagesList = media);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF2F2F2),
      appBar: AppBar(
        title: Text("Upload Gallery", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: loadingVendorData
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Upload Images",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),

              ElevatedButton(
                onPressed: pickImages,
                child: Text("Browse Images"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00509D), foregroundColor: Colors.white),
              ),

              SizedBox(height: 20),

              selectedImages.isNotEmpty
                  ? GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: selectedImages.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          selectedImages[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: GestureDetector(
                          onTap: () => removeImage(index),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      )
                    ],
                  );
                },
              )
                  : SizedBox(),

              savedBase64ImagesList.isNotEmpty
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Text("Saved Images",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: savedBase64ImagesList.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10),
                    itemBuilder: (context, index) {
                      final base64Str = savedBase64ImagesList[index].split(',').last;

                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(base64Str),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: GestureDetector(
                              onTap: () => deleteSavedImage(index),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              )
                  : SizedBox(),

              SizedBox(height: 30),

              // ElevatedButton(
              //   onPressed: uploading ? null : uploadGallery,
              //   child: uploading
              //       ? CircularProgressIndicator(color: Colors.white)
              //       : Text("Save Gallery"),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Color(0xFF00509D),
              //     foregroundColor: Colors.white,
              //     padding: EdgeInsets.symmetric(vertical: 14),
              //   ),
              // ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: uploading ? null : uploadGallery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00509D), // Steel Azure
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: uploading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "Save Gallery",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
