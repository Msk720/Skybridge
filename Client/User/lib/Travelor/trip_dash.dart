import 'dart:async';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skybridge02/Services/DashBoardHelper/delete_data_handler.dart';
import 'package:skybridge02/Services/DashBoardHelper/list_data_handler.dart';
import 'package:skybridge02/Services/custom_floating.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'trip_card.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';

class TripsDashboard extends StatefulWidget {
  const TripsDashboard({super.key});
  @override
  State<TripsDashboard> createState() => _TripsDashboardState();
}

class _TripsDashboardState extends State<TripsDashboard> {
  String _selectedTab = 'Active';
  bool _loading = true;
  List<Map<String, dynamic>> _trips = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadTrips(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrips({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final trips = await listData(collection: "trips");

      final filtered = trips.where((t) => t['status'] == _selectedTab).toList();

      if (!mounted) return;
      setState(() {
        _trips = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      if (showLoader) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trips: $e')),
        );
      }
    }
  }

  Future<bool> _ensureStripeConnectReadyBeforeAdd() async {
    try {
      await ApiService.post('/getStripeConnectAccountStatus', {});
      final profile = await ApiService.get('/getProfile');

      final stripeReady = profile['stripeDetailsSubmitted'] == true &&
          profile['stripePayoutsEnabled'] == true &&
          profile['stripeAccountId'] != null &&
          profile['stripeAccountId'].toString().isNotEmpty;

      if (stripeReady) return true;
    } catch (e) {
      debugPrint('Stripe Connect check error: $e');
    }

    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connect your Stripe account before adding a trip.'),
      ),
    );

    await Navigator.pushNamed(context, '/stripeConnect');

    return false;
  }

  void _onEdit(Map<String, dynamic> trip) async {
    final result = await Navigator.of(context).pushNamed(
      '/add_trip_info',
      arguments: {...trip, 'isEdit': true},
    );

    if (result == true) {
      _loadTrips();
    }
  }

  void _onDeleteTrip(Map<String, dynamic> trip) {
    handleDelete(
      context: context,
      item: trip,
      collection: "trips",
      setLoading: (val) => setState(() => _loading = val),
      onSuccessRemove: (id) {
        setState(() {
          _trips.removeWhere((t) {
            final tid = t['id'].toString();
            return tid == id;
          });
        });
      },
      title: "Delete Trip",
      message: "Delete this trip? This cannot be undone.",
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return TripCard(
      trip: trip,
      onEdit: () => _onEdit(trip),
      onDelete: () => _onDeleteTrip(trip),
      status: _selectedTab,
    );
  }

  void _onTabChanged(String tab) {
    setState(() => _selectedTab = tab);
    _loadTrips();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: "Trip",
        tabs: const ["Active", "Inactive"],
        selectedTab: _selectedTab,
        onTabChanged: _onTabChanged,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _trips.isEmpty
                      ? emptyState(
                          icon: Symbols.plane_contrails_rounded,
                          title: "No Trips Yet",
                          subtitle: "Your trip requests will appear here",
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 5, bottom: 190),
                          itemCount: _trips.length,
                          itemBuilder: (_, i) => _buildTripCard(_trips[i]),
                        ),
            ),
          ],
        ),
      ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
floatingActionButton: Padding(
  padding: const EdgeInsets.only(bottom: 30),
  child: RequestFAB(
    routeName: '/add_trip_info',
    label: 'Add Trip',
    icon: Icons.flight_takeoff_rounded,
    onReturn: () => _loadTrips(),
    beforeNavigate: _ensureStripeConnectReadyBeforeAdd,
  ),
),
    );
  }
}
