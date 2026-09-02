import 'package:skybridge02/Home/Component/app_asset_image.dart';
import 'package:skybridge02/ProductManagement/product_detail.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Theme/text_styles.dart';

class ProductCard extends StatelessWidget {
  final String? id;
  final String? name;
  final String? image;
  final dynamic price;
  final String? storeName;
  final String? storeLink;
  final double weight;
  final String? category;

  const ProductCard({
    super.key,
    this.id,
    this.name,
    this.image,
    this.price,
    this.storeName,
    this.storeLink,
    this.weight = 1.0,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(
              product: {
                'productId': id ?? '',
                'name': name ?? '',
                'image': image ?? '',
                'price': price ?? 0,
                'storeName': storeName ?? '',
                'storeLink': storeLink ?? '',
                'weight': weight,
                'category': category ?? '',
              },
            ),
          ),
        );
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (storeName != null && storeName!.isNotEmpty)
                    Text(storeName!.toUpperCase(),
                        style: AppTextStyles.title.copyWith(
                          fontSize: 11,
                          color: AppColors.textbrand,
                        )),
                  const SizedBox(height: 5),
                  Text(
                    name ?? 'Product',
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price != null ? '\$$price' : 'Price Unavailable',
                        style: AppTextStyles.price.copyWith(
                          fontSize: 18,
                          color: AppColors.secondary,
                        ),
                      ),
                      addButton(context, product: {
                        'productId': id,
                        'name': name,
                        'image': image,
                        'price': price,
                        'storeName': storeName,
                        'storeLink': storeLink,
                        'weight': weight,
                        'category': category,
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget addButton(
    BuildContext context, {
    required Map<String, dynamic> product,
  }) {
    final ValueNotifier<bool> added = ValueNotifier(false);

    return ValueListenableBuilder<bool>(
      valueListenable: added,
      builder: (context, value, _) {
        return GestureDetector(
          onTap: () {
            added.value = true;

            Future.delayed(const Duration(seconds: 1), () {
              added.value = false;
              if (!context.mounted) return;
              Navigator.pushNamed(
                context,
                '/add_request_info',
                arguments: product,
              );
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: value ? AppColors.success : AppColors.secondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              value ? Icons.check : Icons.add,
              color: Colors.white,
              size: 16,
            ),
          ),

          
        );
      },
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        width: double.infinity,
        height: 140,
        color: const Color(0xFFF1F5F9),
        padding: const EdgeInsets.all(10),
        child: appAssetImage(
          image,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
