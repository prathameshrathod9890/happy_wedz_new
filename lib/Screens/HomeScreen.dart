import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:happy_wedz_vendore_new/Screens/FAQs/Makeup.dart';
import 'package:happy_wedz_vendore_new/Screens/FAQs/Pandits.dart';
import 'package:happy_wedz_vendore_new/Screens/ReviewScreen.dart';
import 'package:happy_wedz_vendore_new/Screens/StatsScreen.dart';
import 'package:happy_wedz_vendore_new/Screens/upload_album_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'FAQs/Florists.dart';
import 'FAQs/ProfileScreen.dart';
import 'LeadsScreen.dart';
import 'drawer.dart';
import 'FAQs/BridalWear.dart';
import 'FAQs/Caterars.dart';
import 'FAQs/Decorator.dart';
import 'FAQs/GroomWear.dart';
import 'FAQs/Jewellery and Accessories.dart';
import 'FAQs/Mehnadi.dart';
import 'FAQs/Photographer.dart';
import 'FAQs/Venues.dart';
import 'FAQs/WeddingDj.dart';
import 'FAQs/WeddingGift.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  //int? vendorId;


  final List<Widget> _defaultPages = [
    const HomeTab(),     // 0 - Home
    const LeadsPage(),   // 1 - Leads
    const ReviewsPage(), // 2 - Reviews
    const StatsPage(),   // 3 - Profile / Stats
  ];


  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List.from(_defaultPages);
    //_loadVendorId();
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],


      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF00509D),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,

        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              "assets/icons/home.png",
              height: 24,
              color: _selectedIndex == 0
                  ? const Color(0xFF00509D)
                  : Colors.grey,
            ),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              "assets/icons/leads.png",
              height: 24,
              color: _selectedIndex == 1
                  ? const Color(0xFF00509D)
                  : Colors.grey,
            ),
            label: "Leads",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              "assets/icons/reviews.png",
              height: 24,
              color: _selectedIndex == 2
                  ? const Color(0xFF00509D)
                  : Colors.grey,
            ),
            label: "Reviews",
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              "assets/icons/statistics.png",
              height: 24,
              color: _selectedIndex == 3
                  ? const Color(0xFF00509D)
                  : Colors.grey,
            ),
            label: "Statistics",
          ),
        ],
      ),

    );
  }
  }

//---------------- Home Tab ----------------
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  double _progress = 0.0;
  String _vendorTypeName = "";
  List<dynamic> _recentLeads = [];
  bool _isLoading = true;

  final Map<String, Widget Function()> faqScreens = {
    "photographers": () => const PhotographerFaqScreen(),
    "venues": () => const VenueFaqScreen(),
    "makeup": () => const BridalMakeupFaqScreen(),
    "planning and decor": () => DecoratorFaqScreen(),
    "caterers": () => CatererFaqScreen(),
    "invites and gifts": () => GiftsScreen(),
    "florists": () => FloristFaqScreen(),
    "pandits": () => PanditsFaqScreen(),
    "bridal": () => BridalwearFaqScreen(),
    "groom": () => GroomwearScreen(),
    "jewellery and accessories": () => JewelleryFaqScreen(),
    "mehndi": () => MehendiArtistsScreen(),
    "music and dance": () => WeddingDjScreen(),
  };

  @override
  void initState() {
    super.initState();
    _loadVendorType();
    _fetchRecentLeads();
    super.didChangeDependencies();
    _refreshProgress();

  }

  Future<void> _refreshProgress() async {
    double p = await ProfileCompletionController.getCompletion();
    setState(() {
      _progress = p;
    });
  }


  Future<void> _loadVendorType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _vendorTypeName = prefs.getString('vendorTypeName') ?? "";
    });
  }

  Future<void> _fetchRecentLeads() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token') ?? prefs.getString('authToken');

      if (token == null || token.isEmpty) {
        print("🔴 No token found");
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(
        Uri.parse("https://happywedz.com/api/inbox"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      print("🟢 Recent Leads Status: ${response.statusCode}");
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          final leads = data["inbox"] ?? data["data"] ?? [];
          _recentLeads = leads.take(2).toList(); // show top 2
          _isLoading = false;
        });
      } else {
        print("❌ Failed: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("⚠️ Error fetching recent leads: $e");
      setState(() => _isLoading = false);
    }
  }

  Widget _queriesCard(BuildContext context) {
    int count = _recentLeads.length; // Number of new queries

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeadsPage()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF00509D), // Steel Azure background
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                    children: [
                      const TextSpan(text: "You have "),
                      TextSpan(
                          text: "$count new queries",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),

            const Text(
              "View",
              style: TextStyle(
                decoration: TextDecoration.underline,
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,


      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF003F88), // French Blue
        title: const Text(
          "HappyWeds Business",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),

      drawer: BusinessDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileCompletionBar(progress: _progress),
            const SizedBox(height: 15),
            _queriesCard(context),
            const SizedBox(height: 15),
            // _quickActionsBar(context, _vendorTypeName, faqScreens),
            const SizedBox(height: 10),
            _uploadAlbumCard(context),
            SizedBox(height: 24),
            _getReviewsCard(context),
            SizedBox(height: 24),

          ],
        ),
      ),
    );
  }


}

