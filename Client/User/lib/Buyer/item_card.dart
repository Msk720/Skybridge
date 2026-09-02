// lib/Shopper/item_card.dart
import 'package:flutter/material.dart';
import 'package:skybridge02/Services/action_buttons.dart';
import 'package:skybridge02/Services/format_date.dart';
import 'package:skybridge02/Theme/app_color.dart';
import 'package:skybridge02/Theme/text_styles.dart';

class ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String status;

  const ItemCard(
      {super.key,
      required this.item,
      this.onEdit,
      this.onDelete,
      required this.status});

  @override
  Widget build(BuildContext context) {
    final image = item['image'] ?? '';
    final total = item['totalPrice'] ?? "--";
    final weight = "${item['weightTotal'] ?? '--'} kg";
    final fromCountry = item['fromCountry'] ?? '--';
    final toCountry = item['toCountry'] ?? '--';
    final beforeStr = formatDate(item['date'] ?? item['deliveryDate'] ?? item['departureDate']);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey[200]),
                        )
                      : Container(color: Colors.grey[200]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total", style: AppTextStyles.label),
                        Text(
                          "\$$total",
                          style: AppTextStyles.price,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _infoRow(Icons.shopping_bag, weight),
          _infoRow(Icons.flight_takeoff, fromCountry),
          _infoRow(Icons.flight_land, toCountry),
          _infoRow(Icons.access_time, "Before: $beforeStr"),
          if (status == "Active") ...[
            const SizedBox(height: 12),
            ActionButtonsRow(
              leftText: 'Edit',
              rightText: 'Delete',
              onLeftPressed: onEdit,
              onRightPressed: onDelete,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.value)),
        ],
      ),
    );
  }
}
