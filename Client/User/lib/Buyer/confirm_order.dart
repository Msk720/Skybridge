// lib/order_confirmation.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/section_label.dart';
import '../Services/DashBoardHelper/api_service.dart';

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({super.key});

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _loading = false;
  double weightTotal = 0.0;

  late Map<String, dynamic> data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    data = (args != null && args is Map)
        ? Map<String, dynamic>.from(args)
        : <String, dynamic>{};
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _confirmAndSend(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to confirm order')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = {
        ...data,
        'price': _toDouble(data['price']),
        'weight': _toDouble(data['weight']),
        'weightTotal': _toDouble(data['weight']) * _toInt(data['quantity']),
        'quantity': _toInt(data['quantity']),
        'userId': data['userId'] ?? user.uid,
        'itemPrice': _toDouble(data['itemPrice']),
        'travelerReward': _toInt(data['travelerReward']),
        'totalPrice': _toDouble(data['totalPrice']),
        'status': data['status'] ?? 'Active',
      };

      final result = await ApiService.post(
        '/createData',
        {
          "collection": "items",
          "data": payload,
        },
      );

      debugPrint("DataItem success: $result");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product Request posted successfully')),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    } catch (e) {
      debugPrint('createItem error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = data['image']?.toString() ?? '';
    final name = data['name']?.toString() ?? '';
    final weight = _toDouble(data['weight']);
    final quantity = _toInt(data['quantity']);
    final dateStr = data['date']?.toString() ?? '';
    final fromCountry = data['fromCountry']?.toString() ?? '';
    final fromCity = data['fromCity']?.toString() ?? '';
    final toCountry = data['toCountry']?.toString() ?? '';
    final toCity = data['toCity']?.toString() ?? '';
    final itemPrice = _toDouble(data['itemPrice']);
    final travelerReward = _toInt(data['travelerReward']);
    final totalPrice = _toDouble(data['totalPrice']);
    final weightTotal = weight * quantity;
    final price = _toDouble(data['price']);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: " Confirmation",
        leading: Container(
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
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            /// IMAGE CARD
            infoCard([
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          height: 160,
                          width: 150,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image, size: 80),
                ),
              ),
            ]),

            const SizedBox(height: 12),

            infoCard([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  sectionLabel("PRODUCT", icon: Icons.shopping_cart_checkout),
                  const SizedBox(height: 5),
                  sectionContent([
                    infoText(text: 'Quantity: $quantity'),
                    infoText(
                        text:
                            'Product Weight: ${weight.toStringAsFixed(2)} kg'),
                    infoText(
                        text:
                            'Total Weight: ${weightTotal.toStringAsFixed(2)} kg'),
                    infoText(
                      text: 'Store Price: \$${price.toStringAsFixed(2)}',
                    ),
                  ]),
                ],
              ),
            ]),

            const SizedBox(height: 12),
            infoCard([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel("SHIPPING", icon: Symbols.package_2),
                  const SizedBox(height: 5),
                  sectionContent([
                    infoText(text: 'From: $fromCountry, $fromCity'),
                    infoText(text: 'To: $toCountry, $toCity'),
                    infoText(
                      text: 'Needed Before: ${dateStr.split('T').first}',
                    ),
                  ]),
                ],
              ),
            ]),

            const SizedBox(height: 12),
            infoCard([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel("PRICE INFO", icon: Icons.attach_money),
                  const SizedBox(height: 5),
                  sectionContent([
                    infoText(
                      text: 'Items Cost: \$${itemPrice.toStringAsFixed(2)}',
                    ),
                    infoText(
                      text:
                          'Traveler Reward: \$${travelerReward.toStringAsFixed(2)}',
                    ),
                    infoText(
                      text:
                          'Estimated Total: \$${totalPrice.toStringAsFixed(2)}',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ]),
                ],
              )
            ]),

            const SizedBox(height: 20),

            if (_loading) const CircularProgressIndicator(),
            if (!_loading)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: appPrimaryButton(
                      text: 'Confirm',
                      onPressed: () => _confirmAndSend(data),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/home'),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                              const SizedBox(height: 40),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Widget infoText({
  required String text,
  Color? color,
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.normal,
}) {
  return Text(
    text,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: const Color.fromARGB(255, 87, 97, 122),
    ),
  );
}

Widget sectionContent(List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.only(left: 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}
