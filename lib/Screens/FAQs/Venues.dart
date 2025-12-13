import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ProfileScreen.dart';

// ===== MODEL =====
class FaqQuestion {
  final int id;
  final String text;
  final String description;
  final List<String> label;
  final String type;
  final List<String> options;
  final int? min;
  final int? max;

  FaqQuestion({
    required this.id,
    required this.text,
    required this.description,
    required this.label,
    required this.type,
    required this.options,
    this.min,
    this.max,
  });

  factory FaqQuestion.fromJson(Map<String, dynamic> json) {
    return FaqQuestion(
      id: json['id'],
      text: json['text'] ?? '',
      description: json['description'] ?? '',
      label: List<String>.from(json['label'] ?? []),
      type: json['type'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      min: json['min'],
      max: json['max'],
    );
  }
}

// ===== VENUE FAQ SCREEN =====
class VenueFaqScreen extends StatefulWidget {
  const VenueFaqScreen({super.key});

  @override
  State<VenueFaqScreen> createState() => _VenueFaqScreenState();
}

class _VenueFaqScreenState extends State<VenueFaqScreen> {
  List<FaqQuestion> faqs = [];

  int vendorId = 0;
  int vendorTypeId = 2; // venue vendor type id
  String token = "";
  bool isLoading = false;

  final Map<int, TextEditingController> textControllers = {};



  final Map<int, String> selectedRadio = {};
  final Map<int, List<String>> selectedCheckbox = {};
  final Map<int, double> selectedSlider = {};

  @override
  void initState() {
    super.initState();
    _initFaqScreen();
  }

  Future<void> _initFaqScreen() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId') ?? 0;
    vendorTypeId = prefs.getInt('vendorTypeId') ?? (mockVenueJson['vendor_type_id'] ?? 2) as int;
    token = prefs.getString('authToken') ?? "";

    final data = mockVenueJson['questions'] as List<dynamic>;
    faqs = data.map((e) => FaqQuestion.fromJson(e)).toList();

    // Prepare controllers for text/number/textarea
    for (var q in faqs) {
      if (q.type == 'text' || q.type == 'textarea' || q.type == 'number') {
        textControllers[q.id] = TextEditingController();
      }
    }

    // Fetch saved answers from backend if logged in
    if (vendorId != 0 && token.isNotEmpty) {
      await _fetchFaqAnswers();
    } else {
      setState(() {});
    }
  }

  Future<void> _fetchFaqAnswers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("https://happywedz.com/api/faq-answers/$vendorId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200)
      {
        print("🔹 FETCH FAQ RESPONSE: ${response.body}");
        final data = jsonDecode(response.body);

        List<dynamic> answers = [];
        if (data is Map<String, dynamic>) {
          answers = (data['answers'] ?? []) as List<dynamic>;
        } else if (data is List) {
          answers = data;
        }


        for (var ans in answers) {
          if (ans == null) continue;
          final qid = ans['faqQuestionId'];
          final answer = ans['answer'];

          final question = faqs.firstWhere(
                (q) => q.id == qid,
            orElse: () => FaqQuestion(
              id: 0,
              text: '',
              description: '',
              label: [],
              type: '',
              options: [],
            ),
          );
          if (question.id == 0) continue;

          if (question.type == 'checkbox') {
            try {
              selectedCheckbox[qid] = List<String>.from(answer);
            } catch (_) {
              selectedCheckbox[qid] = [];
            }
          } else if (question.type == 'radio') {
            selectedRadio[qid] = answer.toString();
          } else if (question.type == 'range') {
            selectedSlider[qid] = (answer is num) ? answer.toDouble() : 0.0;
          } else {
            textControllers[qid]?.text = answer.toString();
          }
        }
      } else {
        print("❌ Failed to fetch FAQ answers: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("⚠️ Error loading FAQ answers: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }
  Future<void> _saveFaqAnswers() async {
    setState(() => isLoading = true);

    // Only include answered questions
    final answers = faqs.map((q) {
      dynamic ans;
      if (q.type == 'checkbox') {
        ans = selectedCheckbox[q.id];
      } else if (q.type == 'radio') {
        ans = selectedRadio[q.id];
      } else if (q.type == 'range') {
        ans = selectedSlider[q.id];
      } else {
        ans = textControllers[q.id]?.text.trim();
      }

      // Skip unanswered questions
      if (ans == null || (ans is String && ans.isEmpty) || (ans is List && ans.isEmpty)) {
        return null;
      }

      return {"faqQuestionId": q.id, "answer": ans};
    }).where((element) => element != null).toList();

    if (vendorId == 0 || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingFaqAnswers', jsonEncode(answers));
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You are not logged in yet. Answers saved locally.")),
      );
      return;
    }

    final body = {
      "vendorId": vendorId,
      "vendorTypeId": vendorTypeId,
      "answers": answers,
    };

    try {
      final response = await http.post(
        Uri.parse("https://happywedz.com/api/faq-answers/save"),
        headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
        body: jsonEncode(body),
      );


      print("📤 Sent: ${jsonEncode(body)}");
      print("📩 Response (${response.statusCode}): ${response.body}");
      print("🪪 vendorId: $vendorId");
      print("🔐 token: $token");
      print("🎨 vendorTypeId: $vendorTypeId");
      print("➡️ Sending: ${jsonEncode(body)}");


      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ FAQ answers saved successfully")),
        );
        await _fetchFaqAnswers();
      } else {
        String msg = "Failed to save FAQ answers";
        try {
          final parsed = jsonDecode(response.body);
          if (parsed['message'] != null) msg = parsed['message'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error while saving answers")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Venues FAQs",
          style: TextStyle(color: Colors.black), // optional for better contrast
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFE0F7FA), // 🌸 light WedMeGood blue
        elevation: 0, // optional: gives a clean flat look
        iconTheme: const IconThemeData(color: Colors.black), // optional for visibility
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: faqs.length,
        itemBuilder: (context, index) => _buildFaqCard(faqs[index]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00BCD4),
        icon: const Icon(Icons.send),
        label: const Text("Submit"),
        onPressed: () async {
          await _saveFaqAnswers();

          // Mark FAQ as completed
          await ProfileCompletionController.markDone(ProfileCompletionController.keyFaq);

          if (!mounted) return;

          // ✅ Go directly to Home (pop everything till the first route)
          Navigator.popUntil(context, (route) => route.isFirst);
        },
      ),

    );
  }

