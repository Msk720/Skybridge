import 'package:skybridge02/Home/Component/custom_drawer.dart';
import 'package:skybridge02/Travelor/request_dash.dart';

import 'buyer.dart';
import 'traveler_screen.dart';
import 'package:skybridge02/Travelor/trip_dash.dart';
import 'package:skybridge02/CommunicationManagement/chatlistscreen.dart';
import 'package:skybridge02/Buyer/shipment_dashboard.dart';
import 'package:skybridge02/OrderManagement/order_dashboard.dart';
import 'package:skybridge02/Buyer/offer_dash.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/nav_bar.dart';
import 'package:skybridge02/Notification/notification_bell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _pageRefreshToken = 0;

  String selectedTab = 'Buyer';

  Widget get _ordersScreen => Orderdashboard(
        key: ValueKey('orders-$selectedTab-$_pageRefreshToken'),
        role: selectedTab == 'Buyer' ? 'buyer' : 'traveler',
      );

  Widget get _tripsScreen => TripsDashboard(
        key: ValueKey('trips-$_pageRefreshToken'),
      );
  Widget get _chatListScreen => ChatListScreen(
        key: ValueKey('messages-$selectedTab-$_pageRefreshToken'),
        showBackButton: false,
        selectedTab: selectedTab,
      );
  Widget get _shipmentScreen => ShipmentDashboard(
        key: ValueKey('shipments-$_pageRefreshToken'),
      );
  Widget get _offersScreen => OfferDashboard(
        key: ValueKey('offers-$_pageRefreshToken'),
      );
  Widget get _requestsScreen => RequestDashboard(
        key: ValueKey('requests-$_pageRefreshToken'),
      );

  void _switchHomeTab(String label) {
    if (selectedTab == label) return;

    setState(() {
      selectedTab = label;
      _pageRefreshToken++;
    });
  }

  Widget _buildHomeContent() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: topPadding + 10,
              left: 16,
              right: 16,
              bottom: 0,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              children: [
                // 🔹 TOP ROW (Logo + Icons)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'S',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        Text(
                          'ky',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                        Text(
                          'B',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        Text(
                          'RIDGE',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _circleIcon(
                          Icons.search,
                          onTap: () {
                            Navigator.pushNamed(context, '/search');
                          },
                        ),
                        const SizedBox(width: 8),
                        const NotificationBell(),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (context) {
                            return _circleIcon(
                              Icons.menu,
                              onTap: () {
                                Scaffold.of(context).openDrawer();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Column(
                  children: [
                    // 🔹 TAB TEXT
                    Row(
                      children: [
                        _tabItem("Buyer"),
                        _tabItem("Traveler"),
                      ],
                    ),
                    SizedBox(
                      height: 2.5,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final tabWidth = constraints.maxWidth / 2;

                          return Stack(
                            children: [
                              Positioned(
                                left: selectedTab == "Buyer" ? 0 : tabWidth,
                                child: Container(
                                  width: tabWidth,
                                  height: 2.5,
                                  color: AppColors.activeline,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child:
                    selectedTab == 'Buyer' ? BuyerScreen() : TravelerScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(String label) {
    final isActive = selectedTab == label;

    return Expanded(
      child: GestureDetector(
        onTap: () => _switchHomeTab(label),
        child: Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              color: isActive
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.white.withValues(alpha: 0.85),
          size: 18,
        ),
      ),
    );
  }

  List<Widget> get _pages => [
        _buildHomeContent(),
        selectedTab == 'Buyer' ? _shipmentScreen : _tripsScreen,
        _ordersScreen,
        selectedTab == 'Buyer' ? _offersScreen : _requestsScreen,
        _chatListScreen,
      ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        drawer: CustomDrawer(selectedTab: selectedTab),
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: CustomNavBar(
          currentIndex: _currentIndex,
          selectedTab: selectedTab,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _pageRefreshToken++;
            });
          },
        ),
      ),
    );
  }
}
