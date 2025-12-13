import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({Key? key}) : super(key: key);

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  bool _isLoading = true;
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    fetchReviews();
  }

  // ✅ FETCH REVIEWS
  Future<void> fetchReviews() async {
    print('📡 Fetching reviews from: https://happywedz.com/api/reviews/my-reviews');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('🔑 Token found: $token');

    if (token == null) {
      print('❌ No token found in SharedPreferences');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://happywedz.com/api/reviews/my-reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('🟡 FETCH Status Code: ${response.statusCode}');
      print('📦 FETCH Response Body:\n${response.body}\n');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🧩 Parsed Data: $data');

        if (data['success'] == true && data['reviews'] != null) {
          setState(() {
            _reviews = data['reviews'];
            _isLoading = false;
          });
          print('✅ Reviews fetched successfully! Count: ${_reviews.length}');
        } else {
          print('⚠️ No reviews found or invalid response structure');
          setState(() {
            _isLoading = false;
            _reviews = [];
          });
        }
      } else {
        print('❌ Failed to load reviews, status: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('🔥 Error fetching reviews: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ SEND REPLY
  Future<void> _sendReply(int reviewId, String message) async {
    final url = Uri.parse('https://happywedz.com/api/reviews/reply/$reviewId');
    print('✉️ Sending reply for review ID $reviewId...');
    print('🌍 PUT URL: $url');
    print('📝 Message to send: "$message"');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('🔑 Token found for reply: $token');

    if (token == null) {
      print('❌ No token found in SharedPreferences for reply');
      return;
    }

    try {
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"vendor_reply": message}),
      );

      print('🟢 REPLY Status Code: ${response.statusCode}');
      print('📦 REPLY Response Body:\n${response.body}\n');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('🧩 Parsed REPLY Data: $data');

        setState(() {
          final idx = _reviews.indexWhere((r) => r['id'] == reviewId);
          if (idx != -1) {
            _reviews[idx]['vendor_reply'] = message;
            print('✅ Updated local review list with new reply');
          }
        });

        print('✅ Reply successfully sent and UI updated!');
      } else {
        print('❌ Failed to send reply. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error sending reply: $e');
    }
  }

  // ✅ DIALOG FOR REPLY INPUT
  void _showReplyDialog(int reviewId, String? existingReply) {
    final TextEditingController ctrl = TextEditingController(text: existingReply ?? '');
    print('💬 Opening reply dialog for review ID: $reviewId');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Reply to Review',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00509D),),
        ),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Type your reply...',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('❌ Reply dialog cancelled');
              Navigator.pop(ctx);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00509D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final msg = ctrl.text.trim();
              if (msg.isEmpty) {
                print('⚠️ Reply message is empty');
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              print('📤 Sending reply: $msg');
              await _sendReply(reviewId, msg);
            },
            child: const Text(
              'Send',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),

          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pink))
          : _reviews.isEmpty
          ? const Center(
        child: Text(
          'No reviews available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) {
                final r = _reviews[i];
                print('🧾 Building Review Card for ID: ${r['id']}');
                return _buildReviewCard(r);
              },
              childCount: _reviews.length,
            ),
          ),
        ],
      ),
    );
  }

// ✅ MODERN HEADER
  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).padding.top;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 70,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF003F88), // French Blue
              Color(0xFF00509D), // Steel Azure
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(20, topPad + 10, 16, 10),
        alignment: Alignment.bottomLeft,
        child: const Text(
          'My Reviews',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }


// ✅ MODERN REVIEW CARD
  Widget _buildReviewCard(dynamic r) {
    final user = r['user']?['name'] ?? 'Anonymous';
    final title = r['title'] ?? '';
    final comment = r['comment'] ?? '';
    final vendorReply = r['vendor_reply'] ?? '';
    final mediaList = r['media'] ?? [];
    final date = r['createdAt'] ?? '';
    final rating = r['rating_quality'] ?? 0;

    print('🧱 Review Data -> ID: ${r['id']}, User: $user, Reply: $vendorReply');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 USER HEADER
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF00509D),
                  child: Text(
                    user[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        date.split('T').first,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 🔹 STARS WITH SHADOW
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 22,
                  shadows: [
                    Shadow(
                        color: Colors.amber.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(1, 1))
                  ],
                );
              }),
            ),

            const SizedBox(height: 8),

            // 🔹 TITLE & COMMENT
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            if (comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  comment,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.4),
                ),
              ),

            const SizedBox(height: 12),

            // 🔹 VENDOR REPLY CHAT BUBBLE
            // 🔹 VENDOR REPLY CHAT BUBBLE
            // 🔹 VENDOR REPLY CHAT BUBBLE
            if (vendorReply.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100, // faint sky blue
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade200), // subtle border
                ),
                child: Text(
                  vendorReply,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white, // text stays white
                    height: 1.4,
                  ),
                ),
              ),



            const SizedBox(height: 10),

            // 🔹 ACTION BUTTON
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showReplyDialog(r['id'], r['vendor_reply']?.toString()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00509D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                icon: const Icon(Icons.reply),
                label: Text(vendorReply.isEmpty ? 'Reply' : 'Edit Reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }



}
