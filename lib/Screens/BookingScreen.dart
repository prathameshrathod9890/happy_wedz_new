import 'package:flutter/material.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[300],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Bookings",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _bookingCard(
                    title: "Wedding Photography",
                    client: "Rohan & Priya",
                    date: "25 Aug 2025",
                    status: "Confirmed",
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingDetailsPage(
                            title: "Wedding Photography",
                            client: "Rohan & Priya",
                            date: "25 Aug 2025",
                            status: "Confirmed",
                            color: Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
                  _bookingCard(
                    title: "Wedding Photography",
                    client: "Ankit & Neha",
                    date: "02 Sep 2025",
                    status: "Pending",
                    color: Colors.orange,
                    onTap: () {}
                  ),
                  _bookingCard(
                    title: "Wedding Photography",
                    client: "Isha",
                    date: "10 Sep 2025",
                    status: "Cancelled",
                    color: Colors.red,
                    onTap: () {}
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingCard({
    required String title,
    required String client,
    required String date,
    required String status,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.pinkAccent[100],
                radius: 28,
                child: const Icon(Icons.event, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("Client: $client", style: const TextStyle(color: Colors.grey)),
                    Text("Date: $date", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}








class BookingDetailsPage extends StatelessWidget {
  final String title;
  final String client;
  final String date;
  final String status;
  final Color color;

  const BookingDetailsPage({
    super.key,
    required this.title,
    required this.client,
    required this.date,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        backgroundColor: Colors.pink[300],
        title: const Text("Booking Details"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.pinkAccent[100],
                      radius: 35,
                      child: const Icon(Icons.event, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _detailItem(Icons.person, "Client", client),
                _detailItem(Icons.calendar_today, "Date", date),
                _detailItem(Icons.info_outline, "Status", status, color: color),
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    label: const Text(
                      "Contact Client",
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      // Handle contact action
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.pink[300]),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color ?? Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}


