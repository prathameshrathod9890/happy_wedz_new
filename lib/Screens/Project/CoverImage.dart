import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Albums.dart';

class CoverPicPage extends StatefulWidget {
  @override
  _CoverPicPageState createState() => _CoverPicPageState();
}

class _CoverPicPageState extends State<CoverPicPage> {
  List<String> coverImages = [];

  @override
  void initState() {
    super.initState();
    _loadCoverImages();
  }

  Future<void> _loadCoverImages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      coverImages = prefs.getStringList('cover_image_portfolio') ?? [];
    });
  }

  Future<void> _deleteImage(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      coverImages.removeAt(index);
    });
    await prefs.setStringList('cover_image_portfolio', coverImages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cover Images"),
        backgroundColor: const Color(0xFFE0F7FA),
      ),
      body: coverImages.isEmpty
          ? const Center(
        child: Text(
          "No cover images yet",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 images per row
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: coverImages.length,
        itemBuilder: (context, index) {
          final imgPath = coverImages[index];
          int likes = 0; // default likes count (you can store it later)

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImagePreviewPage(
                    image: XFile(imgPath),
                    likes: likes,
                    onLike: () {
                      // Example: increment like count
                      likes++;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Liked! ($likes)")),
                      );
                    },
                    onDelete: () async {
                      await _deleteImage(index);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Image deleted")),
                      );
                    },
                  ),
                ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(imgPath), fit: BoxFit.cover),
              ],
            ),
          );
        },

      ),
    );
  }
}
