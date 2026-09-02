import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';
import 'package:skybridge02/Services/format_date.dart';
import 'package:skybridge02/Theme/text_styles.dart';

class BaseCard extends StatelessWidget {
  final String fromCity;
  final String toCity;
  final String? dateText;
  final String weightText;
  final String ownerName;
  final String ownerImage;
  final String? weightSubText;
  final String? timeText;
  final VoidCallback onPressed;
  final String actionLabel;
  final IconData? actionIcon;

  const BaseCard({
    super.key,
    required this.fromCity,
    required this.toCity,
    this.dateText,
    this.timeText,
    required this.weightText,
    this.weightSubText,
    required this.ownerName,
    required this.ownerImage,
    required this.onPressed,
    this.actionLabel = 'more info',
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = formatDate(dateText);
    final dateDisplay = timeText != null
        ? "Departs on $formattedDate at $timeText"
        : "Before $formattedDate";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              fromCity,
              style: AppTextStyles.title,
            ),
            const Spacer(),
            const Icon(Icons.flight_takeoff,
                color: AppColors.primary, size: 26),
            const Spacer(),
            const Icon(Icons.location_on, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              toCity,
              style: AppTextStyles.title,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const SizedBox(width: 3),
            const Icon(Icons.scale, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              weightText,
              style: AppTextStyles.value.copyWith(fontSize: 13),
            ),
            if (weightSubText != null) ...[
              const SizedBox(width: 6),
              Text(
                weightSubText!,
                style: AppTextStyles.label.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 3),
            const Icon(Icons.schedule, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Text(
              dateDisplay,
              style: AppTextStyles.value.copyWith(fontSize: 13),
            ),
          ],
        ),
        const Divider(),
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundImage:
                  ownerImage.isNotEmpty ? NetworkImage(ownerImage) : null,
              child: ownerImage.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerName,
                  style: AppTextStyles.name,
                ),
                const Row(
                  children: [
                    Icon(Icons.star, size: 17, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      '4.8',
                      style: AppTextStyles.rating,
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 30,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionIcon != null) ...[
                      Icon(actionIcon, size: 15, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(actionLabel),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
