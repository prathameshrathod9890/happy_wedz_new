import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ProfileScreen.dart';

// ===== MODEL =====
class VendorQuestion {
  final int id;
  final String text;
  final String description;
  final List<String> label;
  final String type;
  final List<String> options;
  final int? min;
  final int? max;

  VendorQuestion({
    required this.id,
    required this.text,
    required this.description,
    required this.label,
    required this.type,
    required this.options,
    this.min,
    this.max,
  });

  factory VendorQuestion.fromJson(Map<String, dynamic> json) {
    return VendorQuestion(
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

// ===== CATERER FAQ SCREEN =====
class CatererFaqScreen extends StatefulWidget {
  const CatererFaqScreen({super.key});

  @override
  State<CatererFaqScreen> createState() => _CatererFaqScreenState();
}

class _CatererFaqScreenState extends State<CatererFaqScreen> {
  late List<VendorQuestion> questions = [];
  final Map<int, String> selectedRadio = {};
  final Map<int, List<String>> selectedCheckbox = {};
  final Map<int, double> selectedSlider = {};
  final Map<int, TextEditingController> textControllers = {};
  final Map<int, bool> expandCheckbox = {};

  int vendorId = 0;
  int vendorTypeId = 7; // Caterer
  String token = "";
  bool isLoading = false;

  late List<VendorQuestion> faqs = [];

  @override
  void initState() {
    super.initState();
    _initFaqScreen();
  }

  Future<void> _initFaqScreen() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId') ?? 0;
    vendorTypeId =
        prefs.getInt('vendorTypeId') ?? (mockCatererJson['vendor_type_id'] ?? 7) as int;
    token = prefs.getString('authToken') ?? "";


    final data = mockCatererJson['questions'] as List<dynamic>;
    faqs = data.map((e) => VendorQuestion.fromJson(e)).toList();
    questions = faqs;


    for (var q in questions) {
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

          final question = questions.firstWhere(
                (q) => q.id == qid,
            orElse: () => VendorQuestion(id: 0, text: '', description: '', label: [], type: '', options: []),
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
      appBar: AppBar(
        title: const Text(
          "Caterer FAQs",
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
        padding: const EdgeInsets.all(12),
        itemCount: questions.length,
        itemBuilder: (context, index) =>
            _buildQuestionCard(questions[index]),
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

  Widget _buildQuestionCard(VendorQuestion q) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (q.description.isNotEmpty) Text(q.description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            _buildInput(q),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(VendorQuestion q) {
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
              TextButton(onPressed: () => setState(() => expandCheckbox[q.id] = true), child: const Text("View more")),
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



// ===== FULL MOCK JSON =====
const mockCatererJson = {
  "vendor_type_id": 7,
  "vendor_type": "Caterers",
  "questions": [
    {
      "id": 101,
      "text":
      "What is the price of veg menu for 20 items that includes beverages, food appetizers, main course & desserts items (excluding seafood) for 300 PAX?",
      "description": "",
      "label": ["Price Per Plate"],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 102,
      "text": "How many guests can you accomodate in your event space?",
      "description": "",
      "label": ["Minimum number of guests", "Maximum number of guests"],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 103,
      "text":
      "What is the price of non-veg menu for 20 items that includes beverages,, food appetizers, main course & desserts items (including seafood) for 300 PAX?",
      "description": "",
      "label": [],
      "type": "range",
      "options": [],
      "min": 0,
      "max": 10000
    },
    {
      "id": 104,
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
      "id": 105,
      "text": "What all menus & catering options do you have?",
      "description": "",
      "label": [],
      "type": "checkbox",
      "options": [
        "North indian/ mughlai",
        "Italian/ european/ continental",
        "Chinese/ thai/ oriental",
        "South indian",
        "Garlic Free/ Onion Free",
        "Live food counters",
        "Chaat & Indian street food",
        "Seafood",
        "Drinks (non-alcoholic)"
      ],
      "min": null,
      "max": null
    },
    {
      "id": 106,
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
      "id": 107,
      "text": "What is the % payment/ amount to confirm the booking?",
      "description": "",
      "label": [],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 108,
      "text": "What is the cancellation policy?",
      "description": "",
      "label": [],
      "type": "text",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 109,
      "text": "Awards, recognitions and publications",
      "description": "",
      "label": [],
      "type": "textarea",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 110,
      "text":
      "Which year did you/your company professionally start your services ?",
      "description": "",
      "label": [],
      "type": "number",
      "options": [],
      "min": null,
      "max": null
    },
    {
      "id": 111,
      "text":
      "What is the price range of the veg menu for 300 PAX? (Typically include charges for beverages, food appetizers, main course & dessert items)",
      "description": "",
      "label": [],
      "type": "radio",
      "options": [
        "Under ₹500",
        "₹500 - ₹799",
        "₹800 - ₹1199",
        "₹1200 - ₹1499",
        "₹1500 - ₹1799",
        "₹1800 - ₹1999",
        "₹2000 - ₹2499",
        "₹2500 - ₹2999",
        "₹3000 and more"
      ],
      "min": null,
      "max": null
    },
    {
      "id": 112,
      "text":
      "What is the price range of the non veg menu for 300 PAX? (Typically include charges for beverages, food appetizers, main course & dessert items excluding seafood)",
      "description": "",
      "label": [],
      "type": "radio",
      "options": [
        "Under ₹500",
        "₹500 - ₹799",
        "₹800 - ₹1199",
        "₹1200 - ₹1499",
        "₹1500 - ₹1799",
        "₹1800 - ₹1999",
        "₹2000 - ₹2499",
        "₹2500 - ₹2999",
        "₹3000 and more"
      ],
      "min": null,
      "max": null
    }
  ]
};



