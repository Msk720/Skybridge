import 'dart:async';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/Services/custom_floating.dart';

import 'dispute_card.dart';
import 'file_dispute.dart';
import 'select_dispute_order.dart';

class DisputeDashboard extends StatefulWidget {
  final String role;

  const DisputeDashboard({
    super.key,
    this.role = 'buyer',
  });

  @override
  State<DisputeDashboard> createState() => _DisputeDashboardState();
}

class _DisputeDashboardState extends State<DisputeDashboard> {
  bool _loading = true;
  bool _openedInitialFileScreen = false;
  Timer? _refreshTimer;
  late String _currentRole;

  List<Map<String, dynamic>> _disputes = [];
  final Set<String> _cancellingIds = {};

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role.toLowerCase() == 'traveler' ? 'traveler' : 'buyer';
    _loadMyDisputes();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadMyDisputes(showLoader: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_openedInitialFileScreen) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      final argRole = args['role']?.toString().toLowerCase();
      if (argRole == 'traveler' || argRole == 'buyer') {
        _currentRole = argRole!;
      }

      final hasOrderData = args.containsKey('_id') ||
          args.containsKey('id') ||
          args.containsKey('orderId') ||
          args.containsKey('orderNumber');

      if (hasOrderData) {
        _openedInitialFileScreen = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openFileDispute(initialOrder: args);
        });
      }
    }
  }

  Future<void> _loadMyDisputes({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final raw = await ApiService.get('/api/disputes/my');

      final dynamic list = raw is Map
          ? raw['disputes'] ?? raw['data'] ?? []
          : raw is List
              ? raw
              : [];

      final items = list is List
          ? list
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(_isVisibleForCurrentUserRole)
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _disputes = items;
      });
    } catch (e) {
      debugPrint('Load disputes error: $e');

      if (!mounted) return;

      if (showLoader) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load disputes')),
        );
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openSelectOrderScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDisputeOrderScreen(
          role: _currentRole,
        ),
      ),
    );

    if (result == true) {
      _loadMyDisputes();
    }
  }

  Future<void> _openFileDispute({Map<String, dynamic>? initialOrder}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileDisputeScreen(
          initialOrder: initialOrder,
          initialRole: _roleFromOrder(initialOrder) ?? _currentRole,
        ),
      ),
    );

    if (result == true) {
      _loadMyDisputes();
    }
  }

  String? _roleFromOrder(Map<String, dynamic>? order) {
    if (order == null) return null;

    final value = order['viewerRole'] ??
        order['role'] ??
        order['currentRole'] ??
        order['userRole'];

    final role = value?.toString().toLowerCase();

    if (role == 'traveler') return 'traveler';
    if (role == 'buyer') return 'buyer';

    return null;
  }

  String _disputeId(Map<String, dynamic> dispute) {
    return (dispute['_id'] ?? dispute['id'] ?? '').toString();
  }


  String _lower(dynamic value) => value?.toString().trim().toLowerCase() ?? '';

  String _nestedLower(Map<String, dynamic> source, String objectKey, String fieldKey) {
    final nested = source[objectKey];
    if (nested is Map) return _lower(nested[fieldKey]);
    return '';
  }

  bool _isVisibleForCurrentUserRole(Map<String, dynamic> dispute) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = _lower(user?.uid);
    final email = _lower(user?.email);

    final filedById = _nestedLower(dispute, 'filedBy', 'id');
    final filedByEmail = _nestedLower(dispute, 'filedBy', 'email');
    final userId = _lower(dispute['userId']);
    final userEmail = _lower(dispute['userEmail']);
    final legacyUserId = _nestedLower(dispute, 'user', 'id');
    final legacyUserEmail = _nestedLower(dispute, 'user', 'email');

    final filedByRole = _lower(dispute['filedByRole']);
    final viewerRole = _lower(dispute['viewerRole']);
    final userRole = _nestedLower(dispute, 'user', 'role');
    final disputeRole = filedByRole.isNotEmpty
        ? filedByRole
        : viewerRole.isNotEmpty
            ? viewerRole
            : userRole;

    final roleMatches = disputeRole.isEmpty || disputeRole == _currentRole;
    final idMatches = uid.isNotEmpty &&
        (filedById == uid || userId == uid || legacyUserId == uid);
    final emailMatches = email.isNotEmpty &&
        (filedByEmail == email || userEmail == email || legacyUserEmail == email);

    return roleMatches && (idMatches || emailMatches);
  }

  Future<void> _cancelDispute(Map<String, dynamic> dispute) async {
    final disputeId = _disputeId(dispute);

    if (disputeId.isEmpty) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Dispute'),
        content: const Text('Are you sure you want to cancel this dispute?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    setState(() => _cancellingIds.add(disputeId));

    try {
      await ApiService.post('/api/disputes/$disputeId/cancel', {
        'status': 'cancelled',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute cancelled')),
      );

      await _loadMyDisputes();
    } catch (e) {
      debugPrint('Cancel dispute error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not cancel dispute. Please update backend route.'),
        ),
      );
    }

    if (mounted) {
      setState(() => _cancellingIds.remove(disputeId));
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
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> dispute) {
    final id = _disputeId(dispute);
    final isCancelling = _cancellingIds.contains(id);

    return Stack(
      children: [
        DisputeCard(
          dispute: dispute,
          onCancel: isCancelling ? null : () => _cancelDispute(dispute),
        ),
        if (isCancelling)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: dashboardAppBar(
        title: 'Disputes',
        leading: _backButton(),
      ),

      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _disputes.isEmpty
                    ? emptyState(
                        icon: Icons.assignment_late_outlined,
                        title: 'No Dispute Yet',
                        subtitle: 'Your disputes will appear here',
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadMyDisputes(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(15, 18, 15, 90),
                          itemCount: _disputes.length,
                          itemBuilder: (_, i) {
                            return _buildDisputeCard(_disputes[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
           floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
floatingActionButton: Padding(
  padding: const EdgeInsets.only(bottom: 0), 
  child: RequestFAB(
    label: 'File Dispute',
    icon: Icons.edit_note_rounded,
    width: 154,
    onPressed: _openSelectOrderScreen,
  ),
),
    );
  }
}
