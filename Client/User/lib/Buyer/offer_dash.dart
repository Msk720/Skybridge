import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skybridge02/Buyer/offer_card.dart';
// import 'package:skybridge02/Services/status_update.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/Services/status.dart';

class OfferDashboard extends StatefulWidget {
  const OfferDashboard({super.key});

  @override
  State<OfferDashboard> createState() => _OfferDashboardState();
}

class _OfferDashboardState extends State<OfferDashboard> {
  final Map<String, bool> actionLoading = {};
  bool loading = true;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchOffers();

    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => fetchOffers(showLoader: false),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> offers = [];

  // @override
  // void initState() {
  //   super.initState();
  //   fetchOffers();
  // }

  // Future<void> fetchOffers() async {
  //   setState(() {
  //     loading = true;
  //   });
  //   try {
  //     final data = await listData(collection: "offers");

  //     offers = List<Map<String, dynamic>>.from(data);
  //   } catch (e) {
  //     debugPrint("❌ fetchOffers error: $e");
  //   }

  //   if (mounted) {
  //     setState(() => loading = false);
  //   }
  // }

  Future<void> fetchOffers({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    try {
      final res =
          await ApiService.get("/listDataWithDetails?collection=offers");

      final List data = res["data"] ?? [];

      offers = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("❌ fetchOffers error: $e");
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _updateOfferStatus({
    required String offerId,
    required String status,
  }) async {
    setState(() => actionLoading[offerId] = true);

    try {
      await updateEntityStatus(
        collection: 'offers',
        id: offerId,
        status: status,
      );

      if (mounted) {
        setState(() {
          final index = offers.indexWhere(
            (offer) => offer['id']?.toString() == offerId,
          );
          if (index != -1) {
            offers[index] = {
              ...offers[index],
              'status': status,
            };
            if (status == 'Rejected' || status == 'Accepted') {
              offers.removeAt(index);
            }
          }
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'Accepted' ? 'Offer accepted' : 'Offer rejected',
          ),
        ),
      );

      await fetchOffers(showLoader: false);
    } catch (e) {
      debugPrint('❌ Action failed: $e');
    } finally {
      if (mounted) {
        setState(() => actionLoading.remove(offerId));
      }
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
            : offers.isEmpty
                ? emptyState(
                    icon: Icons.local_offer_outlined,
                    title: "No Offers Yet",
                    subtitle: "Offers will appear here",
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 120),
                    itemCount: offers.length,
                    itemBuilder: (_, i) => Offercard(
                      isLoading: actionLoading[offers[i]['id']] == true,
                      offer: offers[i],
                      onAccept: (id) {
                        Navigator.pushNamed(
                          context,
                          '/payment',
                          arguments: {'offerId': id},
                        );
                      },
                      onReject: (id) {
                        _updateOfferStatus(
                          offerId: id,
                          status: 'Rejected',
                        );
                      },
                    ),
                  ));
  }
}
