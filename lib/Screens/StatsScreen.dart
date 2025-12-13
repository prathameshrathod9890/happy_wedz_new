import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  // ---------- Leads (existing) ----------
  String selectedRange = "Daily";
  bool isLoading = true;
  List<dynamic> apiRequests = [];
  String? token;

  int leadCount = 0;
  int viewsCount = 0;


  final List<String> ranges = ["Daily", "Weekly", "Monthly"];
  List<String> leadTypes = [
    "This Week",
    "This Month",
    "Last Month",
    "Custom Range"
  ];
  List<String> selectedLeadTypes = [];

  List<String> dailyLabels = [];
  List<double> dailyValues = [];

  List<String> weeklyLabels = [];
  List<double> weeklyValues = [];

  List<String> monthlyLabels = [];
  List<double> monthlyValues = [];

  // animations (used for both sections)
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  List<String> get xLabels {
    if (selectedRange == "Daily") return dailyLabels;
    if (selectedRange == "Weekly") return weeklyLabels;
    return monthlyLabels;
  }

  List<double> get yValues {
    if (selectedRange == "Daily") return dailyValues;
    if (selectedRange == "Weekly") return weeklyValues;
    return monthlyValues;
  }

  // ---------- Profile Views (new, independent) ----------
  // independent selected range for profile views
  String pvSelectedRange = "Daily";
  List<dynamic> profileViews = []; // list of user objects from wishlist API

  List<String> pvDailyLabels = [];
  List<double> pvDailyValues = [];

  List<String> pvWeeklyLabels = [];
  List<double> pvWeeklyValues = [];

  List<String> pvMonthlyLabels = [];
  List<double> pvMonthlyValues = [];

  int profileViewsTotal = 0; // from vendor/profile-views API

  List<String> get pvXLabels {
    if (pvSelectedRange == "Daily") return pvDailyLabels;
    if (pvSelectedRange == "Weekly") return pvWeeklyLabels;
    return pvMonthlyLabels;
  }

  List<double> get pvYValues {
    if (pvSelectedRange == "Daily") return pvDailyValues;
    if (pvSelectedRange == "Weekly") return pvWeeklyValues;
    return pvMonthlyValues;
  }

  int? vendorId; // resolved from SharedPreferences or token

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnim =
        Tween<double>(begin: 30, end: 0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    fetchDashboardData();
    _saveCountsToPrefs(leadCount, viewsCount);

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Try to read vendorId from SharedPreferences, if not present try to decode from JWT token payload.
  int? _resolveVendorIdFromPrefsOrToken(SharedPreferences prefs, String? token) {
    final int? vid = prefs.getInt("vendor_id");
    if (vid != null) return vid;

    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      String payload = parts[1];

      // base64Url decode with padding fix
      String normalized = base64Url.normalize(payload);
      final Uint8List decoded = base64Url.decode(normalized);
      final Map<String, dynamic> map = jsonDecode(utf8.decode(decoded));
      // payload may contain id or vendor id; check common keys
      if (map.containsKey('id')) return (map['id'] as num).toInt();
      if (map.containsKey('vendorId')) return (map['vendorId'] as num).toInt();
      if (map.containsKey('vendor_id')) return (map['vendor_id'] as num).toInt();
    } catch (e) {
      print("⚠ Error decoding token for vendor id: $e");
    }
    return null;
  }

  Future<void> _saveCountsToPrefs(int leads, int views) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lead_count', leads);
    await prefs.setInt('views_count', views);
    print('✅ Counts saved -> Leads: $leads, Views: $views');
  }


  Future<void> fetchDashboardData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString("token");
      vendorId = _resolveVendorIdFromPrefsOrToken(prefs, token);

      print("🟢 Starting dashboard fetch. token present: ${token != null}, vendorId: $vendorId");

      if (token == null) {
        print("⚠ Token not found");
        setState(() => isLoading = false);
        return;
      }

      if (vendorId == null) {
        print("⚠ vendor_id not found in prefs or token payload");
      }

      // ------------------------------------------------------------------
      // ✅ 1) LEADS API
      // ------------------------------------------------------------------
      final leadUrl = Uri.parse("https://happywedz.com/api/request-pricing/vendor/dashboard");
      final leadRes = await http.get(leadUrl, headers: {"Authorization": "Bearer $token"});
      print("✅ Recent Leads Status: ${leadRes.statusCode}");
      print("📡 Raw Lead Response: ${leadRes.body}");

      if (leadRes.statusCode == 200) {
        final data = jsonDecode(leadRes.body);
        apiRequests = data["requests"] ?? [];
        print("ℹ Loaded ${apiRequests.length} lead requests");
      } else {
        print("⚠ Lead Server Error: ${leadRes.statusCode}");
      }

      // ------------------------------------------------------------------
      // ✅ 2) PROFILE VIEWS TOTAL (Display count)
      // ------------------------------------------------------------------
      profileViewsTotal = 0;

      if (vendorId != null) {
        final pvTotalUrl = Uri.parse("https://happywedz.com/api/vendor/profile-views/$vendorId");
        print("📡 Fetching Profile Views Total → $pvTotalUrl");

        final pvTotalRes =
        await http.get(pvTotalUrl, headers: {"Authorization": "Bearer $token"});

        print("✅ Raw Profile Views Total Response Status: ${pvTotalRes.statusCode}");
        print("✅ Raw Body: ${pvTotalRes.body}");

        if (pvTotalRes.statusCode == 200) {
          final pData = jsonDecode(pvTotalRes.body);

          if (pData["success"] == true && pData["vendor"] != null) {
            final views = pData["vendor"]["profileViews"];
            profileViewsTotal = (views ?? 0).toInt();
            print("✅ Assigned profileViewsTotal → $profileViewsTotal");
          } else {
            print("⚠ Invalid structure in profile-views response");
          }
        } else {
          print("❌ ERROR → Profile Views Total statusCode = ${pvTotalRes.statusCode}");
        }
      }

      // ------------------------------------------------------------------
      // ✅ 3) IMPRESSIONS (wishlist users)
      // ------------------------------------------------------------------
      profileViews = [];
      int impressionCount = 0;

      if (vendorId != null) {
        final profileUrl =
        Uri.parse("https://happywedz.com/api/wishlist/vendor/stats/$vendorId");

        print("📡 Fetching Wishlist Stats (Impressions) → $profileUrl");

        final profileRes =
        await http.get(profileUrl, headers: {"Authorization": "Bearer $token"});

        print("✅ Raw Wishlist Response Status: ${profileRes.statusCode}");
        print("✅ Raw Body: ${profileRes.body}");

        if (profileRes.statusCode == 200) {
          final pData = jsonDecode(profileRes.body);

          if (pData["data"] != null && (pData["data"] as List).isNotEmpty) {
            final first = pData["data"][0];

            if (first != null && first["users"] != null) {
              profileViews = List<dynamic>.from(first["users"]);
            }
          }
        } else {
          print("⚠ Wishlist Server Error: ${profileRes.statusCode}");
        }
      }

      impressionCount = profileViews.length;
      print("✅ impressionCount = $impressionCount");

      // ------------------------------------------------------------------
      // ✅ STORE COUNTS TO PREFERENCES
      // ------------------------------------------------------------------
      await prefs.setInt("lead_count", apiRequests.length);
      await prefs.setInt("views_count", profileViewsTotal);
      await prefs.setInt("impression_count", impressionCount);

      // ✅ Save the counts to SharedPreferences so Drawer can read them

      await prefs.setInt("lead_count", leadCount);
      await prefs.setInt("views_count", viewsCount);

      print("✅ Saved lead_count = $leadCount");
      print("✅ Saved views_count = $viewsCount");


      setState(() {});





      print("✅ SAVED lead_count = ${apiRequests.length}");
      print("✅ SAVED views_count = $profileViewsTotal");
      print("✅ SAVED impression_count = $impressionCount");

      await prefs.setBool("stats_updated", true);

      bool updated = prefs.getBool("stats_updated") ?? false;
      if (updated) setState(() {});

      // ------------------------------------------------------------------
      // ✅ PROCESS STATS
      // ------------------------------------------------------------------
      generateDaily();
      generateWeekly();
      generateMonthly();
      generateProfileDaily();
      generateProfileWeekly();
      generateProfileMonthly();
    } catch (e) {
      print("⚠ Exception: $e");
    }

    setState(() {
      isLoading = false;
    });

    _controller.forward();
  }


  // ----------------- LEADS data generators (unchanged) -----------------
  void generateDaily() {
    dailyLabels.clear();
    dailyValues.clear();

    List<DateTime> last7days =
    List.generate(7, (i) => DateTime.now().subtract(Duration(days: i))).reversed.toList();

    for (var day in last7days) {
      String label = DateFormat("dd MMM").format(day);
      int count = apiRequests.where((req) {
        DateTime d = DateTime.parse(req["createdAt"]);
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
      dailyLabels.add(label);
      dailyValues.add(count.toDouble());
    }
    print("📅 DAILY LABELS → $dailyLabels");
    print("📊 DAILY VALUES → $dailyValues");
  }

  void generateWeekly() {
    weeklyLabels.clear();
    weeklyValues.clear();

    DateTime now = DateTime.now();
    DateTime currentWeekStart = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 6; i++) {
      DateTime weekStart = currentWeekStart.subtract(Duration(days: 7 * i));
      DateTime weekEnd = weekStart.add(const Duration(days: 6));

      String label =
          "${DateFormat('MMM d').format(weekStart)}-${DateFormat('d').format(weekEnd)}";
      weeklyLabels.insert(0, label);

      int count = apiRequests.where((req) {
        DateTime d = DateTime.parse(req["createdAt"]);
        return (d.isAfter(weekStart) || d.isAtSameMomentAs(weekStart)) &&
            (d.isBefore(weekEnd) || d.isAtSameMomentAs(weekEnd));
      }).length;

      weeklyValues.insert(0, count.toDouble());
    }

    print("✅ WEEKLY LABELS → $weeklyLabels");
    print("✅ WEEKLY VALUES → $weeklyValues");
  }

  void generateMonthly() {
    monthlyLabels.clear();
    monthlyValues.clear();

    DateTime now = DateTime.now();

    for (int i = 5; i >= 0; i--) {
      DateTime monthDate = DateTime(now.year, now.month - i, 1);
      String label = DateFormat("MMM").format(monthDate);
      monthlyLabels.add(label);

      int count = apiRequests.where((req) {
        DateTime d = DateTime.parse(req["createdAt"]);
        return d.year == monthDate.year && d.month == monthDate.month;
      }).length;

      monthlyValues.add(count.toDouble());
    }

    print("📅 MONTHLY LABELS → $monthlyLabels");
    print("📊 MONTHLY VALUES → $monthlyValues");
  }

  // ----------------- FILTER for leads (unchanged) -----------------
  void filterDataByLeadType() {
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day);
    DateTime end = now;

    if (selectedLeadTypes.contains("This Week")) {
      start = now.subtract(Duration(days: now.weekday - 1));
      end = start.add(const Duration(days: 6));
    } else if (selectedLeadTypes.contains("This Month")) {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0);
    } else if (selectedLeadTypes.contains("Last Month")) {
      DateTime lastMonthStart = (now.month == 1)
          ? DateTime(now.year - 1, 12, 1)
          : DateTime(now.year, now.month - 1, 1);
      DateTime lastMonthEnd =
      DateTime(lastMonthStart.year, lastMonthStart.month + 1, 0);
      start = lastMonthStart;
      end = lastMonthEnd;
      print("📅 Last Month Range (Leads): $start → $end");
    }

    List<dynamic> filtered = apiRequests.where((req) {
      DateTime created = DateTime.parse(req["createdAt"]);
      return (created.isAfter(start) || created.isAtSameMomentAs(start)) &&
          (created.isBefore(end) || created.isAtSameMomentAs(end));
    }).toList();

    if (selectedRange == "Daily") {
      generateDailyFrom(filtered);
    } else if (selectedRange == "Weekly") {
      generateWeeklyFrom(filtered);
    } else {
      generateMonthlyFrom(filtered);
    }

    setState(() {});
    _controller.forward(from: 0);
  }

  void generateDailyFrom(List<dynamic> filtered) {
    dailyLabels.clear();
    dailyValues.clear();

    List<DateTime> last7days =
    List.generate(7, (i) => DateTime.now().subtract(Duration(days: i))).reversed.toList();

    for (var day in last7days) {
      String label = DateFormat("dd MMM").format(day);
      int count = filtered.where((req) {
        DateTime d = DateTime.parse(req["createdAt"]);
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
      dailyLabels.add(label);
      dailyValues.add(count.toDouble());
    }
  }

  void generateWeeklyFrom(List<dynamic> filtered) {
    weeklyLabels.clear();
    weeklyValues.clear();
    DateTime now = DateTime.now();
    DateTime currentWeekStart = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 6; i++) {
      DateTime weekStart = currentWeekStart.subtract(Duration(days: 7 * i));
      DateTime weekEnd = weekStart.add(const Duration(days: 6));
      String label =
          "${DateFormat('MMM d').format(weekStart)}-${DateFormat('d').format(weekEnd)}";
      weeklyLabels.insert(0, label);
      int count = filtered.where((req) {
        DateTime d = DateTime.parse(req["createdAt"]);
        return (d.isAfter(weekStart) || d.isAtSameMomentAs(weekStart)) &&
            (d.isBefore(weekEnd) || d.isAtSameMomentAs(weekEnd));
      }).length;
      weeklyValues.insert(0, count.toDouble());
    }
  }

  void generateMonthlyFrom(List<dynamic> filtered) {
    monthlyLabels.clear();
    monthlyValues.clear();
    DateTime now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      DateTime monthDate = DateTime(now.year, now.month - i, 1);
      String label = DateFormat("MMM").format(monthDate);
      monthlyLabels.add(label);
      int count = filtered.where((req) {
        DateTime d = DateTime.parse(req["createdAt"]);
        return d.year == monthDate.year && d.month == monthDate.month;
      }).length;
      monthlyValues.add(count.toDouble());
    }
  }

  // ----------------- PROFILE VIEWS generators (new) -----------------
  void generateProfileDaily() {
    pvDailyLabels.clear();
    pvDailyValues.clear();

    List<DateTime> last7days =
    List.generate(7, (i) => DateTime.now().subtract(Duration(days: i))).reversed.toList();

    for (var day in last7days) {
      String label = DateFormat("dd MMM").format(day);
      int count = profileViews.where((v) {
        DateTime d = DateTime.parse(v["addedAt"]);
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
      pvDailyLabels.add(label);
      pvDailyValues.add(count.toDouble());
    }

    print("👁 PROFILE DAILY LABELS → $pvDailyLabels");
    print("👁 PROFILE DAILY VALUES → $pvDailyValues");
  }

  void generateProfileWeekly() {
    pvWeeklyLabels.clear();
    pvWeeklyValues.clear();

    DateTime now = DateTime.now();
    DateTime currentWeekStart = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 6; i++) {
      DateTime weekStart = currentWeekStart.subtract(Duration(days: 7 * i));
      DateTime weekEnd = weekStart.add(const Duration(days: 6));

      String label =
          "${DateFormat('MMM d').format(weekStart)}-${DateFormat('d').format(weekEnd)}";
      pvWeeklyLabels.insert(0, label);

      int count = profileViews.where((v) {
        DateTime d = DateTime.parse(v["addedAt"]);
        return (d.isAfter(weekStart) || d.isAtSameMomentAs(weekStart)) &&
            (d.isBefore(weekEnd) || d.isAtSameMomentAs(weekEnd));
      }).length;

      pvWeeklyValues.insert(0, count.toDouble());
    }

    print("👁 PROFILE WEEKLY LABELS → $pvWeeklyLabels");
    print("👁 PROFILE WEEKLY VALUES → $pvWeeklyValues");
  }

  void generateProfileMonthly() {
    pvMonthlyLabels.clear();
    pvMonthlyValues.clear();

    DateTime now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      DateTime monthDate = DateTime(now.year, now.month - i, 1);
      String label = DateFormat("MMM").format(monthDate);
      pvMonthlyLabels.add(label);

      int count = profileViews.where((v) {
        DateTime d = DateTime.parse(v["addedAt"]);
        return d.year == monthDate.year && d.month == monthDate.month;
      }).length;

      pvMonthlyValues.add(count.toDouble());
    }

    print("👁 PROFILE MONTHLY LABELS → $pvMonthlyLabels");
    print("👁 PROFILE MONTHLY VALUES → $pvMonthlyValues");
  }

  // Profile views filter (works similarly if you want a bottom-sheet filter later)
  void filterProfileViewsByType(String type) {
    // placeholder in case you want separate leadTypes for profile views later
    // currently we don't use this, but left here for parity/extension
    if (type == "This Week") {
      pvSelectedRange = "Weekly";
    } else if (type == "This Month") {
      pvSelectedRange = "Monthly";
    }
    setState(() {});
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistics"),
        backgroundColor: const Color(0xFF00509D),
        foregroundColor: Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
              .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Leads (unchanged UI) ----------
                  _sectionHeader("Leads"),
                  const SizedBox(height: 10),
                  _leadTypeDropdown(),
                  const SizedBox(height: 10),
                  _rangeSelectorForLeads(),
                  const SizedBox(height: 10),
                  _animatedChartForLeads(),

                  const SizedBox(height: 30),

                  // ---------- Profile Views (new section) ----------
                  _sectionHeader("Impressions"),
                  const SizedBox(height: 10),
                  _rangeSelectorForProfileViews(),
                  const SizedBox(height: 10),
                  _animatedChartForProfileViews(),

                  const SizedBox(height: 30),

                  _sectionHeader("Profile Views"),
                  const SizedBox(height: 10),
                  _rangeSelectorForProfileViews2(),
                  const SizedBox(height: 10),
                  _animatedChartForProfileViews2(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  // ---------- Leads widgets (unchanged look/behaviour) ----------
  Widget _leadTypeDropdown() => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      GestureDetector(
        onTap: _openLeadTypePopup,
        child: Row(
          children: const [
            Text("Lead Type",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  color: const Color(0xFF00509D), // WedMeGood blue
                )),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFF00BCD4)),

          ],
        ),
      )
    ],
  );

  Widget _rangeSelectorForLeads() {
    return Row(
      children: ranges.map((range) {
        bool isSelected = selectedRange == range;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedRange = range;
                if (selectedRange == "Daily") generateDaily();
                else if (selectedRange == "Weekly") generateWeekly();
                else generateMonthly();
                _controller.forward(from: 0);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF4682B4) : Colors.white, // changed from sky blue to steel azure
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.pinkAccent.withOpacity(0.3), blurRadius: 6)]
                    : [],
              ),

              child: Center(
                child: Text(
                  range.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _animatedChartForLeads() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                .animate(anim),
            child: child,
          )),
      child: _chartContainer(xLabels, yValues, key: ValueKey("leads_$selectedRange")),
    );
  }

  // ---------- Profile Views (New third section) ----------
  Widget _rangeSelectorForProfileViews2() {
    return Row(
      children: ranges.map((range) {
        bool isSelected = pvSelectedRange == range; // reuse same variable (since static data)
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                pvSelectedRange = range;
                _controller.forward(from: 0);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF4682B4) : Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.pinkAccent.withOpacity(0.3), blurRadius: 6)]
                    : [],
              ),

              child: Center(
                child: Text(
                  range.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _animatedChartForProfileViews2() {
    List<String> labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    List<double> values = List.generate(labels.length, (_) => profileViewsTotal.toDouble());

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                .animate(anim),
            child: child,
          )),
      child: _chartContainer(labels, values, key: const ValueKey("profileViews")),
    );
  }

  // ---------- Profile Views widgets (new, independent) ----------
  Widget _rangeSelectorForProfileViews() {
    return Row(
      children: ranges.map((range) {
        bool isSelected = pvSelectedRange == range;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                pvSelectedRange = range;
                if (pvSelectedRange == "Daily") generateProfileDaily();
                else if (pvSelectedRange == "Weekly") generateProfileWeekly();
                else generateProfileMonthly();
                _controller.forward(from: 0);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF4682B4)  : Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.pinkAccent.withOpacity(0.3), blurRadius: 6)]
                    : [],
              ),

              child: Center(
                child: Text(
                  range.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _animatedChartForProfileViews() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                .animate(anim),
            child: child,
          )),
      child: _chartContainer(pvXLabels, pvYValues, key: ValueKey("pv_$pvSelectedRange")),
    );
  }

  // Generic chart container reused for both sections
  Widget _chartContainer(List<String> labels, List<double> values, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            maxY: (values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 0) + 5,
            minY: 0,
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                curveSmoothness: 0.25,
                spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
                color: const Color(0xFF4682B4),

              dotData: FlDotData(show: true),
                barWidth: 2.5,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF4682B4).withOpacity(0.35), // top, slightly stronger
                      Color(0xFF4682B4).withOpacity(0.05), // bottom, very faint
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),


                ),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 && index < labels.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Transform.rotate(
                          angle: -0.7,
                          child: Text(labels[index], style: const TextStyle(fontSize: 11)),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, horizontalInterval: 5, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.8)),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final label = (idx >= 0 && idx < labels.length) ? labels[idx] : "";
                  return LineTooltipItem("$label\n${spot.y.toInt()}",
                      const TextStyle(color: Colors.black, fontWeight: FontWeight.bold));
                }).toList();
              }),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Lead type bottom sheet (unchanged) ----------
  void _openLeadTypePopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Select Lead Type", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          filterDataByLeadType();
                        },
                        child: const Text("OK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF00BCD4),
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: leadTypes.length,
                      itemBuilder: (context, index) {
                        String type = leadTypes[index];
                        bool isSelected = selectedLeadTypes.contains(type);
                        return CheckboxListTile(
                          activeColor: const Color(0xFF00BCD4),

                          controlAffinity: ListTileControlAffinity.leading,
                          value: isSelected,
                          title: Text(type),
                          onChanged: (bool? val) {
                            setStateSheet(() {
                              selectedLeadTypes.clear();
                              if (val == true) selectedLeadTypes.add(type);
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
