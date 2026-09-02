import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skybridge02/Buyer/offer_card.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';

class RequestDashboard extends StatefulWidget {
  const RequestDashboard({super.key});

  @override
  State<RequestDashboard> createState() => _RequestDashboardState();
}

class _RequestDashboardState extends State<RequestDashboard> {
  final Map<String, bool> actionLoading = {};
  bool loading = true;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchRequests();

    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => fetchRequests(showLoader: false),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> requests = [];

  // @override
  // void initState() {
  //   super.initState();
  //   fetchOffers();
  // }

  Future<void> fetchRequests({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    try {
      final res =
          await ApiService.get("/listDataWithDetails?collection=offers&role=traveler&status=all");

      final List data = res["data"] ?? [];

      requests = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("❌ fetchRequests error: $e");
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color.fromARGB(255, 237, 233, 233),
        appBar: dashboardAppBar(
          title: "Offers",
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : requests.isEmpty
                ? emptyState(
                    icon: Icons.pending_actions_outlined,
                    title: "No Offers",
                    subtitle: "Your offers will appear here",
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 120),
                    itemCount: requests.length,
                    itemBuilder: (_, i) => Offercard(
                      offer: requests[i],
                      showActions: false,
                    ),
                  ));
  }
}
