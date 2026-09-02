import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:skybridge02/Services/app_config.dart';
import 'package:skybridge02/Home/home_screen.dart';

class StripeGate extends StatefulWidget {
  const StripeGate({super.key});

  @override
  State<StripeGate> createState() => _StripeGateState();
}

class _StripeGateState extends State<StripeGate> {
  bool handled = false;

  @override
  void initState() {
    super.initState();
    _handleStripe();
  }

  Future<void> _handleStripe() async {
    final uri = Uri.base;

// 👉 extract fragment: /stripe?cancel=true
    final fragment = uri.fragment;

// 👉 convert to Uri
    final fragUri =
        Uri.parse(fragment.startsWith('/') ? fragment : '/$fragment');

    final sessionId = fragUri.queryParameters['session_id'];
    final cancel = fragUri.queryParameters['cancel'];

    if (handled) return;

    if (sessionId != null) {
      handled = true;

      final created = await _createOrder(sessionId);

      _showDialog(
        title: created ? "Payment Successful" : "Order Creation Pending",
        message: created
            ? "Your payment was successful and your order has been placed."
            : "Your payment was successful, but the order was not created automatically. Please open My Orders or contact admin with your payment session ID.",
        isSuccess: created,
      );
    } else if (cancel != null) {
      handled = true;

      _showDialog(
        title: "Payment Cancelled",
        message: "You cancelled the payment.",
        isSuccess: false,
      );
    } else {
      _goHome(); // fallback
    }
  }

  Future<bool> _createOrder(String sessionId) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((value) => value != null)
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        user = FirebaseAuth.instance.currentUser;
      }
    }

    if (user == null) return false;

    final token = await user.getIdToken(true);

    final res = await http.post(
      Uri.parse('${getFunctionsBase()}/orders/createOrder'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'sessionId': sessionId}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('Create order failed: ${res.statusCode} ${res.body}');
      return false;
    }

    return true;
  }

  void _showDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.cancel,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: _goHome,
              child: const Text("OK"),
            ),
          ],
        ),
      );
    });
  }

  void _goHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
