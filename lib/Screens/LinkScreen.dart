import 'package:flutter/material.dart';

class LinkPageScreen extends StatelessWidget {
  const LinkPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _linkController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Link Facebook Page / Website",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.pink[300],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add a link to your Facebook page or website so that customers can know more about you.",
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Input field
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: "Enter Facebook / Website Link",
                hintText: "https://www.facebook.com/yourpage",
                prefixIcon: const Icon(Icons.link, color: Colors.pinkAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                ),
              ),
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_linkController.text.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Link Saved: ${_linkController.text}")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Save",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
