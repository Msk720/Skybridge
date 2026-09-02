import 'package:flutter/material.dart';
import 'package:skybridge02/Theme/app_color.dart';

class FieldDisplayTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final EdgeInsetsGeometry margin;

  const FieldDisplayTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? 'Not added' : value.trim();

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 247, 248, 250),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dotcolor.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
