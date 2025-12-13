import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GalleryUploadPage extends StatefulWidget {
  @override
  State<GalleryUploadPage> createState() => _GalleryUploadPageState();
}

class _GalleryUploadPageState extends State<GalleryUploadPage> {
  List<File> selectedImages = [];
  List<String> savedBase64ImagesList = []; // Stored images
  final ImagePicker picker = ImagePicker();

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

    if (serviceId != null && token != null) {
      await fetchCurrentAttributes();
    }

    if (vendorId != null) {
      savedBase64ImagesList = prefs.getStringList('images_$vendorId') ?? [];
      print("📌 Loaded ${savedBase64ImagesList.length} saved images");
    }

    setState(() => loadingVendorData = false);
  }

  Future<void> fetchCurrentAttributes() async {
    print("📩 Fetching existing vendor-service attributes...");
    try {
      final response = await http.get(
        Uri.parse('https://happywedz.com/api/vendor-services/$serviceId'),
        headers: {"Authorization": "Bearer $token"},
      );

      print("📬 GET Response: ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        currentAttributes = Map<String, dynamic>.from(parsed["attributes"] ?? {});

        // If there are existing images in attributes, merge them
        if (currentAttributes.containsKey("media") &&
            currentAttributes["media"] is List) {
          savedBase64ImagesList = List<String>.from(currentAttributes["media"]);
        }

        print("✅ Loaded current attributes & images: ${savedBase64ImagesList.length}");
      } else {
        print("❌ Failed to fetch existing attributes");
      }
    } catch (e) {
      print("❌ Error fetching current attributes: $e");
    }
  }

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
        SnackBar(content: Text("Please select images")),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      List<String> base64Images = [];

      for (var file in selectedImages) {
        List<int> bytes = await file.readAsBytes();
        String base64Str = base64Encode(bytes);
        base64Images.add("data:image/jpeg;base64,$base64Str");
      }

      // Merge new images with existing ones
      savedBase64ImagesList.addAll(base64Images);
      currentAttributes["media"] = savedBase64ImagesList;

      var body = jsonEncode({
        "vendor_id": vendorId,
        "attributes": currentAttributes,
      });

      var response = await http.put(
        Uri.parse("https://happywedz.com/api/vendor-services/$serviceId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: body,
      );

      print("📥 Response: ${response.statusCode} => ${response.body}");

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList("images_$vendorId", savedBase64ImagesList);

        selectedImages.clear();

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gallery saved")));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Upload failed")));
      }
    } catch (e) {
      print("❌ Upload error: $e");
    } finally {
      setState(() => uploading = false);
    }
  }

  void deleteSavedImage(int index) async {
    final prefs = await SharedPreferences.getInstance();
    savedBase64ImagesList.removeAt(index);
    currentAttributes["media"] = savedBase64ImagesList;
    await prefs.setStringList("images_$vendorId", savedBase64ImagesList);
    setState(() {});
    print("🗑 Deleted saved image at index: $index");
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

              ElevatedButton(
                onPressed: uploading ? null : uploadGallery,
                child: uploading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Save Gallery"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00509D),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
