import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/custom_inputfield.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/Services/image_picker_uploader.dart';
import 'package:skybridge02/Services/section_label.dart';
import 'select_dispute_order.dart';

class FileDisputeScreen extends StatefulWidget {
  final Map<String, dynamic>? initialOrder;
  final String initialRole;

  const FileDisputeScreen({
    super.key,
    this.initialOrder,
    this.initialRole = 'buyer',
  });

  @override
  State<FileDisputeScreen> createState() => _FileDisputeScreenState();
}

class _FileDisputeScreenState extends State<FileDisputeScreen> {
  final TextEditingController _orderController = TextEditingController();
  final TextEditingController _displayOrderController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  final GlobalKey<ImagePickerUploaderState> _evidenceImageKey =
      GlobalKey<ImagePickerUploaderState>();

  Map<String, dynamic>? _selectedOrder;

  String _currentRole = 'buyer';
  String? _nature;
  String? _evidenceImageUrl;

  String? _orderError;
  String? _itemError;
  String? _detailsError;

  bool _natureError = false;
  bool _evidenceError = false;
  bool _submitting = false;
  bool _prefilledFromRoute = false;

  static const List<String> _buyerDisputeOptions = [
    'Item not delivered',
    'Damaged item',
    'Wrong item received',
    'Traveler not responding',
    'Payment issue',
    'Delivery was late',
    'Other issue',
  ];

  static const List<String> _travelerDisputeOptions = [
    'Delivery confirmation refused',
    'Buyer not responding',
    'Wrong delivery details',
    'Payment issue',
    'Other issue',
  ];

  List<String> get _activeDisputeOptions {
    if (_currentRole.toLowerCase() == 'traveler') {
      return _travelerDisputeOptions;
    }

    return _buyerDisputeOptions;
  }

