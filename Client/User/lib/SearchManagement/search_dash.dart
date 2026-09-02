import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skybridge02/SearchManagement/search_card.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'search_item_card.dart';
import 'search_trip_card.dart';

class SearchDash extends StatefulWidget {
  const SearchDash({super.key});

  @override
  State<SearchDash> createState() => _SearchDashState();
}

class _SearchDashState extends State<SearchDash> {
  final fromCountryController = TextEditingController();
  final toCountryController = TextEditingController();
  final fromCityController = TextEditingController();
  final toCityController = TextEditingController();
  final weightController = TextEditingController();
  final dateController = TextEditingController();
  DateTime? selectedDate;

  bool loading = false;
  List<dynamic> results = [];
  String activeTab = "Shipments";

  @override
  void initState() {
    super.initState();
    loadDefaultData();
  }

  void onTabChange(String tab) {
    setState(() {
      activeTab = tab;
    });

    loadDefaultData();
  }

  String capitalizeFirst(String value) {
    if (value.trim().isEmpty) return value;

    return value
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;

        dateController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> loadDefaultData() async {
    setState(() => loading = true);

    try {
      final data = await ApiService.post("/listSearchData", {
        "type": activeTab == "Trips" ? "trips" : "shipments",
      });

      setState(() {
        results = data['data'];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Load failed: $e")),
      );
    }
  }

  Future<void> handleSearch() async {
    final params = {
      "type": activeTab == "Trips" ? "trips" : "shipments",
      "fromCountry": capitalizeFirst(fromCountryController.text),
      "fromCity": capitalizeFirst(fromCityController.text),
      "toCountry": capitalizeFirst(toCountryController.text),
      "toCity": capitalizeFirst(toCityController.text),
      "weight": weightController.text,
      "date":
          dateController.text.isEmpty ? null : selectedDate?.toIso8601String(),
    };

    setState(() => loading = true);

    try {
      final data = await ApiService.post("/searchData", params);
      if (!mounted) return;
      setState(() {
        results = data['data'];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dashboardAppBar(
        title: "Search ",
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          child: IconButton(
            iconSize: 20,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(233, 233, 233, 233),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            infoCard([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchCard(
                    fromCountry: fromCountryController,
                    toCountry: toCountryController,
                    fromCity: fromCityController,
                    toCity: toCityController,
                    weightController: weightController,
                    dateController: dateController,
                    allowCityWithoutCountry: true,
                    onSearch: handleSearch,
                    onDateTap: selectDate,
                    activeTab: activeTab,
                    onTabChange: onTabChange,
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            if (!loading)
              Expanded(
                child: results.isEmpty
                    ? emptyState(
                        icon: Icons.search_off,
                        title: "No Results Found",
                        subtitle: "Try changing your search filters",
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item =
                              Map<String, dynamic>.from(results[index]);

                          return activeTab == "Trips"
                              ? TripCard(trip: item)
                              : ItemCard(item: item);
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
