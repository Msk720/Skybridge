import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:skybridge02/CommunicationManagement/chatlistscreen.dart';
import 'package:skybridge02/Home/home_screen.dart';
import 'package:skybridge02/PaymentIntegration/stripe_connect_screen.dart';
import 'package:skybridge02/UserManagement/profile_screen.dart';
import 'firebase_options.dart';

// Buyer
import 'Buyer/shipment_dashboard.dart';
import 'Buyer/explore_shops.dart';
import 'Buyer/request_option_screen.dart';
import 'Buyer/confirm_order.dart';
import 'Buyer/offer_dash.dart';
import 'Buyer/shipping_details.dart';
import "Buyer/add_product_info.dart";

// User management
import 'UserManagement/splash_screen.dart';
import 'UserManagement/login_screen.dart';
import 'UserManagement/profile_gate.dart';
import 'UserManagement/timer_screen.dart';
import 'UserManagement/forgot_password.dart';
import 'UserManagement/verification.dart';

// Home
import 'Home/buyer.dart';

// Traveler
import 'Travelor/trip_dash.dart';
import 'Travelor/add_trip_info.dart';

// // Orders
import 'OrderManagement/order_dashboard.dart';
import 'DisputeManagement/dispute_dashboard.dart';

// Payment
import 'PaymentIntegration/payment_screen.dart';
import 'PaymentIntegration/stripe_auth.dart';

// Search
import 'SearchManagement/shipment_details_screen.dart';
import 'SearchManagement/search_dash.dart';

// Product
import 'ProductManagement/productdash.dart';

// Notifications
import 'Notification/notifications_screen.dart';

// Services
import 'Services/app_imports.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    Stripe.publishableKey =
        'pk_test_51SzDhkJBR7G3lWKnk2s5Zq4KIBeSZ4BYzyKqdVK6FijJURcTrjaMbsAEnlBa8ZyRi8DuMxRJr4kbWa2nHttbg0uU003AxIdXAI';

    await Stripe.instance.applySettings();
  }

  final uri = Uri.base;
  final fullReturnUrl =
      '${uri.path}?${uri.query}#${uri.fragment}'.toLowerCase();
  final isStripe = uri.path == '/stripe' ||
      uri.fragment.startsWith('/stripe') ||
      fullReturnUrl.contains('session_id=') ||
      fullReturnUrl.contains('cancel=true');

  runApp(MyApp(isStripe: isStripe));
}

class MyApp extends StatelessWidget {
  final bool isStripe;

  const MyApp({super.key, required this.isStripe});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: kIsWeb
          ? (isStripe ? const StripeGate() : const SplashScreen())
          : const TimerScreen(),
      onGenerateRoute: (settings) {
        final routeName = settings.name ?? '';
        final routePath =
            Uri.tryParse(routeName)?.path ?? routeName.split('?').first;

        if (routePath == '/stripe' ||
            routeName.contains('session_id=') ||
            routeName.contains('cancel=true')) {
          return MaterialPageRoute(
            builder: (_) => const StripeGate(),
            settings: settings,
          );
        }

        return null;
      },
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/search': (context) => const SearchDash(),
        '/dashboard': (context) => const ShipmentDashboard(),
        '/explore': (context) => const ExploreShops(),
        '/Buyer': (context) => const BuyerScreen(),
        '/RequestOptions': (context) => const RequestOptionsScreen(),
        '/OrderConfirmation': (context) => const OrderConfirmationScreen(),
        '/tripDash': (context) => const TripsDashboard(),
        '/gate': (context) => const ProfileGate(),
        '/Order': (context) => const Orderdashboard(),
        '/offer': (context) => const OfferDashboard(),
        '/order': (context) => const Orderdashboard(),
        '/payment': (context) => const PaymentScreen(),
        '/SplashScreen': (context) => const SplashScreen(),
        '/add_request_info': (context) => const AddProductInfo(),
        '/add_trip_info': (context) => const TripCreateScreen(),
        '/forgotPassword': (context) => const ForgotPasswordScreen(),
        '/verification': (context) => const VerifyEmailScreen(),
        '/TimerScreen': (context) => const TimerScreen(),
        '/ProductDashboard': (context) => const ProductDashboard(),
        '/ShippingForm': (context) => const ShippingFormScreen(),
        '/shipmentDetails': (context) => const ShipmentDetailsScreen(),
        '/stripe': (context) => const StripeGate(),
        '/stripeConnect': (context) => const StripeConnectScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/messages': (context) => const ChatListScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/disputes': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final role =
              args is Map ? args['role']?.toString().toLowerCase() : null;

          return DisputeDashboard(
            role: role == 'traveler' ? 'traveler' : 'buyer',
          );
        },
      },
    );
  }
}