  @override
  void initState() {
    super.initState();
    _currentRole =
        widget.initialRole.toLowerCase() == 'traveler' ? 'traveler' : 'buyer';
    _prefillFromOrder(widget.initialOrder);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_prefilledFromRoute) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      _prefillFromOrder(args);
    }

    _prefilledFromRoute = true;
  }

  @override
  void dispose() {
    _orderController.dispose();
    _displayOrderController.dispose();
    _itemController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _prefillFromOrder(Map<String, dynamic>? order) {
    if (order == null) return;

    final converted = Map<String, dynamic>.from(order);
    _selectedOrder = converted;
    _currentRole = _getUserRoleFromOrder(converted);

    final orderId = _getOrderId(converted);
    final itemName = _getItemName(converted);

    if (orderId.isNotEmpty) {
      _orderController.text = orderId;
      _displayOrderController.text = '#${_shortOrderId(orderId)}';
    }

    if (itemName.isNotEmpty) {
      _itemController.text = itemName;
    }
  }

  String _getUserRoleFromOrder(Map<String, dynamic> order) {
    final value = order['viewerRole'] ??
        order['role'] ??
        order['currentRole'] ??
        order['userRole'] ??
        widget.initialRole;

    final role = value?.toString().toLowerCase() ?? 'buyer';

    if (role == 'traveler') return 'traveler';
    return 'buyer';
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

    return value?.toString() ?? '';
  }

  String _shortOrderId(String value) {
    final clean = value.trim();
    if (clean.length <= 6) return clean;
    return clean.substring(clean.length - 6);
  }

  DateTime? _parseDateField(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _getStatus(Map<String, dynamic> order) {
    final value = order['status'] ??
        order['orderStatus'] ??
        order['deliveryStatus'] ??
        order['state'];

    return value?.toString() ?? '';
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

    if (status.isEmpty) return true;

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



  bool _doesNatureNeedEvidence(String? nature) {
    final text = _normalizeText(nature ?? '');

    return text.contains('damaged item') ||
        text.contains('damage item') ||
        text.contains('wrong item') ||
        text.contains('delivery confirmation refused') ||
        text.contains('wrong delivery details');
  }

  bool get _isEvidenceRequired => _doesNatureNeedEvidence(_nature);

  bool _hasEvidenceSelected() {
    final hasPickerImage = _evidenceImageKey.currentState?.hasImage ?? false;
    final hasSavedUrl =
        _evidenceImageUrl != null && _evidenceImageUrl!.trim().isNotEmpty;

    return hasPickerImage || hasSavedUrl;
  }

  bool _canSubmitDisputeForOrder(Map<String, dynamic> order) {
    if (_isDisputeWindowOpen(order)) return true;

    // Before delivery, placed/in-transit orders can be disputed anytime.
    // The 24 hour limit applies only after the order is delivered/confirmed.
    return _isUndeliveredOrder(order);
  }

  bool _validateForm() {
    final orderId = _orderController.text.trim();
    final itemName = _itemController.text.trim();
    final details = _detailsController.text.trim();

    setState(() {
      _orderError = null;
      _itemError = null;
      _detailsError = null;
      _natureError = false;
      _evidenceError = false;

      if (_selectedOrder == null || orderId.isEmpty) {
        _orderError = 'Please select order first';
      }

      if (itemName.isEmpty) {
        _itemError = 'Item name is required';
      }

      if (_nature == null || _nature!.trim().isEmpty) {
        _natureError = true;
      }

      if (details.isEmpty) {
        _detailsError = 'Explain issue';
      } else if (details.length < 10) {
        _detailsError = 'Please add more details';
      }

      if (_isEvidenceRequired && !_hasEvidenceSelected()) {
        _evidenceError = true;
      }
    });

    return _orderError == null &&
        _itemError == null &&
        _detailsError == null &&
        !_natureError &&
        !_evidenceError;
  }

  Future<void> _submitDispute() async {
    if (!_validateForm()) return;

    if (_selectedOrder != null && !_canSubmitDisputeForOrder(_selectedOrder!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isUndeliveredOrder(_selectedOrder!)
                ? 'You can file a dispute for this order.'
                : 'Dispute time is over for this order',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final uploadedEvidenceUrl =
          await _evidenceImageKey.currentState?.uploadAndReturn();

      if (!mounted) return;

      _evidenceImageUrl = uploadedEvidenceUrl;

      final selectedOrderId = _selectedOrder == null
          ? _orderController.text.trim()
          : _getOrderId(_selectedOrder!);

      await ApiService.post('/api/disputes', {
        'orderId': selectedOrderId,
        'orderNumber': _orderController.text.trim(),
        'itemDescription': _itemController.text.trim(),
        'natureOfDispute': _nature,
        'extraDetails': _detailsController.text.trim(),
        'documentURL': _evidenceImageUrl,
        'evidenceImage': _evidenceImageUrl,
        'filedByRole': _currentRole,
        'againstRole': _currentRole == 'buyer' ? 'traveler' : 'buyer',
        'buyerUid': _selectedOrder?['buyerUid']?.toString(),
        'travelerUid': _selectedOrder?['travelerUid']?.toString(),
        'viewerRole': _currentRole,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute submitted successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit dispute: $e')),
      );
    }

    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  Future<void> _openOrderSelector() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDisputeOrderScreen(
          role: _currentRole,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  Widget _space() => const SizedBox(height: 20);

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

  Widget _selectOrderFirstState() {
    return emptyInfoCard(
      icon: Icons.receipt_long_outlined,
      title: 'Select order first',
      subtitle: 'A dispute must be linked with an existing order.',
      action: SizedBox(
        width: double.infinity,
        height: 50,
        child: appPrimaryButton(
          text: 'Select Order',
          onPressed: _openOrderSelector,
        ),
      ),
    );
  }

  Widget _orderDetailsSection() {
    return infoCard([
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(
            'ORDER DETAILS',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 8),
          CustomInputField(
            controller: _displayOrderController,
            hint: _orderError ?? 'Order ID',
            icon: Icons.receipt_long_outlined,
            readOnly: true,
            hasError: _orderError != null,
          ),
          CustomInputField(
            controller: _itemController,
            hint: _itemError ?? 'Item Name',
            icon: Icons.inventory_2_outlined,
            readOnly: true,
            hasError: _itemError != null,
          ),
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentRole == 'traveler'
                      ? Icons.flight_takeoff_outlined
                      : Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentRole == 'traveler' ? 'Traveler Side' : 'Buyer Side',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _disputeDetailsSection() {
    return infoCard([
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(
            'DISPUTE DETAILS',
            icon: Icons.gavel_outlined,
          ),
          const SizedBox(height: 8),
          CustomInputField(
            hint: 'Select Nature of Dispute',
            icon: Icons.gavel_outlined,
            value: _nature,
            hasError: _natureError,
            categoryItems: _activeDisputeOptions
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChangedDropdown: (value) {
              if (value == null) return;

              setState(() {
                _nature = value;
                _natureError = false;
                _evidenceError = false;
              });
            },
          ),
          _noteInput(),
          _space(),
          sectionLabel(
            _isEvidenceRequired
                ? 'UPLOAD EVIDENCE'
                : 'UPLOAD EVIDENCE (OPTIONAL)',
            icon: Icons.add_photo_alternate_outlined,
          ),
          const SizedBox(height: 6),
          Text(
            _isEvidenceRequired
                ? 'Evidence is required for this dispute type.'
                : 'Evidence is optional for this dispute type.',
            style: TextStyle(
              color: _evidenceError ? AppColors.error : AppColors.textgray,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ImagePickerUploader(
            key: _evidenceImageKey,
            initialImage: _evidenceImageUrl,
            hasError: _evidenceError,
            onChanged: (url) {
              setState(() {
                _evidenceImageUrl = url;
                _evidenceError = false;
              });
            },
          ),
        ],
      ),
    ]);
  }

  Widget _noteInput() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _detailsError != null ? AppColors.primary : AppColors.border,
            width: 1.2,
          ),
        ),
        child: TextField(
          controller: _detailsController,
          maxLines: 5,
          onChanged: (_) {
            if (_detailsError != null) {
              setState(() => _detailsError = null);
            }
          },
          decoration: InputDecoration(
            hintText: _detailsError ?? 'Explain issue',
            hintStyle: TextStyle(
              color: _detailsError != null ? AppColors.primary : AppColors.icon,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 78),
              child: Icon(
                Icons.notes_outlined,
                color: AppColors.icon,
                size: 20,
              ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textprimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedOrder = _selectedOrder != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: dashboardAppBar(
        title: 'File Dispute',
        leading: _backButton(),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(15),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 30,
              ),
              child: hasSelectedOrder
                  ? Column(
                      children: [
                        _orderDetailsSection(),
                        _space(),
                        _disputeDetailsSection(),
                        _space(),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: appPrimaryButton(
                            text: _submitting
                                ? 'Submitting...'
                                : 'Submit Dispute',
                            loading: _submitting,
                            onPressed: _submitDispute,
                          ),
                        ),
                        SizedBox(height: 55,)
                      ],
                    )
                  : Center(child: _selectOrderFirstState()),
            ),
          );
        },
      ),
    );
  }
}
