import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilescreenWithNext extends StatefulWidget {
  final VoidCallback? onNext;

  const ProfilescreenWithNext({super.key, this.onNext});

  @override
  State<ProfilescreenWithNext> createState() => _ProfilescreenWithNextState();
}

class _ProfilescreenWithNextState extends State<ProfilescreenWithNext> {
  double _progress = 0.0;

  List<TextEditingController> _contactControllers = [TextEditingController()];
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();

  final List<Map<String, String>> countries = [
    {'code': '+91', 'emoji': '🇮🇳', 'name': 'India'},
    {'code': '+1', 'emoji': '🇺🇸', 'name': 'USA'},
    {'code': '+44', 'emoji': '🇬🇧', 'name': 'UK'},
    {'code': '+81', 'emoji': '🇯🇵', 'name': 'Japan'},
  ];

  int selectedCountryIndex = 0;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProgress();

    _contactControllers.first.addListener(() {
      setState(() {
        if (_contactControllers.first.text.isNotEmpty &&
            _contactControllers.first.text.length < 8) {
          errorMessage = 'Please enter a valid number';
        } else {
          errorMessage = null;
        }
      });
    });
  }

  Future<void> _loadProgress() async {
    double progress = await ProfileCompletionController.getCompletion();
    setState(() {
      _progress = progress;
    });
  }

  @override
  void dispose() {
    for (var c in _contactControllers) {
      c.dispose();
    }
    _whatsappController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _youtubeController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Widget _buildPhoneNumberRow(TextEditingController controller,
      {bool showDeleteButton = false}) {
    return Row(
      children: [
        Flexible(
          flex: 3,
          child: DropdownButtonFormField<int>(
            value: selectedCountryIndex,
            decoration: InputDecoration(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: List.generate(countries.length, (index) {
              final country = countries[index];
              return DropdownMenuItem<int>(
                value: index,
                child: Text("${country['emoji']} ${country['code']}"),
              );
            }),
            onChanged: (value) {
              setState(() => selectedCountryIndex = value!);
            },
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 5,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: "Enter number",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
        if (showDeleteButton) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _contactControllers.remove(controller));
            },
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(String title, TextEditingController controller,
      {String? hint, double height = 60}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE0F7FA),
        elevation: 1,
        centerTitle: true,
        title: const Text(
          "Complete Your Profile",
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          ProfileCompletionBar(progress: _progress),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Contact Numbers",
                        style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: () {
                        setState(() =>
                            _contactControllers.add(TextEditingController()));
                      },
                      label: const Text("Add More",
                          style:
                          TextStyle(fontSize: 14, color: Colors.black87)),
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.black87, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children: _contactControllers.map((controller) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildPhoneNumberRow(controller,
                          showDeleteButton: _contactControllers.length > 1),
                    );
                  }).toList(),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                const Text(
                  "WhatsApp Number",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 8),
                _buildPhoneNumberRow(_whatsappController),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                _buildTextField("Instagram Profile", _instagramController,
                    hint: "Enter Instagram URL"),
                const Text(
                  "Latest posts on this profile will be displayed to customers.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildTextField("Website", _websiteController,
                    hint: "Enter your website URL"),
                _buildTextField("Facebook Page", _facebookController,
                    hint: "Enter Facebook URL"),
                _buildTextField("Vimeo/YouTube Channel", _youtubeController,
                    hint: "Enter video channel link"),
                const SizedBox(height: 12),
                const Text(
                  "Brand Description",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _brandController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        hintText: "Write something about your brand...",
                        border: InputBorder.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Colors.white,
        child: Row(
          children: [
            TextButton(
              onPressed: () {},
              child: const Text(
                "Skip",
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
            const Spacer(),
            ElevatedButton(

              onPressed: () => widget.onNext?.call(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding:
                const EdgeInsets.symmetric(horizontal: 48, vertical: 14),

              ),

              child: const Text(
                "Next",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileCompletionBar extends StatelessWidget {
  final double progress;

  const ProfileCompletionBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "${(progress * 100).toInt()}%",
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class ProfileCompletionController {
  static const String keyFaq = 'completed_faq';
  static const String keyLinks = 'completed_links';
  static const String keyPortfolio = 'completed_portfolio';
  static const String keyAlbum = 'completed_album';
  static const String keyReview = 'completed_review';

  static Future<double> getCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    int completed = 0;

    if (prefs.getBool(keyFaq) ?? false) completed++;
    if (prefs.getBool(keyLinks) ?? false) completed++;
    if (prefs.getBool(keyPortfolio) ?? false) completed++;
    if (prefs.getBool(keyAlbum) ?? false) completed++;
    if (prefs.getBool(keyReview) ?? false) completed++;

    return completed / 5;
  }

  static Future<void> markDone(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
