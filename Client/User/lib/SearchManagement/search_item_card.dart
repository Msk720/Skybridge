import 'package:skybridge02/Services/app_imports.dart';
import 'package:skybridge02/Theme/text_styles.dart';
import 'base_card.dart';

class ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemCard({super.key, required this.item});

  void openShipmentDetails(BuildContext context) {
    final shipmentId = item['id']?.toString();

    if (shipmentId == null) {
      debugPrint("❌ shipmentId is null");
      return;
    }

    Navigator.pushNamed(
      context,
      '/shipmentDetails',
      arguments: {...item, 'viewerRole': 'traveler'},
    );
  }

  @override
  Widget build(BuildContext context) {
    String image = item['image']?.toString() ?? "";
    final fromCity = (item['fromCity'] ?? '').toString();
    final toCity = (item['toCity'] ?? '').toString();
    final before = item['date'] ?? item['deliveryDate'] ?? item['departureDate'];
    final weight = "${item['weightTotal'] ?? '—'} KG";
    final reward = item['travelerReward'] ?? "0";
    final title = (item['name'] ?? 'Item').toString();
    final ownerName = (item['ownerName'] ?? '—').toString();
    final ownerImage = (item['ownerImage'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Center(
                child: Container(
                  height: 145,
                  width: 160,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: image.isNotEmpty
                          ? Image.network(
                              image,
                              fit: BoxFit.contain,
                            )
                          : const Icon(Icons.image, size: 40),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: _outlinedBox(
                  child: Text(
                    "Reward \$$reward",
                    style: AppTextStyles.price.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Center(
            child:
                Text(title, style: AppTextStyles.title.copyWith(fontSize: 15)),
          ),
          const Divider(),
          BaseCard(
            fromCity: fromCity,
            toCity: toCity,
            dateText: before,
            weightText: weight,
            ownerName: ownerName,
            ownerImage: ownerImage,
            onPressed: () => openShipmentDetails(context),
          )
        ],
      ),
    );
  }

  Widget _outlinedBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 224, 225, 228),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
