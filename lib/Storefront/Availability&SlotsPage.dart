import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_services/api_service_vendor.dart';

class SlotsPage extends StatefulWidget {
  const SlotsPage({super.key});

  @override
  State<SlotsPage> createState() => _SlotsPageState();
}

class _SlotsPageState extends State<SlotsPage> {
  DateTime _focusedDay = DateTime.now();
  late DateTime _firstDay;
  late DateTime _lastDay;

  Set<DateTime> availableDays = {};
  bool loading = true;
  bool saving = false;

  int? vendorId;
  int? serviceId;
  int? vendorSubcategoryId;
  String? token;
  final VendorServiceApi _vendorApi = VendorServiceApi();


  @override
  void initState() {
    super.initState();
    _firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    _lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    _loadCredentialsAndData();
  }

  // Normalize date to remove time
  DateTime _normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Load cached data first, then fetch from API
  Future<void> _loadCredentialsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId');
    token = prefs.getString('token');
    serviceId = prefs.getInt('serviceId');
    vendorSubcategoryId = prefs.getInt('vendor_subcategory_id');

    // Load local cached slots first
    final local = prefs.getString('slotsData');
    if (local != null) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(local);
        final List<dynamic> available = parsed['availableDays'] ?? [];
        setState(() {
          availableDays =
              available.map((e) => _normalize(DateTime.parse(e))).toSet();
        });
      } catch (_) {}
    }

    setState(() => loading = false);

    // Fetch from GET API in background
    if (vendorId != null && token != null) {
      await fetchVendorSlots();
    }
  }

  /// Fetch slots from API and merge with local data

  Future<void> fetchVendorSlots() async {
    if (vendorId == null || token == null) return;

    try {
      final data = await _vendorApi.getByVendorId(
        vendorId: vendorId!,
        token: token!,
      );

      if (data == null) return;

      serviceId = data["id"];
      vendorSubcategoryId ??= data["vendor_subcategory_id"];

      final List<dynamic> apiSlots =
          data["attributes"]?["available_slots"] ?? [];

      setState(() {
        availableDays = {
          ...availableDays,
          ...apiSlots.map((d) => _normalize(DateTime.parse(d))),
        };
      });

      await _saveLocally();
    } catch (e) {
      debugPrint("❌ Fetch slots error: $e");
    }
  }

  Set<DateTime> _generateTotalMonthDays() =>
      {for (int i = 1; i <= _lastDay.day; i++) DateTime(_focusedDay.year, _focusedDay.month, i)};

  Set<DateTime> _getUnavailableDays() =>
      _generateTotalMonthDays().difference(availableDays);

  /// Save locally in SharedPreferences
  Future<void> _saveLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      "availableDays": availableDays.map((d) => d.toIso8601String()).toList(),
    };
    await prefs.setString('slotsData', jsonEncode(data));
  }

  /// Save to server via PUT API
  Future<void> _saveToServer() async {
    if (vendorId == null || token == null || serviceId == null) return;

    setState(() => saving = true);

    // 🔥 Fetch latest attributes (SAFETY)
    final latest = await _vendorApi.getByServiceId(
      serviceId: serviceId!,
      token: token!,
    );

    Map<String, dynamic> attributes =
    Map<String, dynamic>.from(latest?["attributes"] ?? {});

    // ✅ update ONLY slots
    attributes["available_slots"] = availableDays
        .map((d) => d.toIso8601String().split('T')[0])
        .toList();

    final body = {
      "vendor_id": vendorId,
      "vendor_subcategory_id": vendorSubcategoryId,
      "attributes": attributes,
    };

    await _saveLocally(); // local cache first

    final success = await _vendorApi.updateService(
      serviceId: serviceId!,
      token: token!,
      body: body,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Slots saved successfully.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save slots")),
      );
    }

    setState(() => saving = false);
  }


  Widget _summaryChip(IconData icon, int count, Color color) {
    return Chip(
      label: Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      avatar: Icon(icon, color: color, size: 18),
      backgroundColor: color.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unavailableDays = _getUnavailableDays();

    return Scaffold(
      backgroundColor: const Color(0xffF2F2F2),
      appBar: AppBar(
        title: const Text("Availability & Slots", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0072BB),
        foregroundColor: Colors.white,


        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryChip(Icons.check, availableDays.length, Colors.green),
                _summaryChip(Icons.close, unavailableDays.length, Colors.red),
                _summaryChip(Icons.calendar_today, _generateTotalMonthDays().length, Colors.blue),
              ],
            ),
            const SizedBox(height: 20),
            TableCalendar(
              firstDay: _firstDay,
              lastDay: _lastDay,
              focusedDay: _focusedDay,
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withOpacity(0.3),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8),
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                defaultDecoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8),
                ),
                weekendDecoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.withOpacity(0.1),
                ),
              ),
              selectedDayPredicate: (day) => availableDays.contains(_normalize(day)),
              onDaySelected: (selectedDay, focusedDay) {
                final normalized = _normalize(selectedDay);
                setState(() {
                  _focusedDay = focusedDay;
                  if (availableDays.contains(normalized)) {
                    availableDays.remove(normalized);
                  } else {
                    availableDays.add(normalized);
                  }
                });
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _saveToServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00509D),
                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text("Save Availability Details", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
