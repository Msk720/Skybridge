import 'package:flutter/material.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Theme/app_color.dart';
import 'package:skybridge02/SearchManagement/shipment_details_screen.dart';
import 'package:skybridge02/Services/open_link.dart';
import 'package:skybridge02/ProductManagement/recommendation.dart';

class ProductDetailsScreen extends StatelessWidget {
  final Map product;

  const ProductDetailsScreen({super.key, required this.product});

  void openWebsite(BuildContext context) {
    openLink(context, product['storeLink']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: "Products",
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Column(
          children: [
            infoCard([
              Center(
                child: Image.network(
                  product['image'] ?? '',
                  height: 170,
                  width: 170,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
              const SizedBox(height: 5),
              Center(
                  child: Text(
                product['name'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              )),
              infoRow("Store", product['storeName']),
              infoRow("Price", "\$${product['price']}"),
              infoRow("Weight", "${product['weight']} kg"),
              infoRow("Category", product['category']),
              GestureDetector(
                onTap: () => openWebsite(context),
                child: const Text(
                  "See this product here",
                  style: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: appPrimaryButton(
                text: 'Add Request',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/add_request_info',
                    arguments: product,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            RecommendationSection(
              productId: product['productId'],
            ),
            const SizedBox(height: 45),
          ],
        ),
      ),
    );
  }
}
