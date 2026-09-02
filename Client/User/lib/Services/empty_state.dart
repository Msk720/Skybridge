import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

Widget emptyState({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color.fromARGB(255, 211, 215, 220),
                  child: Icon(
                    icon,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Widget emptyInfoCard({
  required IconData icon,
  required String title,
  required String subtitle,
  Widget? action,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.activeline.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 31,
          backgroundColor: AppColors.primary.withValues(alpha: 0.10),
          child: Icon(
            icon,
            size: 34,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textprimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.textgray,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          action,
        ],
      ],
    ),
  );
}
