// lib/explore_shops.dart
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Services/open_link.dart';
import 'package:skybridge02/Services/dashboard_header.dart';

class Shop {
  final String name;
  final String description;
  final String url;
  final String assetPath;

  Shop({
    required this.name,
    required this.description,
    required this.url,
    required this.assetPath,
  });
}

class ExploreShops extends StatefulWidget {
  const ExploreShops({super.key});

  @override
  State<ExploreShops> createState() => _ExploreShopsState();
}

class _ExploreShopsState extends State<ExploreShops> {
  String searchQuery = '';

  late final List<Shop> allInOneShops;
  late final List<Shop> fashionShops;
  late final List<Shop> electronicsShops;
  late final List<Shop> homeLivingShops;
  late final List<Shop> beautyShops;
  late final List<Shop> toysShops;

  @override
  void initState() {
    super.initState();

    allInOneShops = [
      Shop(
        name: 'Amazon',
        description: 'A global giant offering a wide range of products.',
        url: 'https://www.amazon.com',
        assetPath: 'assets/images/Brands/amazon.png',
      ),
      Shop(
        name: 'eBay',
        description:
            'Known for auctions and a vast selection of new and used items.',
        url: 'https://www.ebay.com',
        assetPath: 'assets/images/Brands/ebay.png',
      ),
      Shop(
        name: 'Shein',
        description: 'Affordable fashion with a wide selection.',
        url: 'https://www.shein.com',
        assetPath: 'assets/images/Brands/shein.png',
      ),
      Shop(
        name: 'Walmart',
        description: 'A large retailer with a wide range of products.',
        url: 'https://www.walmart.com',
        assetPath: 'assets/images/Brands/walmart.png',
      ),
      Shop(
        name: 'Target',
        description: 'Another major retailer with a broad selection of goods.',
        url: 'https://www.target.com',
        assetPath: 'assets/images/Brands/target.png',
      ),
    ];

    fashionShops = [
      Shop(
        name: 'Zara',
        description: 'Fast fashion with trendy styles.',
        url: 'https://www.zara.com/us/',
        assetPath: 'assets/images/Brands/zara.png',
      ),
      Shop(
        name: 'H&M',
        description: 'Offers affordable fashion for men, women, and children.',
        url: 'https://www2.hm.com/en_us/',
        assetPath: 'assets/images/Brands/h&m.png',
      ),
      Shop(
        name: 'Forever 21',
        description: 'Trendy fashion at affordable prices.',
        url: 'https://www.forever21.com',
        assetPath: 'assets/images/Brands/forever21.png',
      ),
      Shop(
        name: 'Uniqlo',
        description:
            'Japanese casual wear designer, manufacturer, and retailer.',
        url: 'https://www.uniqlo.com',
        assetPath: 'assets/images/Brands/uniqlo.png',
      ),
    ];

    electronicsShops = [
      Shop(
        name: 'Best Buy',
        description: 'A major electronics retailer with a wide selection.',
        url: 'https://www.bestbuy.com/',
        assetPath: 'assets/images/Brands/bestbuy.png',
      ),
      Shop(
        name: 'Newegg',
        description: 'Focuses on computer hardware and gaming.',
        url: 'https://www.newegg.com/',
        assetPath: 'assets/images/Brands/newegg.png',
      ),
      Shop(
        name: 'Adorama',
        description: 'Photography, video, and audio equipment.',
        url: 'https://www.adorama.com',
        assetPath: 'assets/images/Brands/adorama.png',
      ),
    ];

    homeLivingShops = [
      Shop(
        name: 'IKEA',
        description: 'Known for affordable, Scandinavian-style furniture.',
        url: 'https://www.ikea.com/us/en/',
        assetPath: 'assets/images/Brands/ikea.png',
      ),
      Shop(
        name: 'Wayfair',
        description:
            'Offers a vast selection of furniture, decor, and home goods.',
        url: 'https://www.wayfair.com/',
        assetPath: 'assets/images/Brands/wayfair.png',
      ),
      Shop(
        name: 'Etsy',
        description: 'A marketplace for handmade and vintage items.',
        url: 'https://www.etsy.com/',
        assetPath: 'assets/images/Brands/etsy.png',
      ),
      Shop(
        name: 'West Elm',
        description: 'Modern furniture and home decor.',
        url: 'https://www.westelm.com',
        assetPath: 'assets/images/Brands/westelm.png',
      ),
      Shop(
        name: 'Home Depot',
        description: 'Home improvement supplies.',
        url: 'https://www.homedepot.com',
        assetPath: 'assets/images/Brands/homedepot.png',
      ),
    ];

    beautyShops = [
      Shop(
        name: 'Sephora',
        description: 'Offers a wide range of beauty products.',
        url: 'https://www.sephora.com/',
        assetPath: 'assets/images/Brands/sephora.png',
      ),
      Shop(
        name: 'Ulta Beauty',
        description: 'Another major beauty retailer.',
        url: 'https://www.ulta.com/',
        assetPath: 'assets/images/Brands/ultabeauty.png',
      ),
      Shop(
        name: 'Glossier',
        description: 'Beauty products inspired by real life.',
        url: 'https://www.glossier.com',
        assetPath: 'assets/images/Brands/glossier.png',
      ),
    ];

    toysShops = [
      Shop(
        name: 'Target',
        description: 'Offers a wide range of toys and games.',
        url: 'https://www.target.com/',
        assetPath: 'assets/images/Brands/target.png',
      ),
      Shop(
        name: 'Walmart',
        description: 'Another major retailer with a toy section.',
        url: 'https://www.walmart.com/',
        assetPath: 'assets/images/Brands/walmart.png',
      ),
      Shop(
        name: 'Hobby Lobby',
        description: 'For arts, crafts, and hobbies.',
        url: 'https://www.hobbylobby.com/',
        assetPath: 'assets/images/Brands/hobbylobby.png',
      ),
      Shop(
        name: 'Toys "R" Us',
        description: 'A famous toy retailer.',
        url: 'https://www.toysrus.com',
        assetPath: 'assets/images/Brands/toysrus.png',
      ),
      Shop(
        name: 'LEGO Store',
        description: 'For all things LEGO.',
        url: 'https://www.lego.com/en-us',
        assetPath: 'assets/images/Brands/legostore.png',
      ),
    ];
  }

