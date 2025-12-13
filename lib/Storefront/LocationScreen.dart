import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final TextEditingController addressController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();

  LatLng selectedLocation = LatLng(20.5937, 78.9629);

  List<String> countries = [];
  String? selectedCountry;

  List<String> citySuggestions = [];
  String? selectedCity;

  bool loadingCountries = true;
  bool loadingCities = false;
  bool loadingVendorData = true;
  bool savingLocation = false;

  final MapController _mapController = MapController();

  int? vendorId;
  int? vendorSubcategoryId;
  int? serviceId;
  String? token;

  Map<String, dynamic> currentAttributes = {}; // Store existing attributes

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    fetchCountries();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    vendorId = prefs.getInt('vendorId');
    vendorSubcategoryId = prefs.getInt('vendor_subcategory_id');
    serviceId = prefs.getInt('serviceId');
    token = prefs.getString('token');

    addressController.text = prefs.getString('address') ?? '';
    stateController.text = prefs.getString('state') ?? '';
    pincodeController.text = prefs.getString('zip') ?? '';
    landmarkController.text = prefs.getString('landmark') ?? '';
    latitudeController.text = prefs.getString('latitude') ?? '';
    longitudeController.text = prefs.getString('longitude') ?? '';

    selectedCountry = prefs.getString('country') ?? 'India';
    selectedCity = prefs.getString('city') ?? '';

    if (latitudeController.text.isNotEmpty && longitudeController.text.isNotEmpty) {
      final lat = double.tryParse(latitudeController.text);
      final lng = double.tryParse(longitudeController.text);
      if (lat != null && lng != null) selectedLocation = LatLng(lat, lng);
    }

    print("🔹 Loaded credentials:");
    print("vendorId: $vendorId, vendorSubcategoryId: $vendorSubcategoryId, serviceId: $serviceId");
    print("token: $token");
    print("Address: ${addressController.text}");
    print("City: $selectedCity, Country: $selectedCountry");
    print("State: ${stateController.text}, Pincode: ${pincodeController.text}");
    print("Latitude: ${latitudeController.text}, Longitude: ${longitudeController.text}");

    if (serviceId != null && token != null) {
      await fetchCurrentAttributes();
    }

    setState(() => loadingVendorData = false);
  }

  Future<void> fetchCurrentAttributes() async {
    print("📩 Fetching existing vendor-service attributes...");
    try {
      final response = await http.get(
        Uri.parse('https://happywedz.com/api/vendor-services/$serviceId'),
        headers: {"Authorization": "Bearer $token"},
      );

      print("📬 GET Response: ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        currentAttributes = Map<String, dynamic>.from(parsed["attributes"] ?? {});
        print("✅ Loaded current attributes: $currentAttributes");
      } else {
        print("❌ Failed to fetch existing attributes");
      }
    } catch (e) {
      print("❌ Error fetching current attributes: $e");
    }
  }

  Future<void> fetchCountries() async {
    setState(() => loadingCountries = true);
    print("🌍 Fetching countries...");
    try {
      final response = await http.get(Uri.parse('https://restcountries.com/v3.1/all?fields=name'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        countries = data.map((c) => c['name']['common'] as String).toList();
        countries.sort();
        print("✅ Countries loaded: ${countries.length}");
        setState(() => loadingCountries = false);
        if (selectedCountry != null) fetchCities(selectedCountry!);
      } else {
        print("❌ Failed to fetch countries: ${response.statusCode}");
        setState(() => loadingCountries = false);
      }
    } catch (e) {
      print("❌ Error fetching countries: $e");
      setState(() => loadingCountries = false);
    }
  }

  Future<void> fetchCities(String country) async {
    setState(() => loadingCities = true);
    print("🌆 Fetching cities for country: $country...");
    try {
      final response = await http.get(Uri.parse('https://countriesnow.space/api/v0.1/countries'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == false && data['data'] != null) {
          final countryData = (data['data'] as List)
              .firstWhere((c) => c['country'] == country, orElse: () => null);
          if (countryData != null && countryData['cities'] != null) {
            final cities = List<String>.from(countryData['cities']);
            setState(() {
              citySuggestions = cities;
              if (selectedCity == null || !citySuggestions.contains(selectedCity)) {
                selectedCity = citySuggestions.isNotEmpty ? citySuggestions.first : null;
              }
            });
            print("✅ Cities loaded: ${citySuggestions.length}, selected: $selectedCity");
          } else {
            setState(() {
              citySuggestions = [];
              selectedCity = null;
            });
            print("⚠ No cities found for country: $country");
          }
        }
      } else {
        setState(() {
          citySuggestions = [];
          selectedCity = null;
        });
        print("❌ Failed to fetch cities: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        citySuggestions = [];
        selectedCity = null;
      });
      print("❌ Error fetching cities: $e");
    } finally {
      setState(() => loadingCities = false);
    }
  }

  Future<void> saveLocation() async {
    if (savingLocation) return;

    print("📤 Saving location...");
    if (vendorId == null || vendorSubcategoryId == null || serviceId == null || token == null) {
      print("❌ Missing vendor/service info.");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Missing vendor/service info. Complete Basic Info first.")));
      return;
    }

    if (addressController.text.isEmpty ||
        selectedCity == null ||
        stateController.text.isEmpty ||
        pincodeController.text.isEmpty ||
        selectedCountry == null) {
      print("❌ Missing required fields.");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    setState(() => savingLocation = true);

    // Merge location fields into current attributes
    currentAttributes["address"] = addressController.text.trim();
    currentAttributes["city"] = selectedCity;
    currentAttributes["state"] = stateController.text.trim();
    currentAttributes["country"] = selectedCountry;
    currentAttributes["pincode"] = pincodeController.text.trim();
    currentAttributes["landmark"] = landmarkController.text.trim();
    currentAttributes["latitude"] = latitudeController.text.trim();
    currentAttributes["longitude"] = longitudeController.text.trim();

    final requestBody = {
      "vendor_id": vendorId,
      "vendor_subcategory_id": vendorSubcategoryId,
      "attributes": currentAttributes,
    };

    print("📦 Request Body: $requestBody");

    try {
      final url = 'https://happywedz.com/api/vendor-services/$serviceId';
      final response = await http.put(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(requestBody),
      );

      print("📥 Response Status: ${response.statusCode}");
      print("📜 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('address', addressController.text.trim());
        await prefs.setString('city', selectedCity ?? '');
        await prefs.setString('state', stateController.text.trim());
        await prefs.setString('zip', pincodeController.text.trim());
        await prefs.setString('landmark', landmarkController.text.trim());
        await prefs.setString('latitude', latitudeController.text.trim());
        await prefs.setString('longitude', longitudeController.text.trim());
        await prefs.setString('country', selectedCountry ?? 'India');

        print("✅ Location saved successfully.");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Location saved successfully")));
      } else {
        print("❌ Failed to save location: ${response.body}");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to save location")));
      }
    } catch (e) {
      print("❌ Error saving location: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving location")));
    }

    setState(() => savingLocation = false);
  }

  Widget field(String label, TextEditingController controller,
      {bool required = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (required ? " *" : ""), style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget dropdownField(String label, String? value, List<String> items, Function(String?) onChanged,
      {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (required ? " *" : ""), style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 5),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: DropdownButtonFormField<String>(
            value: items.contains(value) ? value : null,
            isExpanded: true,
            items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(border: InputBorder.none),
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }

  Widget cityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("City *", style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 5),
        GestureDetector(
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              builder: (context) {
                TextEditingController searchController = TextEditingController();
                List<String> filteredCities = List.from(citySuggestions);

                return StatefulBuilder(builder: (context, setModalState) {
                  return Container(
                    padding: EdgeInsets.all(16),
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Column(
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: "Search city",
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              filteredCities = citySuggestions
                                  .where((c) => c.toLowerCase().contains(val.toLowerCase()))
                                  .toList();
                            });
                          },
                        ),
                        SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredCities.length,
                            itemBuilder: (context, index) {
                              final city = filteredCities[index];
                              return ListTile(
                                title: Text(city),
                                onTap: () {
                                  Navigator.pop(context, city);
                                },
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  );
                });
              },
            );

            if (selected != null) {
              setState(() {
                selectedCity = selected;
                print("📌 City selected: $selectedCity");
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedCity ?? "Select City"),
                Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF2F2F2),
      appBar: AppBar(
        title: Text("Location & Service Areas", style: TextStyle(color: Colors.white)),
        backgroundColor:  const Color(0xFF0072BB),
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: loadingVendorData
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            field("Address", addressController, required: true),
            loadingCountries
                ? CircularProgressIndicator()
                : dropdownField("Country", selectedCountry, countries, (val) {
              setState(() {
                selectedCountry = val;
                print("📌 Country selected: $val");
                fetchCities(val!);
              });
            }, required: true),
            loadingCities ? CircularProgressIndicator() : cityPicker(),
            field("State", stateController, required: true),
            field("Pincode", pincodeController, required: true, keyboardType: TextInputType.number),
            field("Landmark", landmarkController),
            field("Latitude", latitudeController, keyboardType: TextInputType.number),
            field("Longitude", longitudeController, keyboardType: TextInputType.number),
            SizedBox(height: 10),
            Text("Pick on Map", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              height: 250,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: selectedLocation,
                  initialZoom: 5,
                  onTap: (tapPosition, point) {
                    setState(() {
                      selectedLocation = point;
                      latitudeController.text = point.latitude.toString();
                      longitudeController.text = point.longitude.toString();
                      print("📍 Map tapped at: ${point.latitude}, ${point.longitude}");
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.happywedz.vendor',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selectedLocation,
                        width: 45,
                        height: 45,
                        child: Icon(Icons.location_pin, color: Colors.red, size: 45),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: savingLocation ? null : saveLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00509D),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: savingLocation
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Save Location Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
