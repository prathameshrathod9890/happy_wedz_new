import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideosPage extends StatefulWidget {
  @override
  _VideosPageState createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  List<String> _videoUrls = [];

  @override
  void initState() {
    super.initState();
    _loadSavedUrls();
  }

  Future<void> _loadSavedUrls() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? urls = prefs.getStringList('video_urls');
    if (urls != null) {
      setState(() {
        _videoUrls = urls;
      });
    }
  }

  Future<void> _saveUrls() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('video_urls', _videoUrls);
  }

  void _deleteVideo(int index) async {
    setState(() {
      _videoUrls.removeAt(index);
    });
    await _saveUrls();
  }

  void _deleteAllVideos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete All Videos"),
        content: const Text("Are you sure you want to delete all videos?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _videoUrls.clear();
              });
              await _saveUrls();
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAddVideos() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddVideosScreen()),
    );

    if (result != null && result is List<String>) {
      setState(() {
        _videoUrls.addAll(result);
      });
      await _saveUrls();
    }
  }

  /// ✅ YouTube detection
  bool _isYouTubeUrl(String url) {
    return url.contains("youtube.com") || url.contains("youtu.be");
  }

  /// ✅ Instagram detection
  bool _isInstagramUrl(String url) {
    return url.contains("instagram.com/reel");
  }

  /// ✅ Get YouTube thumbnail
  String _getYoutubeThumbnail(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    return "https://img.youtube.com/vi/$videoId/0.jpg";
  }

  void _openVideo(String url) async {
    if (_isYouTubeUrl(url)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => YouTubePlayerScreen(videoUrl: url),
        ),
      );
    } else if (_isInstagramUrl(url)) {
      _launchInstagram(url);
    } else {
      _launchExternal(url);
    }
  }

  void _launchInstagram(String url) async {
    try {
      Uri uri = Uri.parse(url);
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Instagram URL")),
      );
    }
  }

  void _launchExternal(String url) async {
    try {
      Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot launch URL")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid URL")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalTiles = _videoUrls.length + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Videos"),
        backgroundColor: const Color(0xFFE0F7FA),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _deleteAllVideos();
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text("Delete All Videos"),
              ),
            ],
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: totalTiles,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _navigateToAddVideos,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 40, color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        "Add Videos",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            final vidIndex = index - 1;
            final videoUrl = _videoUrls[vidIndex];

            return GestureDetector(
              onTap: () => _openVideo(videoUrl),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _isYouTubeUrl(videoUrl)
                        ? Image.network(
                      _getYoutubeThumbnail(videoUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                        : Container(
                      color: Colors.black12,
                      child: const Center(
                        child: Icon(
                          Icons.ondemand_video,
                          size: 60,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.red.withOpacity(0.8),
                      child: IconButton(
                        icon: const Icon(Icons.delete,
                            size: 16, color: Colors.white),
                        onPressed: () => _deleteVideo(vidIndex),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

// -----------------------------
// YouTube Player Screen
// -----------------------------
class YouTubePlayerScreen extends StatefulWidget {
  final String videoUrl;

  YouTubePlayerScreen({required this.videoUrl});

  @override
  _YouTubePlayerScreenState createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    _controller = YoutubePlayerController(
      initialVideoId: videoId ?? '',
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Player'),
        backgroundColor: Colors.deepPurple,
      ),
      body: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// -----------------------------
// Add Videos Screen
// -----------------------------
class AddVideosScreen extends StatefulWidget {
  @override
  _AddVideosScreenState createState() => _AddVideosScreenState();
}

class _AddVideosScreenState extends State<AddVideosScreen> {
  List<TextEditingController> _controllers = [TextEditingController()];

  void _addAnotherVideo() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _controllers.removeAt(index);
    });
  }

  void _uploadVideos() {
    List<String> urls = _controllers
        .map((controller) => controller.text.trim())
        .where((url) => url.isNotEmpty)
        .toList();

    Navigator.pop(context, urls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Videos"),
        backgroundColor: Colors.pink[100],
      ),
      body: Column(
        children: [
          ..._controllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;

            return Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                          hintText: "Paste your URL here"),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeVideo(index),
                  ),
                ],
              ),
            );
          }).toList(),
          TextButton(
            onPressed: _addAnotherVideo,
            child: const Text(
              "+ Add another video",
              style: TextStyle(color: const Color(0xFF00BCD4)),

            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: _uploadVideos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE0F7FA),

                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "UPLOAD VIDEO",
                style: TextStyle(color: Colors.white),


              ),
            ),
          ),
        ],
      ),
    );
  }
}
