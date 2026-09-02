import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/Services/section_label.dart';
import 'file_dispute.dart';

class SelectDisputeOrderScreen extends StatefulWidget {
  final String role;

  const SelectDisputeOrderScreen({
    super.key,
    this.role = 'buyer',
  });

  @override
  State<SelectDisputeOrderScreen> createState() =>
      _SelectDisputeOrderScreenState();
}

class _SelectDisputeOrderScreenState extends State<SelectDisputeOrderScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rolesToLoad = widget.role.toLowerCase() == 'traveler'
          ? ['traveler']
          : widget.role.toLowerCase() == 'buyer'
              ? ['buyer']
              : ['buyer', 'traveler'];

      final loaded = <Map<String, dynamic>>[];

      for (final role in rolesToLoad) {
        final raw = await ApiService.get(
          '/listDataWithDetails?collection=orders&role=$role&limit=100',
        );

        final dynamic list = raw is Map
            ? raw['data'] ?? raw['orders'] ?? []
            : raw is List
                ? raw
                : [];

        if (list is List) {
          for (final item in list.whereType<Map>()) {
            final order = Map<String, dynamic>.from(item);
            order['viewerRole'] = (order['viewerRole'] ?? role).toString();
            loaded.add(order);
          }
        }
      }

      final deduped = <String, Map<String, dynamic>>{};
      for (final order in loaded) {
        final key = '${_getOrderId(order)}_${_getRole(order)}';
        if (key.trim().isNotEmpty) {
          deduped[key] = order;
        }
      }

      if (!mounted) return;

      setState(() {
        _orders = deduped.values.toList();
      });
    } catch (e) {
      debugPrint('Load dispute orders error: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Could not load your orders';
      });
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _getOrderId(Map<String, dynamic> order) {
    final value =
        order['orderNumber'] ?? order['id'] ?? order['_id'] ?? order['orderId'];

    return value?.toString() ?? '';
  }

  String _getItemName(Map<String, dynamic> order) {
    final value = order['itemName'] ??
        order['productName'] ??
        order['name'] ??
        order['itemDescription'] ??
        order['title'];

    return value?.toString() ?? 'Item';
  }

  String _getRole(Map<String, dynamic> order) {
    final value = order['viewerRole'] ??
        order['role'] ??
        order['currentRole'] ??
        order['userRole'] ??
        widget.role;

    final role = value?.toString().toLowerCase() ?? 'buyer';

    if (role == 'traveler') return 'traveler';
    return 'buyer';
  }

  String _getStatus(Map<String, dynamic> order) {
    final value = order['status'] ??
        order['orderStatus'] ??
        order['deliveryStatus'] ??
        order['state'];

    return value?.toString() ?? 'Order';
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  DateTime? _parseDateField(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  bool _isDisputeWindowOpen(Map<String, dynamic> order) {
    final deadline = _parseDateField(
      order['disputeWindowEndsAt'] ?? order['paymentReleaseEligibleAt'],
    );

    if (deadline == null) return false;

    final now = DateTime.now();
    return now.isBefore(deadline) || now.isAtSameMomentAs(deadline);
  }

  bool _isUndeliveredOrder(Map<String, dynamic> order) {
    final status = _normalizeText(_getStatus(order));

    if (status.isEmpty || status == 'order') return true;

    final deliveredWords = [
      'received',
      'delivered',
      'completed',
      'complete',
      'done',
      'closed',
      'cancelled',
      'canceled',
      'returned',
      'refunded',
    ];

    if (deliveredWords.any(status.contains)) return false;

    return true;
  }

  bool _canFileDispute(Map<String, dynamic> order) {
    return _isDisputeWindowOpen(order) || _isUndeliveredOrder(order);
  }

  String _disputeWindowText(Map<String, dynamic> order) {
    final deadline = _parseDateField(
      order['disputeWindowEndsAt'] ?? order['paymentReleaseEligibleAt'],
    );

    if (deadline == null) {
      return _isUndeliveredOrder(order) ? 'No time limit' : 'Not ready';
    }

    if (!_isDisputeWindowOpen(order)) {
      return _isUndeliveredOrder(order) ? 'No time limit' : 'Time over';
    }

    final remaining = deadline.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    if (hours > 0) return '${hours}h ${minutes}m left';
    if (minutes > 0) return '${minutes}m ${seconds}s left';
    return '${seconds}s left';
  }

  String _shortOrderId(String value) {
    final clean = value.trim();
    if (clean.length <= 6) return clean;
    return clean.substring(clean.length - 6);
  }

  Future<void> _selectOrder(Map<String, dynamic> order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileDisputeScreen(
          initialOrder: order,
          initialRole: _getRole(order),
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  Widget _backButton() {
    return Container(
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
    );
  }

  Widget _emptyOrderState() {
    return emptyInfoCard(
      icon: Icons.receipt_long_outlined,
      title: 'Cannot file dispute without order',
      subtitle: 'You need to have at least one order before opening a dispute.',
    );
  }


  Widget _errorState() {
    return emptyInfoCard(
      icon: Icons.error_outline,
      title: _error ?? 'Something went wrong',
      subtitle: 'Please try again to load your orders.',
      action: SizedBox(
        width: double.infinity,
        height: 48,
        child: appPrimaryButton(
          text: 'Try Again',
          onPressed: _loadOrders,
        ),
      ),
    );
  }


  Widget _orderCard(Map<String, dynamic> order) {
    final orderId = _getOrderId(order);
    final itemName = _getItemName(order);
    final role = _getRole(order);
    final status = _getStatus(order);
    final canFileDispute = _canFileDispute(order);

    return InkWell(
      onTap: canFileDispute
          ? () => _selectOrder(order)
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dispute time is over for this order'),
                ),
              );
            },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.activeline.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderId.isEmpty ? 'Order ID' : '#${_shortOrderId(orderId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textprimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textgray,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _smallChip(
                        label: role == 'traveler' ? 'Traveler' : 'Buyer',
                        icon: role == 'traveler'
                            ? Icons.flight_takeoff_outlined
                            : Icons.shopping_bag_outlined,
                      ),
                      _smallChip(
                        label: status,
                        icon: Icons.info_outline,
                      ),
                      _smallChip(
                        label: _disputeWindowText(order),
                        icon: canFileDispute
                            ? Icons.timer_outlined
                            : Icons.lock_clock_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallChip({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 82),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 90),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) return Center(child: _errorState());

    if (_orders.isEmpty) return Center(child: _emptyOrderState());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionLabel(
          'SELECT ORDER FOR DISPUTE',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 12),
        ..._orders.map(_orderCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: dashboardAppBar(
        title: 'Select Order',
        leading: _backButton(),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(15),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 30,
                ),
                child: _body(),
              ),
            );
          },
        ),
      ),
    );
  }
}