  Widget _buildFaqCard(FaqQuestion q) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q.text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            _buildInput(q),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(FaqQuestion q) {
    switch (q.type) {
      case "number":
        return Column(
          children: q.label.isNotEmpty
              ? q.label.map((lbl) {
            final controller = textControllers[q.id]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: lbl,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            );
          }).toList()
              : [
            TextFormField(
              controller: textControllers[q.id],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Enter answer",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            )
          ],
        );

      case "text":
      case "textarea":
        return TextFormField(
          controller: textControllers[q.id],
          minLines: q.type == "textarea" ? 3 : 1,
          maxLines: q.type == "textarea" ? 5 : 1,
          decoration: InputDecoration(
            labelText: q.label.isNotEmpty ? q.label.first : "Enter answer",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        );

      case "radio":
        return _buildExpandableOptions(
          options: q.options,
          builder: (opt) => RadioListTile(
            title: Text(opt),
            value: opt,
            groupValue: selectedRadio[q.id],
            onChanged: (val) => setState(() => selectedRadio[q.id] = val.toString()),
          ),
        );

      case "checkbox":
        return _buildExpandableOptions(
          options: q.options,
          builder: (opt) {
            bool isChecked = selectedCheckbox[q.id]?.contains(opt) ?? false;
            return CheckboxListTile(
              title: Text(opt),
              value: isChecked,
              onChanged: (val) {
                setState(() {
                  selectedCheckbox[q.id] ??= [];
                  if (val == true) {
                    selectedCheckbox[q.id]!.add(opt);
                  } else {
                    selectedCheckbox[q.id]!.remove(opt);
                  }
                });
              },
            );
          },
        );

      default:
        return const SizedBox();
    }
  }


  Widget _buildExpandableOptions({
    required List<String> options,
    required Widget Function(String) builder,
  }) {
    int visibleCount = 2;
    bool expanded = false;

    return StatefulBuilder(
      builder: (context, setInnerState) {
        final visibleOptions =
        expanded ? options : options.take(visibleCount).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...visibleOptions.map(builder).toList(),
            if (!expanded && options.length > visibleCount)
              TextButton.icon(
                onPressed: () => setInnerState(() => expanded = true),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                label: const Text(
                  "View more",
                  style: TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===== MOCK JSON FOR VENUES =====
const mockVenueJson = {
  "vendor_type_id": 2,
  "vendor_type": "venues",
  "questions": [
    {
      "id": 101,
      "text": "Does your venue allow outside caterers?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": ["Yes", "No"],
      "min": null,
      "max": null
    },
    {
      "id": 202,
      "text": "Does your venue allow outside decorators?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": ["Yes", "No"],
      "min": null,
      "max": null
    },
    {
      "id": 203,
      "text": "Does your venue allow outside DJ?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": ["Yes", "No"],
      "min": null,
      "max": null
    },
    {
      "id": 204,
      "text": "Does your venue allow alcohol from outside?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": ["Yes", "No"],
      "min": null,
      "max": null
    },
    {
      "id": 205,
      "text": "Does your venue allow fireworks?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": ["Yes", "No"],
      "min": null,
      "max": null
    },
    {
      "id": 206,
      "text": "Does your venue have rooms available?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": ["Yes", "No"],
      "min": null,
      "max": null
    },
    {
      "id": 207,
      "text": "What are the different spaces available at your venue?",
      "description": "",
      "label": [],
      "type": "checkbox",
      "options": [
        "Banquet Hall",
        "Lawn",
        "Resort",
        "Marriage Garden",
        "Mandapam",
        "Palace/ Fort",
        "Destination Wedding Venue",
        "Other"
      ],
      "min": null,
      "max": null
    },
    {
      "id": 208,
      "text": "What is your USP (Unique Selling Proposition)?",
      "description": "",
      "label": [],
      "type": "text",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 209,
      "text": "How many guests can you accommodate?",
      "description": "",
      "label": ["Minimum number of guests", "Maximum number of guests"],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 210,
      "text": "Do you provide valet parking?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": ["Yes", "No"],
      "min": null,
      "max": null
    },
    {
      "id": 211,
      "text": "What is the starting price per plate (for veg menu)?",
      "description": "",
      "label": ["Price Per Plate (Veg)"],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 212,
      "text": "What is the starting price per plate (for non-veg menu)?",
      "description": "",
      "label": ["Price Per Plate (Non-Veg)"],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 213,
      "text": "What is the rental charge of your venue (if applicable)?",
      "description": "",
      "label": [],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    }
  ]
};