  List<Shop> _filterShops(List<Shop> shops) {
    if (searchQuery.trim().isEmpty) return shops;
    final q = searchQuery.toLowerCase();
    return shops.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  List<Map<String, Object>> _sections() {
    return [
      {'title': 'All-in-One Shops', 'shops': _filterShops(allInOneShops)},
      {'title': 'Fashion', 'shops': _filterShops(fashionShops)},
      {'title': 'Electronics', 'shops': _filterShops(electronicsShops)},
      {'title': 'Home & Living', 'shops': _filterShops(homeLivingShops)},
      {'title': 'Beauty & Personal Care', 'shops': _filterShops(beautyShops)},
      {'title': 'Toys & Hobbies', 'shops': _filterShops(toysShops)},
    ].where((section) => (section['shops'] as List).isNotEmpty).toList();
  }

  Widget _buildShopCard(Shop shop) {
    return GestureDetector(
      onTap: () async {
        await openLink(context, shop.url);
      },
      child: Container(
        width: 150,
        height: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Image.asset(
                  shop.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.store,
                      size: 48,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              shop.description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4F4F4F)),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Shop> shops) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              color: AppColors.primary,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: shops.map(_buildShopCard).toList()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: "Explore Shops",
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // search bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Search shops...',
                          hintStyle: TextStyle(color: AppColors.secondary),
                        ),
                        onChanged: (t) => setState(() => searchQuery = t),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // sections list
              Expanded(
                child: ListView.builder(
                  itemCount: sections.length,
                  itemBuilder: (_, i) {
                    final sec = sections[i];
                    final title = sec['title'] as String;
                    final shops = sec['shops'] as List<Shop>;
                    return _buildSection(title, shops);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
