import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

Widget sectionLabel(
  String text, {
  Color? dotColor,
  IconData? icon,
}) {
  return Row(
    children: [
      if (dotColor != null) ...[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
      ] else if (icon != null) ...[
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
      ],
      Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
          letterSpacing: 1.3,
        ),
      ),
    ],
  );
}
