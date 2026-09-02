import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';

class DeliveryQrDialog extends StatefulWidget {
  final Map<String, dynamic> order;

  const DeliveryQrDialog({
    super.key,
    required this.order,
  });

  @override
  State<DeliveryQrDialog> createState() => _DeliveryQrDialogState();
}

class _DeliveryQrDialogState extends State<DeliveryQrDialog> {
  bool loading = true;
  String? qrPayload;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  Future<void> _loadQr() async {
    final orderId = widget.order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      setState(() {
        loading = false;
        errorMessage = 'Invalid order.';
      });
      return;
    }

    try {
      final result = await ApiService.post('/createDeliveryQr', {
        'orderId': orderId,
      });

      setState(() {
        qrPayload = result['qrPayload']?.toString();
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'Unable to generate delivery QR.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: Color(0xFF0F766E),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Delivery Verification QR',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask the traveler to scan this QR after handing over the order. Payment will be held for 24 hours before release.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(),
              )
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrPayload!,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF103F81),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
