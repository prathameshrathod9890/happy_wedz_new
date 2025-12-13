// import 'package:flutter/material.dart';
//
// class ChatScreen extends StatefulWidget {
//   final String receiverName;
//   final String receiverId; // optional if needed later
//
//   const ChatScreen({
//     super.key,
//     required this.receiverName,
//     required this.receiverId,
//   });
//
//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _msgController = TextEditingController();
//
//   // Temporary message list (later you can connect API/Firebase)
//   List<Map<String, dynamic>> messages = [];
//
//   void sendMessage() {
//     final text = _msgController.text.trim();
//     if (text.isEmpty) return;
//
//     setState(() {
//       messages.add({
//         "message": text,
//         "isMe": true,
//         "time": TimeOfDay.now().format(context),
//       });
//     });
//
//     _msgController.clear();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade200,
//
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF00509D),
//         foregroundColor: Colors.white,
//         title: Row(
//           children: [
//             const CircleAvatar(
//               backgroundColor: Colors.white,
//               child: Icon(Icons.person, color: Colors.black),
//             ),
//             const SizedBox(width: 12),
//             Text(widget.receiverName),
//           ],
//         ),
//       ),
//
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.all(12),
//               reverse: true,
//               itemCount: messages.length,
//               itemBuilder: (context, index) {
//                 final msg = messages[messages.length - 1 - index];
//
//                 return Align(
//                   alignment:
//                   msg["isMe"] ? Alignment.centerRight : Alignment.centerLeft,
//                   child: Container(
//                     margin: const EdgeInsets.symmetric(vertical: 4),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 14,
//                       vertical: 10,
//                     ),
//                     constraints:
//                     BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
//                     decoration: BoxDecoration(
//                       color: msg["isMe"]
//                           ? const Color(0xFF00509D)
//                           : Colors.white,
//                       borderRadius: BorderRadius.circular(14),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black12,
//                           blurRadius: 4,
//                           offset: const Offset(0, 2),
//                         )
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           msg["message"],
//                           style: TextStyle(
//                             color: msg["isMe"] ? Colors.white : Colors.black,
//                             fontSize: 15,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Align(
//                           alignment: Alignment.bottomRight,
//                           child: Text(
//                             msg["time"],
//                             style: TextStyle(
//                               color: msg["isMe"]
//                                   ? Colors.white70
//                                   : Colors.black54,
//                               fontSize: 11,
//                             ),
//                           ),
//                         )
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//
//           // ------------------- Bottom Input Box -------------------
//           _buildMessageInput(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageInput() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black12,
//             blurRadius: 4,
//             offset: const Offset(0, -2),
//           )
//         ],
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _msgController,
//               decoration: InputDecoration(
//                 hintText: "Type a message...",
//                 filled: true,
//                 fillColor: Colors.grey.shade100,
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30),
//                   borderSide: BorderSide.none,
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(width: 8),
//
//           CircleAvatar(
//             radius: 26,
//             backgroundColor: const Color(0xFF00509D),
//             child: IconButton(
//               icon: const Icon(Icons.send, color: Colors.white),
//               onPressed: sendMessage,
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final String receiverName;
  final String receiverId;
   //final String conversationId;

  const ChatScreen({
    super.key,
    required this.receiverName,
    required this.receiverId,
   // required this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();

  List<Map<String, dynamic>> messages = [];

  //---------------- FETCH MESSAGES FROM API -----------------
  Future<void> fetchMessages() async {
    const url = "https://happywedz.com/api/messages/vendor/conversations/37/messages";

    const token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NzUwNzcsInJvbGUiOiJ2ZW5kb3IiLCJpYXQiOjE3NjU1MTkwMTQsImV4cCI6MTc2NTY5MTgxNH0.hsiCzY4rGHL50KByPiQBAfTcHmmfjHQopj59TxNZrSo";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);

        setState(() {
          messages = data.map((msg) {
            return {
              "message": msg["message"],
              "isMe": msg["senderType"] == "vendor",
              "time": msg["createdAt"].toString().substring(11, 16),
            };
          }).toList().reversed.toList();
        });
      } else {
        print("Error: ${response.body}");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }

  // Future<void> fetchMessages() async {
  //   final url =
  //       "https://happywedz.com/api/messages/vendor/conversations/${widget.conversationId}/messages";
  //
  //   const token =
  //       "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6NzUwNzcsInJvbGUiOiJ2ZW5kb3IiLCJpYXQiOjE3NjU1MTkwMTQsImV4cCI6MTc2NTY5MTgxNH0.hsiCzY4rGHL50KByPiQBAfTcHmmfjHQopj59TxNZrSo";
  //
  //   try {
  //     final response = await http.get(
  //       Uri.parse(url),
  //       headers: {
  //         "Authorization": "Bearer $token",
  //       },
  //     );
  //
  //     if (response.statusCode == 200) {
  //       List data = jsonDecode(response.body);
  //
  //       setState(() {
  //         messages = data.map((msg) {
  //           return {
  //             "message": msg["message"],
  //             "isMe": msg["senderType"] == "vendor",
  //             "time": msg["createdAt"].toString().substring(11, 16),
  //           };
  //         }).toList().reversed.toList();
  //       });
  //     } else {
  //       print("API Error: ${response.body}");
  //     }
  //   } catch (e) {
  //     print("Exception: $e");
  //   }
  // }


  @override
  void initState() {
    super.initState();
    fetchMessages(); // Fetch API data
  }


  void sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.insert(0, {
        "message": text,
        "isMe": true,
        "time": TimeOfDay.now().format(context),
      });
    });

    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00509D),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Text(widget.receiverName),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];

                return Align(
                  alignment:
                  msg["isMe"] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg["isMe"]
                          ? const Color(0xFF00509D)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg["message"],
                          style: TextStyle(
                            color: msg["isMe"] ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            msg["time"],
                            style: TextStyle(
                              color: msg["isMe"]
                                  ? Colors.white70
                                  : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: "Type a message...",
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF00509D),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: sendMessage,
            ),
          )
        ],
      ),
    );
  }
}
