import 'package:flutter/material.dart';

class AnswerFaqsScreen extends StatelessWidget {
  const AnswerFaqsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> faqs = [
      {
        "question": "What is your starting price for wedding photography?",
        "status": "Unanswered",
        "color": Colors.red,
      },
      {
        "question": "Do you provide outstation services?",
        "status": "Answered",
        "color": Colors.green,
      },
      {
        "question": "Can we customize the catering menu?",
        "status": "Unanswered",
        "color": Colors.red,
      },
      {
        "question": "What is your cancellation policy?",
        "status": "Answered",
        "color": Colors.green,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.pink[100],
        title: const Text("Answer FAQs"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              title: Text(
                faq["question"],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: faq["color"].withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  faq["status"],
                  style: TextStyle(
                    color: faq["color"],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () {
                _showAnswerDialog(context, faq["question"]);
              },
            ),
          );
        },
      ),
    );
  }

  void _showAnswerDialog(BuildContext context, String question) {
    final TextEditingController _answerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: _answerController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Type your answer here...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              // TODO: Send answer to API
              Navigator.pop(context);
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }
}
