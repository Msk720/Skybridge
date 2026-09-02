import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/Services/status.dart';
import '../Services/DashBoardHelper/api_service.dart';
import 'delivery_qr_dialog.dart';
import 'order_card.dart';
import 'qr_scanner_screen.dart';
import 'rate_traveler_screen.dart';

class Orderdashboard extends StatefulWidget {
  final String? role;

  const Orderdashboard({super.key, this.role});

  @override
  State<Orderdashboard> createState() => _OrderdashboardState();
}

class _OrderdashboardState extends State<Orderdashboard> {
  late String role;
  String _selectedTab = 'Placed';
  bool loading = true;
  bool updating = false;
  bool checkingRatingPrompt = false;
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _orders = [];
  final Set<String> _promptedRatingOrderIds = {};

  static const List<String> _orderTabs = [
    'Placed',
    'InTransit',
    'Received',
    'Inactive',
  ];

  @override
  void initState() {
    super.initState();
    role = widget.role ?? 'buyer';
    fetchOrders();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => fetchOrders(showLoader: false),
    );
  }

  @override
  void didUpdateWidget(covariant Orderdashboard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.role != widget.role && widget.role != null) {
      role = widget.role!;
      fetchOrders();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged(String tab) {
    setState(() => _selectedTab = tab);
    fetchOrders();
  }

  Future<void> fetchOrders({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    try {
      final encodedStatus = Uri.encodeComponent(_selectedTab);
      final encodedRole = Uri.encodeComponent(role);
      final res = await ApiService.get(
        "/listDataWithDetails?collection=orders&status=$encodedStatus&role=$encodedRole",
      );

      final List data = res["data"] ?? [];

      _orders = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("❌ fetchOrders error: $e");
    }

    if (mounted) {
      setState(() => loading = false);
      _promptForPendingRating();
    }
  }

  void _applyOrderStatusLocally(String orderId, String status) {
    if (!mounted) return;

    setState(() {
      final index = _orders.indexWhere(
        (order) => order['id']?.toString() == orderId,
      );

      if (index == -1) return;

      _orders[index] = {
        ..._orders[index],
        'status': status,
      };

      if (status != _selectedTab) {
        _orders.removeWhere(
          (order) => order['id']?.toString() == orderId,
        );
      }
    });
  }

  Future<void> _promptForPendingRating() async {
    if (role != 'buyer' || checkingRatingPrompt) return;

    checkingRatingPrompt = true;

    try {
      List<Map<String, dynamic>> receivedOrders =
          _selectedTab == 'Received' ? _orders : [];

      if (_selectedTab != 'Received') {
        final res = await ApiService.get(
          '/listDataWithDetails?collection=orders&status=Received&role=buyer&limit=20',
        );
        final List data = res['data'] ?? [];
        receivedOrders = List<Map<String, dynamic>>.from(data);
      }

      Map<String, dynamic>? orderToRate;

      for (final order in receivedOrders) {
        final id = order['id']?.toString() ?? '';
        final status = order['status']?.toString() ?? '';
        final ratingStatus = order['buyerRatingStatus']?.toString() ?? '';
        final needsRating = id.isNotEmpty &&
            status == 'Received' &&
            !_promptedRatingOrderIds.contains(id) &&
            ratingStatus != 'rated' &&
            ratingStatus != 'noRating' &&
            order['buyerRatingSubmitted'] != true &&
            order['buyerRatingSkipped'] != true;

        if (needsRating) {
          orderToRate = order;
          break;
        }
      }

      if (orderToRate == null) return;

      final orderId = orderToRate['id']?.toString();
      if (orderId == null || orderId.isEmpty) return;

      _promptedRatingOrderIds.add(orderId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _rateTraveler(orderToRate!);
        }
      });
    } catch (e) {
      debugPrint('Rating prompt check error: $e');
    } finally {
      checkingRatingPrompt = false;
    }
  }

  Future<void> _updateOrderStatus(
    Map<String, dynamic> order,
    String status,
  ) async {
    final currentStatus = order['status']?.toString() ?? '';

    if (currentStatus != 'Placed' || status != 'InTransit') {
      return;
    }

    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty) return;

    setState(() => updating = true);

    try {
      await updateEntityStatus(
        collection: 'orders',
        id: orderId,
        status: status,
      );

      _applyOrderStatusLocally(orderId, status);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order moved to InTransit')),
      );

      await fetchOrders(showLoader: false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update order status')),
      );
    }

    if (mounted) {
      setState(() => updating = false);
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final currentStatus = order['status']?.toString() ?? '';

    if (currentStatus != 'Placed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cannot be cancelled after delivery has started'),
        ),
      );
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Your payment will be refunded to the original payment method used at checkout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    final orderId = order['id']?.toString();
    if (orderId == null || orderId.isEmpty) return;

    setState(() => updating = true);

    try {
      await updateEntityStatus(
        collection: 'orders',
        id: orderId,
        status: 'Inactive',
      );

      _applyOrderStatusLocally(orderId, 'Inactive');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Order cancelled. Refund will return to the original payment method.'),
        ),
      );

      await fetchOrders(showLoader: false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to cancel order')),
      );
    }

    if (mounted) {
      setState(() => updating = false);
    }
  }

  Future<void> _showDeliveryQr(Map<String, dynamic> order) async {
    final currentStatus = order['status']?.toString() ?? '';

    if (currentStatus != 'InTransit') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery QR is available only after order pickup'),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => DeliveryQrDialog(order: order),
    );
  }

  Future<void> _scanDeliveryQr(Map<String, dynamic> order) async {
    final currentStatus = order['status']?.toString() ?? '';

    if (currentStatus != 'InTransit') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR scan is available only for in-transit orders'),
        ),
      );
      return;
    }

    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(order: order),
      ),
    );

    if (verified == true) {
      final orderId = order['id']?.toString();
      if (orderId != null && orderId.isNotEmpty) {
        _applyOrderStatusLocally(orderId, 'Received');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Order received. Payment will release after 24 hours if no dispute is filed.'),
        ),
      );

      await fetchOrders(showLoader: false);
    }
  }

  Future<void> _rateTraveler(Map<String, dynamic> order) async {
    final rated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RateTravelerScreen(order: order),
      ),
    );

    if (rated == true) {
      await fetchOrders(showLoader: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color.fromARGB(255, 237, 233, 233),
        appBar: dashboardAppBar(
          title: "Orders",
          tabs: _orderTabs,
          selectedTab: _selectedTab,
          onTabChanged: _onTabChanged,
        ),
        body: SafeArea(
          child: Column(
            children: [
              /// TABS CONTAINER
              const SizedBox(height: 12),

              /// CONTENT
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : _orders.isEmpty
                        ? emptyState(
                            icon: Symbols.package_2,
                            title: "No Orders Yet",
                            subtitle:
                                "Your ${_selectedTab.toLowerCase()} orders will appear here",
                          )
                        : Stack(
                            children: [
                              ListView.builder(
                                padding: const EdgeInsets.only(bottom: 130),
                                itemCount: _orders.length,
                                itemBuilder: (_, i) => Ordercard(
                                  order: _orders[i],
                                  viewerRole: role,
                                  onStatusChanged: role == 'traveler'
                                      ? (status) => _updateOrderStatus(
                                            _orders[i],
                                            status,
                                          )
                                      : null,
                                  onCancelOrder: role == 'buyer'
                                      ? () => _cancelOrder(_orders[i])
                                      : null,
                                  onShowDeliveryQr: role == 'buyer'
                                      ? () => _showDeliveryQr(_orders[i])
                                      : null,
                                  onScanDeliveryQr: role == 'traveler'
                                      ? () => _scanDeliveryQr(_orders[i])
                                      : null,
                                  onRateTraveler: role == 'buyer'
                                      ? () => _rateTraveler(_orders[i])
                                      : null,
                                ),
                              ),
                              if (updating)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        ));
  }
}
