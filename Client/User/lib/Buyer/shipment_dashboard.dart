import 'dart:async';
import 'package:skybridge02/Buyer/item_card.dart';
import 'package:skybridge02/Services/DashBoardHelper/list_data_handler.dart';
import 'package:skybridge02/Services/custom_floating.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/Services/DashBoardHelper/delete_data_handler.dart';
import 'package:skybridge02/Services/app_imports.dart';

class ShipmentDashboard extends StatefulWidget {
  const ShipmentDashboard({super.key});
  @override
  State<ShipmentDashboard> createState() => _ShipmentDashboardState();
}

class _ShipmentDashboardState extends State<ShipmentDashboard> {
  String _selectedTab = 'Active';
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool status = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadFromBackend(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged(String tab) {
    setState(() => _selectedTab = tab);
    _loadFromBackend();
  }

  Future<void> _loadFromBackend({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final items = await listData(
        collection: "items",
      );

      final filtered =
          items.where((item) => item['status'] == _selectedTab).toList();

      if (!mounted) return;
      setState(() {
        _requests = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      if (showLoader) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading items: $e')),
        );
      }
    }
  }

  void _onEditRequest(Map<String, dynamic> req) async {
    final result = await Navigator.pushNamed(
      context,
      '/ShippingForm',
      arguments: {...req, 'isEdit': true},
    );

    if (result == true) {
      _loadFromBackend();
    }
  }

  void _onDeleteRequest(Map<String, dynamic> req) {
    handleDelete(
      context: context,
      item: req,
      collection: "items",
      setLoading: (val) => setState(() => _loading = val),
      onSuccessRemove: (id) {
        setState(() {
          _requests.removeWhere((r) {
            final rid = r['id']?.toString();
            return rid == id;
          });
        });
      },
      title: "Delete item",
      message: "Delete this item from server? This cannot be undone.",
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    return ItemCard(
      status: _selectedTab,
      item: req,
      onEdit: () => _onEditRequest(req),
      onDelete: () => _onDeleteRequest(req),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: "Shipments",
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
                  : _requests.isEmpty
                      ? emptyState(
                          icon: Icons.shopping_cart,
                          title: "No Item Yet",
                          subtitle: "Your item requests will appear here",
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 5, bottom: 90),
                          itemCount: _requests.length,
                          itemBuilder: (_, i) =>
                              _buildRequestCard(_requests[i]),
                        ),
            ),
          ],
        ),
      ),
     
 floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
floatingActionButton: const Padding(
  padding: EdgeInsets.only(bottom: 40), 
  child: RequestFAB(
    routeName: '/RequestOptions',
    label: 'Add Item',
    icon: Icons.add_shopping_cart_rounded,
  ),
),

    );
  }
}