// ---------------- Helper Widgets ----------------

Widget _profileCompletionCard() {
  return _buildCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start
      ,
      children: [
        const Text("Complete your profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),

      ],
    ),
  );
}

// Widget _quickActionsBar(
//     BuildContext context,
//     String vendorTypeName,
//     Map<String, Widget Function()> faqScreens,
//     ) {
//   final actions = [
//     {
//       "icon": Icons.question_answer_outlined,
//       "title": "Answer FAQs",
//       "onTap": () {
//         final screenBuilder =
//         faqScreens[vendorTypeName.trim().toLowerCase()];
//         if (screenBuilder != null) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => ProfilescreenWithNext(
//                 onNext: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => screenBuilder()),
//                   );
//                 },
//               ),
//             ),
//           );
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//                 content:
//                 Text("No FAQ screen available for your vendor type")),
//           );
//         }
//       }
//     },
//     {
//       "icon": Icons.link,
//       "title": "Link Facebook page /Website",
//       "onTap": () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const ProfilescreenWithNext()),
//         );
//       }
//     },
//     // {
//     //   "icon": Icons.add_a_photo,
//     //   "title": "Add Images to portfolio",
//     //   "onTap": () {
//     //     Navigator.push(
//     //         context, MaterialPageRoute(builder: (_) => PortfoliioPage()));
//     //   }
//     // },
//     {
//       "icon": Icons.cloud_upload,
//       "title": "Upload the first Album",
//       "onTap": () {
//         Navigator.push(
//             context, MaterialPageRoute(builder: (_) => AlbumsPage()));
//       }
//     },
//     {
//       "icon": Icons.reviews,
//       "title": "Get Client Review to You",
//       "onTap": () async {
//         await Share.share(
//           "Hey! Please share your review about my work 😊",
//           subject: "Client Review Request",
//         );
//       },
//     },
//   ];
//
//   return Padding(
//     padding: const EdgeInsets.only(left: 12, top: 2, bottom: 4),
//     child: SizedBox(
//       height: 38,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: actions.length,
//         itemBuilder: (context, index) {
//           final item = actions[index];
//           return GestureDetector(
//             onTap: item["onTap"] as void Function()?,
//             child: Container(
//               margin: const EdgeInsets.only(right: 8),
//               padding:
//               const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFE0F7FA),
//                 borderRadius: BorderRadius.circular(24),
//                 border:
//                 Border.all(color: const Color(0xFF00BCD4), width: 0.8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(item["icon"] as IconData,
//                       size: 15, color: const Color(0xFF00BCD4)),
//                   const SizedBox(width: 4),
//                   Text(
//                     item["title"] as String,
//                     style: const TextStyle(
//                       fontSize: 11.5,
//                       fontWeight: FontWeight.w500,
//                       color: Colors.black87,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     ),
//   );
// }
Widget _uploadAlbumCard(BuildContext context) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F3FA), // Light blue background
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.image_outlined,
          size: 48,
          color:Color(0xFF00509D), // Blue icon
        ),

        const SizedBox(height: 16),

        const Text(
          "Upload Albums",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          "Upload more pictures of your\nwork to get more leads",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black87),
        ),

        const SizedBox(height: 20),

        // White rounded button
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadAlbumPage()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00509D), // Steel Azure
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            "Add Album",
            style: TextStyle(
              color: Colors.white, // White text
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        )

      ],
    ),
  );
}

