import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

// ===== FLORIST FAQ SCREEN =====
class FloristFaqScreen extends StatefulWidget {
  const FloristFaqScreen({super.key});

  @override
  State<FloristFaqScreen> createState() => _FloristFaqScreenState();
}

class _FloristFaqScreenState extends State<FloristFaqScreen> {
  late List<FaqQuestion> faqs = [];
  final Map<int, String> selectedRadio = {};
  final Map<int, List<String>> selectedCheckbox = {};
  final Map<int, double> selectedSlider = {};
  final Map<int, TextEditingController> textControllers = {};
  final Map<int, bool> expandCheckbox = {};

  int vendorId = 0;
  int vendorTypeId = 13; // Florist
  String token = "";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initFaqScreen();
  }

  Future<void> _initFaqScreen() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId') ?? 0;
    vendorTypeId = prefs.getInt('vendorTypeId') ?? floristJson['vendor_type_id'] as int;
    token = prefs.getString('authToken') ?? "";

    final data = floristJson['questions'] as List<dynamic>;
    faqs = data.map((e) => FaqQuestion.fromJson(e)).toList();

    for (var q in faqs) {
      if (q.type == 'text' || q.type == 'textarea' || q.type == 'number') {
        textControllers[q.id] = TextEditingController();
      }
    }

    if (vendorId != 0 && token.isNotEmpty) {
      await _fetchFaqAnswers();
    } else {
      setState(() {});
    }
  }

  // ===== FETCH SAVED ANSWERS =====
  Future<void> _fetchFaqAnswers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("https://happywedz.com/api/faq-answers/$vendorId"),
        headers: {"Authorization": "Bearer $token"},
      );

      print("📩 Fetch response (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answers = data['answers'] ?? [];
        for (var ans in answers) {
          final qid = ans['faqQuestionId'];
          var answer = ans['answer'];

          final question = faqs.firstWhere(
                (q) => q.id == qid,
            orElse: () => FaqQuestion(id: 0, text: '', description: '', label: [], type: '', options: []),
          );
          if (question.id == 0) continue;

          if (question.type == 'checkbox') {
            try {
              if (answer is String && answer.startsWith('{')) {
                answer = jsonDecode(answer.replaceAll('{', '[').replaceAll('}', ']'));
              }
              selectedCheckbox[qid] = List<String>.from(answer);
            } catch (_) {
              selectedCheckbox[qid] = [];
            }
          } else if (question.type == 'radio') {
            selectedRadio[qid] = answer.toString();
          } else if (question.type == 'range') {
            selectedSlider[qid] = (answer is num) ? answer.toDouble() : (question.min?.toDouble() ?? 0);
          } else {
            textControllers[qid]?.text = answer.toString();
          }
        }
      } else {
        print("❌ Failed to fetch FAQ answers: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Error fetching FAQ answers: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ===== SAVE ANSWERS =====
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

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Florists FAQs",
          style: TextStyle(color: Colors.black), // optional for better contrast
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFE0F7FA), // 🌸 light WedMeGood blue
        elevation: 0, // optional: gives a clean flat look
        iconTheme: const IconThemeData(color: Colors.black), // optional for visibility
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: faqs.length,
        itemBuilder: (context, index) => _buildFaqCard(faqs[index]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.pinkAccent,
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
            Text(q.text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (q.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(q.description,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
        return TextFormField(
          controller: textControllers[q.id],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: q.label.isNotEmpty ? q.label.first : "Enter answer",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
          ),
        );
      case "radio":
        return Column(
          children: q.options
              .map((opt) => RadioListTile(
            title: Text(opt),
            value: opt,
            groupValue: selectedRadio[q.id],
            onChanged: (val) => setState(() => selectedRadio[q.id] = val.toString()),
          ))
              .toList(),
        );
      case "checkbox":
        int visibleCount = expandCheckbox[q.id] == true ? q.options.length : 2;
        List<String> visibleOptions = q.options.take(visibleCount).toList();
        return Column(
          children: [
            ...visibleOptions.map((opt) {
              bool checked = selectedCheckbox[q.id]?.contains(opt) ?? false;
              return CheckboxListTile(
                value: checked,
                title: Text(opt),
                onChanged: (val) {
                  setState(() {
                    selectedCheckbox[q.id] ??= [];
                    if (val == true) selectedCheckbox[q.id]!.add(opt);
                    else selectedCheckbox[q.id]!.remove(opt);
                  });
                },
              );
            }),
            if (q.options.length > 2 && expandCheckbox[q.id] != true)
              TextButton(
                onPressed: () => setState(() => expandCheckbox[q.id] = true),
                child: const Text("View more"),
              ),
          ],
        );
      case "range":
        double value = selectedSlider[q.id] ?? (q.min?.toDouble() ?? 0.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Slider(
              value: value,
              min: q.min?.toDouble() ?? 0,
              max: q.max?.toDouble() ?? 100000,
              divisions: 10,
              label: value.toStringAsFixed(0),
              onChanged: (val) => setState(() => selectedSlider[q.id] = val),
            ),
            Text("Selected: ${value.toStringAsFixed(0)}"),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}

// ===== MOCK JSON FOR FLORIST =====
const floristJson = {
  "vendor_type_id": 13,
  "vendor_type": "Florist",
  "questions": [
    {
      "id": 801,
      "text":
      "What is the price for flower based traditional decoration for an indoor venue setup for 100 PAX for pre-wedding/ reception events? (Typically includes decoration of: entrance-8x8 ft, passage, guest area, stage area-16x12 ft)?",
      "description":
      "Enter your average pricing in order for your Storefront to appear in results when couples search by price.",
      "label": ["Venue decor"],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 802,
      "text":
      "What is the starting price for indoor floral decor services?",
      "description": "",
      "label": [],
      "type": "range",
      "options": [],
      "min": 0,
      "max": 1000000
    },
    {
      "id": 803,
      "text":
      "What is the starting price for flower based traditional decoration for an indoor venue setup for 100 PAX for pre-wedding/ reception events? (Typically includes decoration of: entrance-8x8 ft, passage, guest area, stage area-16x12 ft)?  ",
      "description":"",
      "label": [],
      "type": "range",
      "options": [],
      "min": 0,
      "max": 1000000
    },
    {
      "id": 804,
      "text":
      "Are you ready to host/provide service to events during COVID19, following the government guidelines?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": [
        "Information not available",
        "Not operational",
        "Yes, with special deals",
        "Yes"
      ],
      "min": null,
      "max": null
    },
    {
      "id": 805,
      "text":
      "What is the starting price for outdoor floral decor services?",
      "description":"",
      "label": [],
      "type": "range",
      "options": [],
      "min": 0,
      "max": 2000000
    },
    {
      "id": 806,
      "text":
      "What is the starting price for flower based traditional decoration for an outdoor setup for 300 PAX for wedding events? (Typically includes decoration of: entrance, passage, guest area, stage area, mandapa)",
      "description":"",
      "label": [],
      "type": "range",
      "options": [],
      "min": 0,
      "max": 2000000
    },
    {
      "id": 807,
      "text": "Which flowers do you provide for floral decorations?",
      "description": "",
      "label": [],
      "type": "checkbox",
      "options": [
        "Jasmine",
        "Sunflower",
        "Lotus",
        "Rose",
        "Orchid",
        "Lillies",
        "Perwinkle",
        "Bougainvillaea",
        "Marigold",
        "Hibiscus",
        "Carnations",
        "Gerbera"
      ],
      "min": null,
      "max": null
    },

    {
      "id": 808,
      "text": "Which forms of payment do you accept?",
      "description": "",
      "label": [],
      "type": "checkbox",
      "options": [
        "Cash",
        "Cheque/ DD",
        "Credit/ Debit card",
        "UPI",
        "Net Banking",
        "Mobile wallets"
      ],
      "min": null,
      "max": null
    },
    {
      "id": 809,
      "text": "What is the % payment/ amount to confirm the booking?",
      "description": "",
      "label": [],
      "type": "text",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 810,
      "text": "What is the cancellation policy?",
      "description": "",
      "label": [],
      "type": "text",
      "options": [],
      "min": null,
      "max": null
    },

    {
      "id": 811,
      "text": "Which year did you/your company professionally start services in?",
      "description": "",
      "label": [],
      "type": "number",
      "options": [],
      "min": null,
      "max": null,
    },
    {
      "id": 812,
      "text": "Awards, recognitions and publications",
      "description": "",
      "label": [],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 813,
      "text":
      "What is the price range for flower based home decoration for sangeet related events? (Typically includes decoration of balcony, entrance, & common area)?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": [
        "Under ₹5,000",
        "₹5,000 - ₹9,999",
        "₹10,000 - ₹14,999",
        "₹15,000 - ₹19,999",
        "₹20,000 - ₹24,999",
        "₹25,000 - ₹29,999",
        "₹30,000 - ₹39,999",
        "₹40,000 - ₹49,999",
        "₹50,000 and more",
      ],
      "min": null,
      "max": null
    },
    {
      "id": 814,
      "text":
      "What is the price range for flower based traditional decoration for an indoor venue setup for 100 PAX for pre-wedding/ reception events? (Typically includes decoration of entrance-8x8 ft, passage, guest area, stage area-16x12 ft)?",
      "description": "",
      "label": [],
      "type": "radio",
      "options": [
        "Under ₹25,000",
        "₹25,000 - ₹49,999",
        "₹50,000 - ₹74,999",
        "₹75,000 - ₹99,999",
        "₹1,00,000 - ₹1,24,999",
        "₹1,25,000 - ₹1,49,999",
        "₹1,50,000 - ₹1,74,999",
        "₹1,75,000 - ₹1,99,999",
        "₹2,00,000 and more",
      ],
      "min": null,
      "max": null
    },
    {
      "id": 815,
      "text":
      "What is the price range for flower based traditional decoration for an outdoor setup for 300 PAX for wedding events?(Typically includes decoration of: entrance, passage, guest area, stage area, mandapa)",
      "description": "",
      "label": [],
      "type": "radio",
      "options": [
        "Under ₹50,000",
        "₹50,000 - ₹74,999",
        "₹75,000 - ₹99,999",
        "₹1,00,000 - ₹1,24,999",
        "₹1,25,000 - ₹1,49,999",
        "₹1,50,000 - ₹1,74,999",
        "₹1,75,000 - ₹1,99,999",
        "₹2,00,000 - ₹2,99,999",
        "₹3,00,000 and more",
      ],
      "min": null,
      "max": null
    },

    // Add remaining questions as needed
  ]
};
