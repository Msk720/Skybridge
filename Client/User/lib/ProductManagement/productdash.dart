import 'package:flutter/material.dart';
import 'package:skybridge02/Services/DashBoardHelper/list_data_handler.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/empty_state.dart';
import 'package:skybridge02/ProductManagement/product_card.dart';

class ProductDashboard extends StatefulWidget {
  const ProductDashboard({super.key});

  @override
  State<ProductDashboard> createState() => _ProductDashboardState();
}

class _ProductDashboardState extends State<ProductDashboard> {
  bool loading = true;

  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    setState(() => loading = true);

    try {
      final data = await listData(
        collection: "Products",
      );

      setState(() {
        products = data;
        loading = false;
      });
    } catch (e) {
      debugPrint("Fetch products error: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color.fromARGB(255, 237, 233, 233),
        appBar: dashboardAppBar(
          title: "Products ",
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
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : products.isEmpty
                ? emptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: "No Products",
                    subtitle: "Products will appear here",
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16 , 16, 16, 60),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.64,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final product = products[i];

                      return ProductCard(
                        id: product['id'] ?? '',
                        name: product['name'] ?? '',
                        image: product['image'] ?? '',
                        price: product['price'] ?? 0,
                        storeName: product['storeName'] ?? '',
                        storeLink: product['storeLink'] ?? '',
                        weight: (product['weight'] ?? 1).toDouble(),
                        category: product['category'] ?? '',
                      );
                    },
                  ));
  }
}
