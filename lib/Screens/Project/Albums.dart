import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../FAQs/ProfileScreen.dart';

class AlbumsPage extends StatefulWidget {
  @override
  _AlbumsPageState createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  final List<Map<String, dynamic>> _albums = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final albumsJson = prefs.getString('albums_data');
    if (albumsJson != null) {
      final List<dynamic> albumsList = jsonDecode(albumsJson);
      setState(() {
        _albums.clear();
        _albums.addAll(albumsList.map((e) => Map<String, dynamic>.from(e)));
      });
    }
  }

  Future<void> _saveAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('albums_data', jsonEncode(_albums));
  }

  Future<void> _addNewAlbum() async {
    // Navigate to form first
    final formData = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateAlbumFormPage()),
    );

    if (formData != null && formData is Map<String, dynamic>) {
      final List<XFile>? selectedImages = await _picker.pickMultiImage();

      if (selectedImages != null && selectedImages.isNotEmpty) {
        setState(() {
          _albums.add({
            "title": formData['title'] ?? "New Album",
            "description": formData['description'] ?? "",
            "location": formData['location'] ?? "",
            "banquet": formData['banquet'] ?? "None",
            "count": selectedImages.length,
            "cover": selectedImages.first.path,
            "local": true,
            "images": selectedImages.map((xfile) => xfile.path).toList(),
          });
        });
        await _saveAlbums();
      }
    }
  }

  // Add ability to add more photos to existing album
  Future<void> _addMorePhotos(int index) async {
    final List<XFile>? selectedImages = await _picker.pickMultiImage();

    if (selectedImages != null && selectedImages.isNotEmpty) {
      setState(() {
        final album = _albums[index];
        final images = List<String>.from(album['images'] ?? []);
        images.addAll(selectedImages.map((xfile) => xfile.path));
        album['images'] = images;
        album['count'] = images.length;
        // Optionally update cover photo if none
        if (album['cover'] == null || album['cover'].toString().isEmpty) {
          album['cover'] = images.first;
        }
      });


      await _saveAlbums();


      await ProfileCompletionController.markDone(ProfileCompletionController.keyAlbum);

    }
  }

  // Optional: Implement refresh action (reload from prefs)
  void _refreshAlbums() {
    _loadAlbums();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Albums refreshed')),
    );
  }

  // Delete all albums
  Future<void> _deleteAllAlbums() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All Albums'),
        content: const Text('Are you sure you want to delete all albums?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _albums.clear();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('albums_data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Albums"),
        backgroundColor: const Color(0xFFE0F7FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt),
            onPressed: _refreshAlbums,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteAllAlbums,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // --- Add New Album Card ---
                GestureDetector(
                  onTap: _addNewAlbum,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: const DecorationImage(
                        image: NetworkImage(
                          "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80",
                        ),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black54,
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 36),
                          SizedBox(height: 4),
                          Text(
                            "Add New Album",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- Album List ---
                ..._albums.asMap().entries.map((entry) {
                  final index = entry.key;
                  final album = entry.value;
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumImagesPage(
                            title: album["title"],
                            images: List<String>.from(album["images"] ?? []),
                            local: album["local"] ?? true,
                            onAlbumUpdated: (updatedImages) async {
                              setState(() {
                                album["images"] = updatedImages;
                                album["count"] = updatedImages.length;
                                if (updatedImages.isNotEmpty) {
                                  album["cover"] = updatedImages.first;
                                } else {
                                  album["cover"] = null;
                                }
                              });
                              await _saveAlbums();
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: (album["cover"] != null && album["cover"].toString().isNotEmpty)
                              ? (album["local"] == true
                              ? FileImage(File(album["cover"]))
                              : NetworkImage(album["cover"])) as ImageProvider
                              : const AssetImage('assets/images/placeholder.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(album["title"],
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  Text("${album["count"]} Images",
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: CircleAvatar(
                                backgroundColor: const Color(0xFF00BCD4),
                                child: IconButton(
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  onPressed: () => _addMorePhotos(index),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Bottom button
          Container(
            width: double.infinity,
            color: const Color(0xFFE0F7FA),


            padding: const EdgeInsets.all(14),
            child: const Center(
              child: Text(
                "View Album Upload Guidelines",
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class CreateAlbumFormPage extends StatefulWidget {
  const CreateAlbumFormPage({Key? key}) : super(key: key);

  @override
  State<CreateAlbumFormPage> createState() => _CreateAlbumFormPageState();
}

class _CreateAlbumFormPageState extends State<CreateAlbumFormPage> {
  final _formKey = GlobalKey<FormState>();

  String _title = '';
  String _description = '';
  String _location = '';
  String _selectedBanquet = 'None';

  final List<String> _banquetOptions = ['None', 'Category 1', 'Category 2', 'Category 3'];

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Send data back to previous page
      Navigator.pop(context, {
        'title': _title,
        'description': _description,
        'location': _location,
        'banquet': _selectedBanquet,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Album"),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Enter title' : null,
                onSaved: (value) => _title = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => value!.isEmpty ? 'Enter description' : null,
                onSaved: (value) => _description = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) => value!.isEmpty ? 'Enter location' : null,
                onSaved: (value) => _location = value!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Banquet'),
                value: _selectedBanquet,
                items: _banquetOptions.map((String banquet) {
                  return DropdownMenuItem<String>(
                    value: banquet,
                    child: Text(banquet),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBanquet = value!;
                  });
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "CREATE ALBUM",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumImagesPage extends StatefulWidget {
  final String title;
  final List<String> images;
  final bool local;
  final Function(List<String>)? onAlbumUpdated;

  const AlbumImagesPage({
    Key? key,
    required this.title,
    required this.images,
    required this.local,
    this.onAlbumUpdated,
  }) : super(key: key);

  @override
  State<AlbumImagesPage> createState() => _AlbumImagesPageState();
}

class _AlbumImagesPageState extends State<AlbumImagesPage> {
  late List<String> _images;
  late List<int> _likes;

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.images);
    _likes = List<int>.filled(_images.length, 0);
  }

  void _onLikeImage(int index) {
    setState(() {
      _likes[index]++;
    });
  }

  void _onImageDeleted(int index) {
    setState(() {
      _images.removeAt(index);
      _likes.removeAt(index);
    });

    // Update album in parent widget
    if (widget.onAlbumUpdated != null) {
      widget.onAlbumUpdated!(_images);
    }
  }

  Future<void> _onMakeCoverPhoto(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coverImage', _images[index]);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("This photo is now your cover image.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          itemCount: _images.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImagePreviewPage(
                      image: XFile(_images[index]),
                      likes: _likes[index],
                      onLike: () {
                        _onLikeImage(index);
                      },
                      onDelete: () {
                        _onImageDeleted(index);
                      },
                      onMakeCover: () => _onMakeCoverPhoto(index),
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: widget.local
                    ? Image.file(
                  File(_images[index]),
                  fit: BoxFit.cover,
                )
                    : Image.network(
                  _images[index],
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


class ImagePreviewPage extends StatelessWidget {
  final XFile image;
  final int likes;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback? onMakeCover;

  const ImagePreviewPage({
    Key? key,
    required this.image,
    required this.likes,
    required this.onLike,
    required this.onDelete,
    this.onMakeCover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Image.file(
                  File(image.path),
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // ❤️ Like Button
                GestureDetector(
                  onTap: () {
                    onLike();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Photo liked')),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.pinkAccent),
                      const SizedBox(width: 4),
                      Text(
                        likes.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // 🔄 Share Button
                GestureDetector(
                  onTap: () async {
                    await Share.shareXFiles(
                      [image],
                      text: "Check out this photo!",
                    );
                  },
                  child: const Icon(Icons.share, color: Colors.white),
                ),

                // 🗑 Delete Button with confirmation
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Photo'),
                        content: const Text('Are you sure you want to delete this photo?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      onDelete(); // remove from album
                      Navigator.of(context).pop(); // close preview
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Photo deleted')),
                      );
                    }
                  },
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const Divider(color: Colors.white, thickness: 1),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 🌄 Make Cover Photo
                  GestureDetector(
                    onTap: () {
                      if (onMakeCover != null) {
                        onMakeCover!();
                      }
                    },

                    child: Column(
                      children: const [
                        Icon(Icons.photo, color: Colors.white),
                        SizedBox(height: 4),
                        Text(
                          "Make Cover Photo",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // ✏️ Edit placeholder (future use)
                  Column(
                    children: const [
                      Icon(Icons.edit, color: Colors.white),
                      SizedBox(height: 4),
                      Text("Edit Photo",
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