Widget _getReviewsCard(BuildContext context) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F3FA), // Light grey background
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.star_border,
          size: 40,
          color: Color(0xFF00509D),
        ),

        const SizedBox(height: 16),

        const Text(
          "Get More Reviews",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          "Improve your credibility by\ngetting more reviews from your\nclients",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black87),
        ),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ask for Reviews Button
            _roundedOutlineButton(
              label: "Ask for\nReviews",
              onTap: () {},
            ),

            const SizedBox(width: 16),

            // Upload Reviews Button
            _roundedOutlineButton(
              label: "Upload\nReviews",
              onTap: () {},
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _roundedOutlineButton({required String label, required VoidCallback onTap}) {
  return OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Colors.black54),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(40),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 26),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
    ),
  );
}

// Widget _phoneUpdateCard() {
//   return Container(
//     padding: const EdgeInsets.all(16),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(12),
//       border: Border.all(color: Colors.grey.shade300),
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           "Have any queries? Speak to happy Weds Team",
//           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//         ),
//         const SizedBox(height: 16),
//
//         // Green Button
//     SizedBox(
//       width: double.infinity,
//       child: ElevatedButton.icon(
//         onPressed: () {},
//         icon: const Icon(Icons.phone, color: Colors.white),
//         label: const Text(
//           "Request Call Back",
//           style: TextStyle(color: Colors.white, fontSize: 16),
//         ),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: const Color(0xFF00509D), // Steel Azure
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//       ),
//     ),
//
//     ],
//     ),
//   );
// }



//
// Widget _membershipPlansCard(BuildContext context) {
//   return _buildCard(
//     child: Row(
//       children: [
//         const Icon(
//           Icons.card_membership,
//           color: Color(0xFF00509D), // Steel Azure
//           size: 40,
//         ),
//         const SizedBox(width: 12),
//         const Expanded(
//           child: Text(
//             "Upgrade to Premium Membership to get more leads & visibility",
//             style: TextStyle(fontSize: 14),
//           ),
//         ),
//         TextButton(
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => ViewPlansScreen()),
//             );
//           },
//           child: const Text("View Plans"),
//         ),
//       ],
//     ),
//   );
// }

Widget _buildCard({required Widget child, Color? color}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}





class GetNowPage extends StatelessWidget {
  const GetNowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA),

      appBar: AppBar(
        backgroundColor: const Color(0xFFE0F7FA),


        title: const Text(
          "Boost Your Reviews",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFB6C1),Color(0xFF00BCD4),
      ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎞️ Lottie animation for Coming Soon (online asset)
            Lottie.network(
              'https://assets10.lottiefiles.com/packages/lf20_x62chJ.json',
              width: 220,
              repeat: true,
            ),
            const SizedBox(height: 30),

            // ✨ Shimmer-like animated text
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Colors.yellowAccent, Colors.white],
              ).createShader(bounds),
              child: const Text(
                "Coming Soon!",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Exciting Membership Plans are on the way.\nStay tuned for amazing benefits!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),

            // 🌸 Soft bouncing “Stay Tuned” button (disabled)
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                "Stay Tuned ❤️",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                    color: Color(0xFF00BCD4),


                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
