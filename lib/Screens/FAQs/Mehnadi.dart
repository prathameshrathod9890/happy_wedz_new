import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

// ===== MEHENDI ARTISTS SCREEN =====
class MehendiArtistsScreen extends StatefulWidget {
  const MehendiArtistsScreen({super.key});

  @override
  State<MehendiArtistsScreen> createState() => _MehendiArtistsScreenState();
}

class _MehendiArtistsScreenState extends State<MehendiArtistsScreen> {
  late List<VendorQuestion> questions = [];
  final Map<int, String> selectedRadio = {};
  final Map<int, List<String>> selectedCheckbox = {};
  final Map<int, double> selectedSlider = {};
  final Map<int, TextEditingController> textControllers = {};
  final Map<int, bool> expandCheckbox = {};
  late List<VendorQuestion> faqs = [];

  int vendorId = 0;
  int vendorTypeId = mehendiartistsJson["vendor_type_id"] as int;
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
    vendorTypeId = prefs.getInt('vendorTypeId') ?? mehendiartistsJson["vendor_type_id"] as int;
    token = prefs.getString('authToken') ?? "";

    final data = mehendiartistsJson['questions'] as List<dynamic>;
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
        headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answers = (data["answers"] ?? []) as List<dynamic>;

        for (var ans in answers) {
          final qid = ans["faqQuestionId"];
          var answer = ans["answer"];
          final question = questions.firstWhere(
                (q) => q.id == qid,
            orElse: () => VendorQuestion(
              id: 0,
              text: '',
              description: '',
              label: [],
              type: '',
              options: [],
            ),
          );
          if (question.id == 0) continue;

          if (question.type == "checkbox") {
            try {
              if (answer is String && answer.startsWith("{")) {
                answer = jsonDecode(answer.replaceAll("{", "[").replaceAll("}", "]"));
              }
              selectedCheckbox[qid] = List<String>.from(answer);
            } catch (_) {
              selectedCheckbox[qid] = [];
            }
          } else if (question.type == "radio") {
            selectedRadio[qid] = answer.toString();
          } else if (question.type == "range") {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Mehendi FAQs",
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
        itemCount: questions.length,
        itemBuilder: (context, index) => _buildQuestionCard(questions[index]),
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
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (q.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(q.description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
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
      case "text":
      case "textarea":
        return TextFormField(
          controller: textControllers[q.id],
          keyboardType: q.type == "number" ? TextInputType.number : TextInputType.text,
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
                child: const Text("view more"),
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



// ===== MEHENDI ARTISTS JSON =====
const mehendiartistsJson = {
  "vendor_type_id": 5,
  "vendor_type": "mehendiartists",
  "questions": [
    {"id":801,"text":"Which types of mehendi designs do you offer?","description":"","label":[],"type":"checkbox","options":["Indian","Arabic","Indo-Arabic","Western","Indo-western","Moroccan","Pakistani","Customised designs"],"min":null,"max":null},
    {"id":802,"text":"Do you provide home service?","description":"","label":[],"type":"radio","options":["Yes","No"],"min":null,"max":null},
    {"id":803,"text":"What is your starting price for bridal mehendi?","description":"","label":["Price (Bridal Mehendi)"],"type":"number","options":[],"min":null,"max":null},
    {"id":804,"text":"What is your starting price range for family/guest mehendi?","description":"","label":[],"type":"radio","options":["Under ₹1,000","₹1,000 - ₹2,499","₹2,500 - ₹4,999","₹5,000 - ₹7,499","₹7,500 and above"],"min":null,"max":null},
    {"id":805,"text":"How many mehendi artists are available for events?","description":"","label":[],"type":"number","options":[],"min":null,"max":null},
    {"id":806,"text":"Do you provide trials?","description":"","label":[],"type":"radio","options":["Yes","No"],"min":null,"max":null},
    {"id":807,"text":"What is your cancellation policy?","description":"","label":[],"type":"textarea","options":[],"min":null,"max":null},
    {"id":808,"text":"Which year did you/your team professionally start providing mehendi services?","description":"","label":[],"type":"number","options":[],"min":null,"max":null}
  ]
};
