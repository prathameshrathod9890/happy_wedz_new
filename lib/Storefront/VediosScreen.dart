import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:http/http.dart' as http;

class VideoUploadPage extends StatefulWidget {
  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  List<String> videoURLs = [];
  Map<String, String?> thumbnails = {}; // URL -> thumbnail path
  int? vendorId;
  int? serviceId;
  String? token;

  final TextEditingController urlController = TextEditingController();
  bool loadingVendorData = true;
  bool saving = false;

  VideoPlayerController? activeController;
  String? activeVideoUrl;

  Map<String, dynamic> currentAttributes = {};

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt("vendorId");
    serviceId = prefs.getInt("serviceId");
    token = prefs.getString("token");

    if (serviceId != null && token != null) {
      await fetchCurrentAttributes();
    }

    if (vendorId != null) {
      videoURLs = prefs.getStringList("videos_$vendorId") ?? [];
      for (var url in videoURLs) {
        thumbnails[url] = await getThumbnail(url);
      }
    }

    setState(() => loadingVendorData = false);
  }

  Future<void> fetchCurrentAttributes() async {
    try {
      final response = await http.get(
        Uri.parse('https://happywedz.com/api/vendor-services/$serviceId'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        currentAttributes = Map<String, dynamic>.from(parsed["attributes"] ?? {});
        if (currentAttributes.containsKey("video") &&
            currentAttributes["video"] is List) {
          videoURLs = List<String>.from(currentAttributes["video"]);
        }
      }
    } catch (e) {
      print("Error fetching video attributes: $e");
    }
  }

  Future<String?> getThumbnail(String url) async {
    if (url.contains("youtube") || url.contains("youtu.be")) {
      final id = extractYouTubeId(url);
      if (id != null) return 'https://img.youtube.com/vi/$id/0.jpg';
    } else if (url.endsWith(".mp4")) {
      try {
        final thumb = await VideoThumbnail.thumbnailFile(
          video: url,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 200,
          quality: 75,
        );
        return thumb;
      } catch (e) {
        print("Thumbnail error: $e");
      }
    }
    return null;
  }

  void addVideoURL() async {
    final url = urlController.text.trim();
    if (url.isEmpty) return;
    urlController.clear();

    setState(() {
      videoURLs.add(url);
      thumbnails[url] = null;
    });

    final thumb = await getThumbnail(url);
    setState(() {
      thumbnails[url] = thumb;
    });
  }

  void removeVideo(int index) async {
    final url = videoURLs[index];

    if (activeVideoUrl == url) {
      activeController?.pause();
      activeController?.dispose();
      activeController = null;
      activeVideoUrl = null;
    }

    setState(() {
      videoURLs.removeAt(index);
      thumbnails.remove(url);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("videos_$vendorId", videoURLs);
  }

  Future<void> saveVideoGallery() async {
    if (vendorId == null || serviceId == null || token == null) return;

    setState(() => saving = true);

    currentAttributes["video"] = videoURLs;

    final payload = {
      "vendor_id": vendorId,
      "attributes": currentAttributes,
    };

    try {
      final response = await http.put(
        Uri.parse("https://happywedz.com/api/vendor-services/$serviceId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList("videos_$vendorId", videoURLs);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Videos Saved Successfully")));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to Save")));
      }
    } catch (e) {
      print("Error saving videos: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving videos")));
    }

    setState(() => saving = false);
  }

  void playVideo(String url) async {
    if (activeVideoUrl == url) {
      if (activeController!.value.isPlaying) {
        activeController!.pause();
      } else {
        activeController!.play();
      }
      setState(() {});
      return;
    }

    activeController?.pause();
    activeController?.dispose();

    activeController = VideoPlayerController.network(url);
    await activeController!.initialize();
    activeController!.play();

    activeVideoUrl = url;
    setState(() {});
  }

  String? extractYouTubeId(String url) {
    final RegExp exp = RegExp(r"(?:v=|youtu\.be/|embed/)([^&?]+)");
    final match = exp.firstMatch(url);
    return match != null ? match.group(1) : null;
  }

  Widget buildVideoGrid() {
    return videoURLs.isEmpty
        ? Text("No Videos Added Yet")
        : GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: videoURLs.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1),
      itemBuilder: (context, index) {
        final url = videoURLs[index];
        bool isActive = activeVideoUrl == url;
        final thumb = thumbnails[url];
        return GestureDetector(
          onTap: () => playVideo(url),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black12,
                  child: isActive &&
                      activeController != null &&
                      activeController!.value.isInitialized
                      ? AspectRatio(
                    aspectRatio: activeController!.value.aspectRatio,
                    child: VideoPlayer(activeController!),
                  )
                      :
                  // thumb != null
                  //     ? (url.contains("youtube")
                  //     ? Image.network(
                  //   thumb,
                  //   fit: BoxFit.cover,
                  // )
                  //     : Image.file(
                  //   File(thumb),
                  //   fit: BoxFit.cover,
                  // ))
                  //     : Center(
                  //   child: Icon(Icons.play_arrow,
                  //       size: 40, color: Colors.white),
                  // ),
                  thumb != null
                      ? (thumb.startsWith("http")
                      ? Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.play_circle,
                      size: 40,
                      color: Colors.white,
                    ),
                  )
                      : Image.file(
                    File(thumb),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.play_circle,
                      size: 40,
                      color: Colors.white,
                    ),
                  ))
                      : const Center(
                    child: Icon(Icons.play_arrow, size: 40, color: Colors.white),
                  ),

                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => removeVideo(index),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
              if (isActive)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: IconButton(
                    icon: Icon(
                      activeController!.value.isPlaying
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      size: 30,
                      color: Colors.white,
                    ),
                    onPressed: () => playVideo(url),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    urlController.dispose();
    activeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF2F2F2),
      appBar: AppBar(
        title: Text("Video Gallery", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: loadingVendorData
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: "Enter Video URL...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                // ElevatedButton(
                //   onPressed: addVideoURL,
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Color(0xFF00509D),
                //   ),
                //   child: Text("Add"),
                // )
                ElevatedButton(
                  onPressed: addVideoURL,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00509D),
                    foregroundColor: Colors.white, // 👈 text + icon color
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "+   Add",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              ],
            ),
            SizedBox(height: 20),
            buildVideoGrid(),
            SizedBox(height: 30),

            // ElevatedButton(
            //     onPressed: saving ? null : saveVideoGallery,
            //
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: const Color(0xFF00509D), // Steel Azure
            //     elevation: 2,
            //     padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(30),
            //     ),
            //   ),
            //   child: const Text(
            //     "Save Gallery",
            //     style: TextStyle(
            //       color: Colors.white, // White text
            //       fontSize: 16,
            //       fontWeight: FontWeight.w500,
            //     ),
            //   ),
            // )

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : saveVideoGallery,
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
                child: saving
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
    );
  }
}
