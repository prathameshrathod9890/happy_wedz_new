// PhotographerFaqScreen.dart
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

// ===== FAQ SCREEN =====
class PhotographerFaqScreen extends StatefulWidget {
  const PhotographerFaqScreen({super.key});

  @override
  State<PhotographerFaqScreen> createState() => _PhotographerFaqScreenState();
}

class _PhotographerFaqScreenState extends State<PhotographerFaqScreen> {
  late List<FaqQuestion> faqs = [];
  final Map<int, String> selectedRadio = {};
  final Map<int, List<String>> selectedCheckbox = {};
  final Map<int, double> selectedSlider = {};
  final Map<int, TextEditingController> textControllers = {};
  final Map<int, bool> expandCheckbox = {};

  int vendorId = 0;
  int vendorTypeId = 1;
  String token = "";

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _initFaqScreen();
  }

  Future<void> _initFaqScreen() async {
    // Load vendor data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId') ?? 0;
    vendorTypeId = prefs.getInt('vendorTypeId') ?? (photographerJson['vendor_type_id'] ?? 1) as int;
    token = prefs.getString('authToken') ?? "";

    // Initialize FAQ from static JSON (keeping your static screens)
    final data = photographerJson['questions'] as List<dynamic>;
    faqs = data.map((e) => FaqQuestion.fromJson(e)).toList();

    // Prepare text controllers
    for (var q in faqs) {
      if (q.type == 'text' || q.type == 'textarea' || q.type == 'number') {
        textControllers[q.id] = TextEditingController();
      }
    }

    // If vendor exists and token present, fetch saved answers from backend
    if (vendorId != 0 && token.isNotEmpty) {
      await _fetchFaqAnswers();
    } else {
      // no vendor yet — that's fine, user can fill; we will save pending answers if they try to submit
      setState(() {});
    }
  }

  // ===== FETCH SAVED ANSWERS =====
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
          "Photographer FAQs",
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
              max: q.max?.toDouble() ?? 100,
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

// ===== MOCK JSON =====
const photographerJson = {
  "vendor_type_id": 1,
  "vendor_type": "Photographer",
  "questions": [
    {
      "id": 3101,
      "text":
      "What is the price for 1 day Marriage offering that includes Photography and Videography (Candid/ Cinematographic & Traditional) for an audience size of 300?",
      "description":
      "Enter your average pricing in order for your Storefront to appear in results when couples seach by price",
      "label": ["1 Day Wedding Package"],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 3102,
      "text":
      "What is the price for 1 day pre-wedding photoshoot? (Typically includes: Teaser & a highlight video with photographs shot candidly and traditionally)",
      "description": "",
      "label": [],
      "type": "range",
      "options": [],
      "min": 0,
      "max": 1000000
    },
    {
      "id": 3103,
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
      "id": 3104,
      "text":
      "What is the price for 2 day wedding package that covers enagagement/reception & wedding for an audienece size od 300?(Typically includes: Photography & Videography, both shot candidly and traditionally)",
      "description": "",
      "label": [],
      "type": "range",
      "options": [],
      "min": 0,
      "max": 1000000
    },
    {
      "id": 3105,
      "text":
      "What is the price for 3 day wedding package that covers pre-wedding, enagaement/reception & wedding for an audience size of 300? (Typically includes: Photography & videogarphy, both shot candidly and traditioanlly)",
      "description": "",
      "label": [],
      "type": "range",
      "options": [],
      "min": 0,
      "max": 1000000
    },
    {
      "id": 3106,
      "text": "What are the occasions that you cover?",
      "description": "",
      "label": [],
      "type": "checkbox",
      "options": [
        "Wedding & engagement",
        "Engagement photography",
        "Mehandi & sangeet",
        "Couple pre-wedding",
        "Parties",
        "Corporate events",
        "Maternity shoot",
        "Baby shoot"
      ],
      "min": null,
      "max": null
    },
    {
      "id": 3107,
      "text": "What shooting capabilities do you provide?",
      "description": "",
      "label": [],
      "type": "checkbox",
      "options": [
        "Traditional",
        "Candid",
        "Cinematographic",
        "Drone Shoots",
        "Photobooth",
        "Live Screening",
      ],
      "min": null,
      "max": null
    },
    {
      "id": 3108,
      "text": "Do you travel outstation",
      "description": "",
      "label": [],
      "type": "radio",
      "options": ["Yes", "No"],
      "min": null,
      "max": null
    },
    {
      "id": 3109,
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
      "id": 3110,
      "text": "What is the % advance amount to confirm the booking?",
      "description": "",
      "label": [],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 3111,
      "text": "What is your cancellation policy?",
      "description": "",
      "label": [],
      "type": "textarea",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 3112,
      "text": "Which year did you/your company professionally start services in?",
      "description": "",
      "label": [],
      "type": "number",
      "options": [],
      "min": null,
      "max": null,
    },
    {
      "id": 3113,
      "text":
      "What is the price range for 1 day pre-wedding photoshoot? (Typically includes: Teaser & a highlight video with photographs shot candidly and traditioanlly)",
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
        "₹1,50,000 - ₹1,99,999",
        "₹2,00,000 and more",
      ],
      "min": null,
      "max": null
    },
    {
      "id": 3114,
      "text":
      "What is the price range for 2 day wedding package that covers engagement/reception & wedding for an audience size of 300? (Typically includes: Photography & Videography, both shot candidly and traditionally)",
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
        "₹1,50,000 - ₹1,99,999",
        "₹2,00,000 and more",
      ],
      "min": null,
      "max": null
    },
    {
      "id": 3115,
      "text":
      "What is the price range for 2 day wedding package that covers engagement/reception & wedding for an audience size of 300? (Typically includes: Photography & Videography, both shot candidly and traditionally)",
      "description": "",
      "label": [],
      "type": "radio",
      "options": [
        "Under ₹50,000",
        "₹50,000 - ₹74,999",
        "₹75,000 - ₹99,999",
        "₹1,00,000 - ₹1,49,999",
        "₹1,50,000 - ₹1,99,999",
        "₹2,00,000 - ₹2,49,999",
        "₹2,50,000 - ₹2,99,999",
        "₹3,00,000 and more",
      ],
      "min": null,
      "max": null
    },
    {
      "id": 3116,
      "text":
      "What is the price range for 3 day wedding package that covers engagement/reception & wedding for an audience size of 300? (Typically includes: Photography & Videography, both shot candidly and traditionally)",
      "description": "",
      "label": [],
      "type": "radio",
      "options": [
        "Under ₹75,000",
        "₹75,000 - ₹99,999",
        "₹1,00,000 - ₹1,49,999",
        "₹1,50,000 - ₹1,99,999",
        "₹2,00,000 - ₹2,49,999",
        "₹2,50,000 - ₹2,99,999",
        "₹3,00,000 - ₹3,99,999",
        "₹4,00,000 and more",
      ],
      "min": null,
      "max": null
    },
  ]
};
