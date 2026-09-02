import 'package:skybridge02/Services/app_imports.dart';

Widget sectionTitle(
  String title, {
  String? actionText,
  VoidCallback? onTap,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 🔹 TITLE
        Text(
          title,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),

        if (actionText != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color.fromARGB(255, 37, 139, 235),
              ),
            ),
          ),
      ],
    ),
  );
}
