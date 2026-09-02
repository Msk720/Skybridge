import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';

class QrScannerScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const QrScannerScreen({
    super.key,
    required this.order,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String rawValue) async {
    if (processing) return;

    setState(() => processing = true);

    try {
      final decoded = jsonDecode(rawValue);
      final scannedOrderId = decoded['orderId']?.toString();
      final token = decoded['token']?.toString();
      final qrTransactionId = decoded['qrTransactionId']?.toString();
      final type = decoded['type']?.toString();
      final currentOrderId = widget.order['id']?.toString();

      if (type != 'delivery_verification' ||
          scannedOrderId == null ||
          token == null ||
          scannedOrderId != currentOrderId) {
        throw Exception('Invalid QR for this order');
      }

      final result = await ApiService.post('/verifyDeliveryQr', {
        'orderId': scannedOrderId,
        'token': token,
        if (qrTransactionId != null && qrTransactionId.isNotEmpty)
          'qrTransactionId': qrTransactionId,
      });

      if (result['success'] != true) {
        throw Exception('Verification failed');
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR or delivery verification failed'),
        ),
      );

      setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Delivery QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final rawValue = capture.barcodes.isEmpty
                  ? null
                  : capture.barcodes.first.rawValue;

              if (rawValue != null && rawValue.isNotEmpty) {
                _handleCode(rawValue);
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 42,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                processing
                    ? 'Verifying delivery...'
                    : 'Scan the buyer delivery QR to mark this order as received. Payment will be held for 24 hours for dispute review.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (processing)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
