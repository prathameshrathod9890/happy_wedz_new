import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'new_screens/leaddetails_screen.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  // ✅ Shared static list to access from HomeTab
  static List<dynamic> latestLeads = [];

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _sort = 'Newest';
  String _selectedFilter = 'All Enquiries';
  bool _isLoading = true;
  List<dynamic> _leads = [];

  /// 🔥 IMPORTANT: archived IDs (persisted)
  Set<String> _archivedLeadIds = {};
  /// 🔥 opened (only UI, no need to persist)
  Set<String> _openedLeadIds = {};

  Map<String, String> _conversationMap = {};

  final List<String> _filters = [
    'All Enquiries',
    'Unread',
    'Archived',
    'Pending',
    'Booked',
    'Declined',
  ];


  @override
  void initState() {
    super.initState();
    _loadArchivedLeads();
    _loadInitialData();
   // _fetchLeads();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _fetchLeads(),
      _fetchConversations(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadArchivedLeads() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('archived_leads') ?? [];
    setState(() {
      _archivedLeadIds = saved.toSet();
    });
  }

  Future<void> _toggleArchive(String id) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      if (_archivedLeadIds.contains(id)) {
        _archivedLeadIds.remove(id);
      } else {
        _archivedLeadIds.add(id);
      }
    });

    await prefs.setStringList(
      'archived_leads',
      _archivedLeadIds.toList(),
    );
  }

  Future<void> _fetchLeads() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token') ?? prefs.getString('authToken');

      if (token == null || token.isEmpty) return;

      final res = await http.get(
        Uri.parse('https://happywedz.com/api/inbox'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token'
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _leads = data["inbox"] ?? data["data"] ?? [];
        LeadsPage.latestLeads = _leads;
      }
    } catch (e) {
      print("🔥 Leads error: $e");
    }
  }


  Future<void> _fetchConversations() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token') ?? prefs.getString('authToken');

      if (token == null) return;

      final res = await http.get(
        Uri.parse("https://happywedz.com/api/messages/vendor/conversations"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);

        for (var c in list) {
          final requestId = c['requestId']?.toString();
          final conversationId = c['id']?.toString();

          print("🟢 Found => requestId: $requestId | conversationId: $conversationId");


          if (requestId != null && conversationId != null) {
            _conversationMap[requestId] = conversationId;
          }
        }
        print("📦 Conversation Map => $_conversationMap");
      }
    } catch (e) {
      print("🔥 Conversation error: $e");
    }
  }

  List<dynamic> get _filteredLeads {
    final leads = _leads.map((l) => l['request'] ?? l).toList();

    switch (_selectedFilter) {
      case 'Unread':
        return leads
            .where((l) => !_openedLeadIds.contains((l['_id'] ?? l['id']).toString()))
            .toList();
      case 'Archived':
        return leads
            .where((l) => _archivedLeadIds.contains((l['_id'] ?? l['id']).toString()))
            .toList();
      case 'Pending':
        return leads
            .where((l) => (l['status'] ?? '').toString().toLowerCase() == 'pending')
            .toList();
      case 'Booked':
        return leads
            .where((l) => (l['status'] ?? '').toString().toLowerCase() == 'booked')
            .toList();
      case 'Declined':
        return leads
            .where((l) => (l['status'] ?? '').toString().toLowerCase() == 'declined')
            .toList();
      default:
        return leads
            .where((l) => !_archivedLeadIds.contains((l['_id'] ?? l['id']).toString()))
            .toList();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF003F88), // French Blue
                  Color(0xFF00509D), // Steel Azure
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Leads',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 10),
                _buildSearch(),
                const SizedBox(height: 10),
                SizedBox(height: 40, child: _buildFilterChips()),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchLeads,
              color: const Color(0xFFFF4D79),
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF4D79)),
              )
                  : _filteredLeads.isEmpty
                  ? const Center(
                child: Text(
                  "No leads found",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _filteredLeads.length,
                itemBuilder: (context, index) {
                  final lead = _filteredLeads[index];
                  return _buildLeadCard(lead);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(dynamic lead) {
    final name = "${lead['firstName'] ?? ''} ${lead['lastName'] ?? ''}".trim();
    final date = lead['eventDate'] ?? 'N/A';
    final status = lead['status'] ?? 'N/A';
    final msg = (lead['message'] ?? '').isEmpty ? 'No message' : lead['message'];
    final id = (lead['_id'] ?? lead['id'] ?? '').toString();

    // 🔵 BLUE THEME STATUS COLORS
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'booked':
        statusColor = const Color(0xFF003F88); // Dark Steel Blue
        break;
      case 'pending':
        statusColor = const Color(0xFF4A90E2); // Medium Blue
        break;
      case 'declined':
        statusColor = const Color(0xFF89C2D9); // Light Blue
        break;
      default:
        statusColor = const Color(0xFFBFD7ED); // Very Light Blue
    }

    return InkWell(
      onTap: () async {
        _openedLeadIds.add(id);
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead, conversationId: _conversationMap[id],)),
        );
        if (updated == true) _fetchLeads();
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Stack(
          children: [
            ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

              // 🔵 Avatar blue color
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF00509D),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),

              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.black,
                        // decoration: _archivedLeadIds.contains(id)
                        //     ? TextDecoration.lineThrough
                        //     : null,
                      ),
                    ),
                  ),
                ],
              ),

              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Event Date: $date",
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 3),
                    Text(
                      msg.length > 20 ? '${msg.substring(0, 20)}...' : msg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),

            ),

            // ⋮ Menu + Status Badge
            Positioned(
              right: 10,
              top: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      // if (value == 'archive') {
                      //   setState(() {
                      //     if (_archivedLeadIds.contains(id)) {
                      //       _archivedLeadIds.remove(id);
                      //     } else {
                      //       _archivedLeadIds.add(id);
                      //     }
                      //   });
                      // }
                      if (value == 'archive') {
                        await _toggleArchive(id); // 🔥 PERSISTENT LOGIC
                      }

                      if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Lead"),
                            content: const Text(
                                "Are you sure you want to delete this lead?"),
                            actions: [
                              TextButton(
                                child: const Text("Cancel"),
                                onPressed: () => Navigator.pop(context),
                              ),
                              TextButton(
                                child: const Text("Delete",
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () {
                                  setState(() {
                                    _leads.removeWhere((item) =>
                                    (item['_id'] ?? item['id'])
                                        .toString() ==
                                        id);
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(
                          _archivedLeadIds.contains(id)
                              ? 'Unarchive'
                              : 'Archive',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  ),

                  const SizedBox(height: 4),

                  // 🔵 BLUE STATUS BADGE
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearch() {
    return TextField(
      controller: _searchCtrl,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by name, city, event…',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: _filters.map((label) {
        final bool isSelected = _selectedFilter == label;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF00509D)  // Steel Azure text
                    : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),

            selected: isSelected,

            // Always white background
            backgroundColor: Colors.white,
            selectedColor: Colors.white,

            // Border becomes Steel Azure when selected
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF00509D)
                  : Colors.grey.shade300,
            ),

            onSelected: (_) => setState(() => _selectedFilter = label),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }).toList(),
    );
  }

}





