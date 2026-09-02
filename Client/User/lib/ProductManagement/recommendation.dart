import 'package:flutter/material.dart';
import 'package:skybridge02/ProductManagement/product_card.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';

class RecommendationSection extends StatefulWidget {
  final String productId;

  const RecommendationSection({super.key, required this.productId});

  @override
  State<RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection> {
  List recommendations = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRecommendations();
  }

  Future<void> loadRecommendations() async {
    setState(() => loading = true);

    try {
      final res = await ApiService.get(
        "/getRecommendations?productId=${widget.productId}",
      );

      setState(() {
        recommendations = List<Map<String, dynamic>>.from(res);
        loading = false;
      });
    } catch (e) {
      debugPrint("Recommendation error: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      );
    }

    if (recommendations.isEmpty) {
      return const SizedBox();
    }

    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Similar Products",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 245,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final item = recommendations[index];

              return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: SizedBox(
                  width: 155,
                  child: ProductCard(
                    id: item['id'],
                    name: item['name'],
                    image: item['image'],
                    price: item['price'],
                    storeName: item['storeName'],
                    storeLink: item['storeLink'],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
