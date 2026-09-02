import 'package:skybridge02/Home/Component/app_asset_image.dart';
import 'package:skybridge02/Home/Component/section_title.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/DashBoardHelper/list_data_handler.dart';
import 'package:skybridge02/Services/open_link.dart';
import 'package:skybridge02/Home/Component/info_slider.dart';
import 'package:skybridge02/ProductManagement/product_card.dart';
import 'package:skybridge02/Home/Component/horizontal_list.dart';

class BuyerScreen extends StatefulWidget {
  const BuyerScreen({super.key});

  @override
  State<BuyerScreen> createState() => _BuyerScreenState();
}

class _BuyerScreenState extends State<BuyerScreen> {
  int _selectedCategory = 0;

  final List<InfoSlide> _slides = [
    InfoSlide(
      title: 'Want a Product from Abroad?',
      description: 'Submit your order and connect with travelers.',
      iconName: 'shopping-bag',
    ),
    InfoSlide(
      title: 'Shop Global Brands Easily',
      description: 'Access international products through travelers.',
      iconName: 'global-shop',
    ),
    InfoSlide(
      title: 'Need Assistance?',
      description: 'Our support team is ready to help you anytime.',
      iconName: 'support',
    ),
  ];

  final List<Map<String, String>> _trendingStores = const [
    {
      'name': 'Apple',
      'image': 'assets/images/Brands/apple.png',
      'storeUrl': 'https://www.apple.com/',
    },
    {
      'name': 'Nike',
      'image': 'assets/images/Brands/nike.png',
      'storeUrl': 'https://www.nike.com/',
    },
    {
      'name': 'Lego',
      'image': 'assets/images/Brands/legostore.png',
      'storeUrl': 'https://www.lego.com/en-us',
    },
    {
      'name': 'Puma',
      'image': 'assets/images/Brands/puma.png',
      'storeUrl': 'https://about.puma.com/en',
    },
    {
      'name': 'Gucci',
      'image': 'assets/images/Brands/gucci.png',
      'storeUrl': 'https://www.gucci.com/us/en/',
    },
    {
      'name': 'Adidas',
      'image': 'assets/images/Brands/adidas.png',
      'storeUrl': 'https://www.adidas.com/',
    },
    {
      'name': 'Zara',
      'image': 'assets/images/Brands/zara.png',
      'storeUrl': 'https://www.zara.com/',
    },
    {
      'name': 'Sephoro',
      'image': 'assets/images/Brands/sephora.png',
      'storeUrl': 'https://www.sephora.com/',
    },
  ];

  final List<Map<String, String>> _categories = const [
    {'label': 'Electronics', 'value': 'electronics', 'icon': 'devices_other'},
    {'label': 'Cosmetics', 'value': 'cosmetics', 'icon': 'brush'},
    {'label': 'Clothing', 'value': 'clothing', 'icon': 'checkroom'},
    {'label': 'Bags', 'value': 'bags', 'icon': 'shopping_bag'},
    {'label': 'Shoes', 'value': 'shoes', 'icon': 'shoe'},
    {'label': 'Medicine', 'value': 'medicine', 'icon': 'health_and_safety'},
  ];

  // runtime state
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  String? _errorMsg;

  @override
  void initState() {
    super.initState();

    _loadProductsFromApi(
      category: _categories[0]['value']!,
    );
  }

  Future<void> _loadProductsFromApi({String? category}) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final products = await listData(
        collection: "Products",
        category: category,
      );

      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  Widget iconGridSlider({
    required List<Map<String, String>> items,
    required Widget Function(Map<String, String> item, bool isActive) buildIcon,
    required String Function(Map<String, String> item) getLabel,
    int? selectedIndex,
    Function(int index)? onItemTap,
    bool enableSelection = false,
  }) {
    return SizedBox(
      height: 95,
      child: horizontalList(
        itemCount: items.length,
        spacing: 14,
        horizontalPadding: 6,
        useCard: false,
        onItemTap: onItemTap,
        itemBuilder: (i) {
          final item = items[i];
          final isActive = enableSelection && selectedIndex == i;

          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 68,
                height: 63,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isActive)
                      BoxShadow(
                        color: AppColors.black.withAlpha(10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: buildIcon(item, isActive),
                ),
              ),
              SizedBox(
                width: 67,
                child: Text(
                  getLabel(item),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.textprimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _mapCategoryIcon(String iconName) {
    switch (iconName) {
      case 'devices_other':
        return Icons.devices_other;

      case 'brush':
        return Icons.brush;

      case 'checkroom':
        return Icons.checkroom;

      case 'shoe':
        return Icons.directions_walk;

      case 'health_and_safety':
        return Icons.health_and_safety;

      case 'shopping_bag':
        return Icons.shopping_bag;
    }
    return Icons.category;
  }

  Widget _buildProducts() {
    if (_errorMsg != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                final cat = _categories[_selectedCategory]['value']!;
                _loadProductsFromApi(category: cat);
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No products available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return horizontalList(
      itemCount: _products.take(6).length,
      spacing: 12,
      horizontalPadding: 6,
      useCard: false,
      itemBuilder: (i) {
        final p = _products[i];

        return SizedBox(
          width: 150,
          height: 245,
          child: ProductCard(
            id: p['id'] ?? '',
            name: p['name'] ?? '',
            image: p['image'] ?? '',
            price: p['price'] ?? 0,
            storeName: p['storeName'] ?? '',
            storeLink: p['storeLink'] ?? '',
            category: p['category'] ?? '',
          ),
        );
      },
    );
  }

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
              InfoSlider(slides: _slides),

              const SizedBox(height: 8),

              sectionTitle("Trending categories"),
              const SizedBox(height: 10),
              iconGridSlider(
                items: _categories,
                enableSelection: true,
                selectedIndex: _selectedCategory,
                onItemTap: (index) {
                  final cat = _categories[index]['value']!;

                  setState(() => _selectedCategory = index);

                  _loadProductsFromApi(category: cat);
                },
                buildIcon: (cat, isActive) => Icon(
                  _mapCategoryIcon(cat['icon'] ?? ''),
                  size: 26,
                  color: isActive ? AppColors.white : AppColors.textSecondary,
                ),
                getLabel: (cat) => cat['label'] ?? '',
              ),

              // Trending Products

              sectionTitle(
                "Trending products",
                actionText: "See More",
                onTap: () {
                  Navigator.pushNamed(context, '/ProductDashboard');
                },
              ),
              const SizedBox(height: 10),

              _buildProducts(),

              const SizedBox(height: 20),

              sectionTitle(
                "Trending Stores",
                actionText: "See More",
                onTap: () {
                  Navigator.pushNamed(context, '/explore');
                },
              ),
              const SizedBox(height: 10),

              iconGridSlider(
                items: _trendingStores,
                buildIcon: (store, _) => appAssetImage(
                  store['image'],
                  fit: BoxFit.contain,
                ),
                getLabel: (store) => store['name'] ?? '',
                onItemTap: (index) {
                  openLink(context, _trendingStores[index]['storeUrl']);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
