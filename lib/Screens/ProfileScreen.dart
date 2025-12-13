import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[300],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.pink[100],
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {

            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundImage: AssetImage("assets/profile.jpg"),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Jiya Wedding Planner ",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text("Wedding Planner • Mumbai",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Menu List
            _buildMenuItem(Icons.settings, "Account Settings", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountSettingsScreen()));
            }),
            _buildMenuItem(Icons.verified_user, "Verify Your Business", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VerifyBusinessScreen()));
            }),
            _buildMenuItem(Icons.payment, "Payment History", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaymentHistoryScreen()));
            }),
            _buildMenuItem(Icons.star, "My Reviews", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyReviewsScreen()));
            }),
            _buildMenuItem(Icons.help_outline, "Help & Support", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpSupportScreen()));
            }),
            _buildMenuItem(Icons.logout, "Logout", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogoutScreen()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {required VoidCallback onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.pinkAccent),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}






class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _nameController = TextEditingController(text: "");
  final _emailController = TextEditingController(text: "");
  final _phoneController = TextEditingController(text: "+91 ");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Settings"),
        backgroundColor: Colors.pinkAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Image
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundImage: AssetImage("assets/images/profile.jpg"),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Name
            _buildTextField("Full Name", _nameController, Icons.person),

            const SizedBox(height: 16),

            // Email
            _buildTextField("Email Address", _emailController, Icons.email),

            const SizedBox(height: 16),

            // Phone
            _buildTextField("Phone Number", _phoneController, Icons.phone),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Account details updated")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.pinkAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
        ),
      ),
    );
  }
}













class VerifyBusinessScreen extends StatefulWidget {
  const VerifyBusinessScreen({super.key});

  @override
  State<VerifyBusinessScreen> createState() => _VerifyBusinessScreenState();
}

class _VerifyBusinessScreenState extends State<VerifyBusinessScreen> {
  final _businessNameC = TextEditingController();
  final _ownerNameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  String? _selectedProof;

  final List<String> proofTypes = [
    "Aadhar Card",
    "PAN Card",
    "GST Certificate",
    "Shop Registration",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Your Business"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Fill in the details below to verify your business on WedMeGood. This helps customers trust your profile more.",
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),

            _buildTextField("Business Name", _businessNameC, Icons.store),
            const SizedBox(height: 16),

            _buildTextField("Owner's Name", _ownerNameC, Icons.person),
            const SizedBox(height: 16),

            _buildTextField("Phone Number", _phoneC, Icons.phone),
            const SizedBox(height: 16),

            _buildTextField("Email Address", _emailC, Icons.email),
            const SizedBox(height: 16),

            // Proof Type Dropdown
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Select Proof Type",
                prefixIcon: const Icon(Icons.badge, color: Colors.pinkAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              value: _selectedProof,
              items: proofTypes
                  .map((proof) => DropdownMenuItem(
                value: proof,
                child: Text(proof),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProof = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Upload Proof Button
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file, color: Colors.pinkAccent),
              label: const Text("Upload Document"),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.pinkAccent),
                foregroundColor: Colors.pinkAccent,
              ),
              onPressed: () {
                // Upload file picker
              },
            ),
            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Verification request sent")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Submit for Verification",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.pinkAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
        ),
      ),
    );
  }
}




class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> paymentHistory = [
      {
        "title": "Wedding Planner",
        "date": "10 Aug 2025",
        "amount": 15000,
        "status": "Paid",
      },
      {
        "title": "Makeup Planner",
        "date": "02 Aug 2025",
        "amount": 5000,
        "status": "Refunded",
      },
      {
        "title": "Makeup Planner",
        "date": "28 Jul 2025",
        "amount": 10000,
        "status": "Pending",
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment History"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: ListView.builder(
        itemCount: paymentHistory.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final payment = paymentHistory[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                payment["title"],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(payment["date"]),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "₹${payment["amount"]}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.pinkAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusChip(payment["status"]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    switch (status) {
      case "Paid":
        bgColor = Colors.green.shade100;
        break;
      case "Refunded":
        bgColor = Colors.orange.shade100;
        break;
      default:
        bgColor = Colors.red.shade100;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}




class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> reviews = [
      {
        "vendor": "Dream Wedding Photography",
        "category": "Photographer",
        "rating": 4.5,
        "review":
        "Amazing photography! Captured every moment beautifully. Highly recommend.",
        "date": "12 Aug 2025",
      },
      {
        "vendor": "Glam Bride Studio",
        "category": "Makeup Artist",
        "rating": 5.0,
        "review":
        "Loved the makeup! It was perfect for my big day and lasted all night.",
        "date": "05 Aug 2025",
      },
      {
        "vendor": "Royal Palace Banquets",
        "category": "Venue",
        "rating": 4.0,
        "review":
        "Spacious venue and great decor, but parking could be improved.",
        "date": "28 Jul 2025",
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reviews"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reviews.length,
        itemBuilder: (context, index) {
          final review = reviews[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vendor name + category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review["vendor"],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              review["category"],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStarRating(review["rating"]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Review text
                  Text(
                    review["review"],
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  // Date
                  Text(
                    review["date"],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    int fullStars = rating.floor();
    bool hasHalfStar = rating - fullStars >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < fullStars; i++)
          const Icon(Icons.star, color: Colors.amber, size: 20),
        if (hasHalfStar)
          const Icon(Icons.star_half, color: Colors.amber, size: 20),
        for (int i = fullStars + (hasHalfStar ? 1 : 0); i < 5; i++)
          const Icon(Icons.star_border, color: Colors.amber, size: 20),
      ],
    );
  }
}









class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> helpOptions = [
      {
        "icon": Icons.question_answer_outlined,
        "title": "FAQs",
        "subtitle": "Find answers to common questions",
        "onTap": () {}
      },
      {
        "icon": Icons.chat_outlined,
        "title": "Chat with Support",
        "subtitle": "Get help from our team instantly",
        "onTap": () {}
      },
      {
        "icon": Icons.mail_outline,
        "title": "Email Us",
        "subtitle": "Send us your query",
        "onTap": () {}
      },
      {
        "icon": Icons.call_outlined,
        "title": "Call Support",
        "subtitle": "Talk directly with our team",
        "onTap": () {}
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: helpOptions.length,
        separatorBuilder: (context, index) =>
        const Divider(height: 1, color: Colors.grey),
        itemBuilder: (context, index) {
          final option = helpOptions[index];
          return ListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.pinkAccent.withOpacity(0.1),
              child: Icon(option["icon"], color: Colors.pinkAccent),
            ),
            title: Text(
              option["title"],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(
              option["subtitle"],
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: option["onTap"],
          );
        },
      ),
    );
  }
}





class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Logout"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout,
              size: 80,
              color: Colors.pinkAccent,
            ),
            const SizedBox(height: 20),
            const Text(
              "Are you sure you want to logout?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              "You will need to log in again to access your account.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // TODO: Perform logout action
              },
              child: const Text(
                "Yes, Logout",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Colors.pinkAccent),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

