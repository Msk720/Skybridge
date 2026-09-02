import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skybridge02/Services/app_config.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool loading = false;
  late String offerId;
  double amount = 0.0;

  double get totalWithFee {
    final total = (amount + 0.30) / (1 - 0.029);
    return double.parse(total.toStringAsFixed(2));
  }

  double get stripeFee {
    final fee = totalWithFee - amount;
    return double.parse(fee.toStringAsFixed(2));
  }

  CardFieldInputDetails? _card;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    final args = route?.settings.arguments as Map<String, dynamic>?;

    if (args == null || args['offerId'] == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/offer');
      });
      return;
    }

    offerId = args['offerId'];

    _loadAmount();
  }

  Future<void> _payWeb() async {
    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final token = await user.getIdToken();

      final res = await http.post(
        Uri.parse('${getFunctionsBase()}/createCheckoutSessionFromOffer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'offerId': offerId,
          'appOrigin': Uri.base.origin,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to create checkout session');
      }

      final data = jsonDecode(res.body);
      final checkoutUrl = data['url'];

      final uri = Uri.parse(checkoutUrl);

      if (!await launchUrl(uri, webOnlyWindowName: '_self')) {
        throw Exception('Could not open Stripe Checkout');
      }
    } catch (e) {
      _show('Payment failed');
      setState(() => loading = false);
    }
  }

  Future<void> _pay() async {
    if (kIsWeb) {
      await _payWeb();
    } else {
      await _payMobile();
    }
  }

  Future<void> _loadAmount() async {
    try {
      final res = await ApiService.get(
        "/listDataWithDetails?collection=offers",
      );

      final List data = res["data"] ?? [];

      Map<String, dynamic>? offer;

      for (final o in data) {
        if (o['id'] == offerId) {
          offer = Map<String, dynamic>.from(o);
          break;
        }
      }

      if (offer == null) return;

      setState(() {
        amount = (offer!['totalAmount'] as num).toDouble();
      });
    } catch (e) {
      debugPrint('Load amount error: $e');
    }
  }

  Future<void> _payMobile() async {
    if (_card == null || !_card!.complete) {
      _show('Please enter complete card details');
      return;
    }

    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final token = await user.getIdToken();

      final res = await http.post(
        Uri.parse('${getFunctionsBase()}/createPaymentIntentFromOffer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'offerId': offerId}),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Create payment intent failed: ${res.body}');
      }

      final data = jsonDecode(res.body);

      final clientSecret = data['clientSecret']?.toString();
      final paymentIntentId = data['paymentIntentId']?.toString();

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Payment client secret missing');
      }

      if (paymentIntentId == null || paymentIntentId.isEmpty) {
        throw Exception('Payment intent ID missing');
      }

      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name: FirebaseAuth.instance.currentUser?.displayName ??
                  FirebaseAuth.instance.currentUser?.email ??
                  "SkyBridge User",
              email: FirebaseAuth.instance.currentUser?.email,
            ),
          ),
        ),
      );

      final orderRes = await http.post(
        Uri.parse('${getFunctionsBase()}/orders/createOrder'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'offerId': offerId,
          'paymentIntentId': paymentIntentId,
        }),
      );

      if (orderRes.statusCode < 200 || orderRes.statusCode >= 300) {
        throw Exception('Create order failed: ${orderRes.body}');
      }

      if (!mounted) return;

      setState(() => loading = false);

      _show('✅ Payment successful');

      Navigator.pop(context, true);
    } on StripeException catch (e) {
      debugPrint('STRIPE ERROR: ${e.error}');
      if (mounted) {
        _show(e.error.message ?? 'Stripe error');
      }
    } catch (e) {
      debugPrint('UNKNOWN PAYMENT ERROR: $e');
      if (mounted) {
        _show('❌ Payment failed: $e');
      }
    } finally {
      if (mounted && loading) {
        setState(() => loading = false);
      }
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: dashboardAppBar(
        title: "Request Options",
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
      body: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 5),
            const Text(
              'Send payment to us',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Amount: \$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (!kIsWeb) ...[
              const Text(
                'Card details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: CardField(
                  onCardChanged: (card) => _card = card,
                  enablePostalCode: true,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ],
           
            const SizedBox(height: 12),
            Text(
              ' Fee: \$${stripeFee.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
         

            SizedBox(
              width: double.infinity,
              height: 50,
              child: appPrimaryButton(
                text: 'Pay \$${totalWithFee.toStringAsFixed(2)}',
                loading: loading,
                onPressed: _pay,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Test Card: 4242 4242 4242 4242\nAny future date • Any CVC',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
