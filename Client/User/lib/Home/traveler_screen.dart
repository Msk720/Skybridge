// lib/traveler_screen.dart
import 'package:flutter/material.dart';
import 'package:skybridge02/Home/Component/app_asset_image.dart';
import 'package:skybridge02/Home/Component/section_title.dart';
import 'package:skybridge02/Theme/app_color.dart';
import 'package:skybridge02/Home/Component/info_slider.dart';
import 'package:skybridge02/Home/Component/horizontal_list.dart';

class TravelerScreen extends StatelessWidget {
  const TravelerScreen({super.key});

  List<InfoSlide> get _sliderData => [
        InfoSlide(
          title: 'Traveling with Extra Space?',
          description: 'Deliver items while traveling and earn money.',
          iconName: 'flight',
        ),
        InfoSlide(
          title: 'Earn While You Travel',
          description: 'Use your luggage space to carry items for shoppers.',
          iconName: 'travel-earn',
        ),
        InfoSlide(
          title: 'Need Assistance?',
          description: 'Our support team is here to help.',
          iconName: 'support',
        ),
      ];

  final List<Map<String, String>> _trendingcountries = const [
    {'name': 'Pakistan ', 'image': 'assets/images/Flags/pakistanround.png'},
    {'name': 'USA', 'image': 'assets/images/Flags/usaround.png'},
    {'name': 'China', 'image': 'assets/images/Flags/chinaround.png'},
    {'name': 'Germany', 'image': 'assets/images/Flags/germanyround.png'},
    {'name': 'India', 'image': 'assets/images/Flags/indiaround.png'},
    {'name': 'UK', 'image': 'assets/images/Flags/ukround.png'},
    {'name': 'Japan', 'image': 'assets/images/Flags/japanround.png'},
    {'name': 'Brazil', 'image': 'assets/images/Flags/brazilround.png'},
    {'name': 'South Korea', 'image': 'assets/images/Flags/southkorearound.png'},
  ];

  final List<Map<String, dynamic>> _travelRoutes = const [
    // first route (city-to-city, same pattern)
    {
      'route': 'Lahore - Istanbul',
      'flag1': 'assets/images/Flags/pakistan.png',
      'flag2': 'assets/images/Flags/turkey.png',
    },

    {
      'route': 'New York - Paris',
      'flag1': 'assets/images/Flags/usa.png',
      'flag2': 'assets/images/Flags/france.png',
    },
    {
      'route': 'London - Tokyo',
      'flag1': 'assets/images/Flags/unitedkingdom.png',
      'flag2': 'assets/images/Flags/japan.png',
    },
    {
      'route': 'Dubai - Sydney',
      'flag1': 'assets/images/Flags/uae.png',
      'flag2': 'assets/images/Flags/australia.png',
    },
    {
      'route': 'Berlin - Los Angeles',
      'flag1': 'assets/images/Flags/germany.png',
      'flag2': 'assets/images/Flags/usa.png',
    },
    {
      'route': 'Tokyo - New York',
      'flag1': 'assets/images/Flags/japan.png',
      'flag2': 'assets/images/Flags/usa.png',
    },
    {
      'route': 'Istanbul - London',
      'flag1': 'assets/images/Flags/turkey.png',
      'flag2': 'assets/images/Flags/unitedkingdom.png',
    },
    {
      'route': 'Delhi - Dubai',
      'flag1': 'assets/images/Flags/india.png',
      'flag2': 'assets/images/Flags/uae.png',
    },
  ];

  final List<Map<String, String>> _topDestinations = const [
    {
      'name': 'Lahore',
      'shipments': '900 Shipment',
      'trips': '1000 Trip',
      'image': 'assets/images/Flags/LahoreCity.jpg',
    },
    {
      'name': 'Dubai',
      'shipments': '1077 Shipment',
      'trips': '719 Trip',
      'image': 'assets/images/Flags/DubaiCity.jpg',
    },
    {
      'name': 'Istanbul',
      'shipments': '1500 Shipment',
      'trips': '1000 Trip',
      'image': 'assets/images/Flags/IstanbulCity.jpg',
    },
    {
      'name': 'Paris',
      'shipments': '2000 Shipments',
      'trips': '1800 Trips',
      'image': 'assets/images/Flags/ParisCity.jpg',
    },
    {
      'name': 'Tokyo',
      'shipments': '1300 Shipments',
      'trips': '1100 Trips',
      'image': 'assets/images/Flags/TokyoCity.jpg',
    },
    {
      'name': 'New York City',
      'shipments': '1600 Shipments',
      'trips': '1400 Trips',
      'image': 'assets/images/Flags/NewyorkCity.jpg',
    },
    {
      'name': 'London',
      'shipments': '800 Shipments',
      'trips': '700 Trips',
      'image': 'assets/images/Flags/LondonCity.jpg',
    },
    {
      'name': 'Sydney',
      'shipments': '900 Shipments',
      'trips': '850 Trips',
      'image': 'assets/images/Flags/SydneyCity.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoSlider(slides: _sliderData),

                const SizedBox(height: 8),

                sectionTitle('Top Product Demand Countries'),

                const SizedBox(height: 10),
                horizontalList(
                  itemCount: _trendingcountries.length,
                  spacing: 10,
                  useCard: false,
                  itemBuilder: (index) {
                    final s = _trendingcountries[index];

                    return Column(
                      children: [
                        Container(
                          width: 69,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.white,
                          ),
                          child: Center(
                            child: appAssetImage(
                              s['image'],
                              width: 50,
                              height: 50,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s['name']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Top Destinations
                const SizedBox(height: 18),

                sectionTitle('Top Destinations'),

                const SizedBox(height: 10),

                horizontalList(
                  itemCount: _topDestinations.length,
                  itemBuilder: (index) {
                    final d = _topDestinations[index];

                    return SizedBox(
                      width: 40,
                      child: Column(
                        children: [
                          appAssetImage(d['image'],
                              width: double.infinity, height: 110),
                          const SizedBox(height: 10),
                          Text(d['name']!,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(d['shipments']!,
                              style:
                                  const TextStyle(color: AppColors.secondary)),
                          Text(d['trips']!,
                              style:
                                  const TextStyle(color: AppColors.secondary)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),

                sectionTitle(
                  'Top Travel Routes',
                ),

                const SizedBox(height: 10),
                horizontalList(
                  itemCount: _travelRoutes.length,
                  itemBuilder: (index) {
                    final r = _travelRoutes[index];

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            appAssetImage(r['flag1'], width: 40, height: 25),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('→',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                            appAssetImage(r['flag2'], width: 40, height: 25),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          r['route']!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ));
  }
}
